''*******************************
''* retroii_video 9/2019   *
''* Author: Jon Thomasson *
''*******************************
''
''
CON
    _clkmode  = xtal1 + pll16x
    _xinfreq  = 5_000_000

    BasePin   = 16                          ' P16-P20 VGA
    SDA_pin = 29
    SCL_pin = 28      
    
    Line_Buffer_Size = 60
                                      ' 
    {DATA PINS}
    D0 = 0
    D7 = 7
    
    {ADDRESS PINS}
    A0 = 8
    A7 = 15
    A8 = 21
    A14 = 27
    
    {WRITE ENABLE PIN}
    WE = 30
    
    {MODES}
    MODE_MONITOR = 1
    MODE_RETROII = 2
    MODE_ASSEMBLER = 3
    MODE_SD_CARD = 4
  
OBJ 
    slave : "I2C slave v1.2"
    vga :   "VGA5PIN_Text_640x480_80x60_8x8_FG8_BG8"     ' VGA Driver       Font 8x8        

DAT

'   Colors:

'   0 = Black
'   1 = Red
'   2 = Green
'   3 = Blue
'   4 = Yellow
'   5 = Magenta
'   6 = Cyan
'   7 = White

'   eq. 3 = Foreground Blue(fgc), 7 = Background White(bgc)


VAR
                                            '                             
    byte vgabuff[vga#cols * vga#rows * 2]   ' VGA Text-Buffer 1. Byte = Character, 2. Byte = Color (bgc * 16 + fgc)           
    byte cursor[6]                          ' Cursor info array 
    long sync                               ' sync used by VGA routine

    long pos                                ' Global Screen-Pointer
    long bpos                               ' Global Screen-Pointer
    'byte data
    byte line_buffer[Line_Buffer_Size]
    long row_num
    byte ascii_buffer[16]
    byte cursor_x
    byte line_count
    long current_mode

PUB main | index
    init
    
    repeat
        'index := slave.check_reg(29) 'check for new mode
        'if index > -1
        '    current_mode := index
            
        case current_mode
            MODE_MONITOR: 
                run_monitor
            MODE_RETROII:
                run_retroii
    

                
PRI run_monitor | i, index
    cursor[2] := %010   
    i := 0
    line_count := 0
   
    print_header
    
    repeat
        index := slave.check_reg(29) 'check for new mode
        if index > -1
            current_mode := index
            QUIT 'mode changed, so exit out
        index := slave.check_reg(31)
        if index > -1
            if index == $0D 'enter key detected
                
                i := 0
                print_header
                parse_command
                setPos(0, 0)
                cursor_x := 0
                line_count := 0
            else   
                print($07, $00, index)
                line_buffer[i] := index
                cursor_x++
                cursor[0] := cursor_x
                line_count++
                i++

PRI run_retroii | index, mem_loc, mem_start, data, row, col, i
    cls
    cursor[2] := 0   
    'str($07, $03, string("RETROII mode"))
    repeat
        index := slave.check_reg(29) 'check for new mode
        if index > -1
            current_mode := index
            QUIT 'mode changed, so exit out
             '
        'just going to get text page 1 up and running for now.
        'read from $0400 to $07FF for TEXT mode page 1
        'for each row 24
        '   for each column 40
        '       read memory and display ascii value
        mem_loc := $400    'set starting address  
        mem_start := $00              
        row := 0  
        col := 0   
        i := 0
        'setPos(0, 0) 'start in upper left corner of screen
        
        repeat 3
            mem_loc := $400 + mem_start
            repeat 8
                col := 0
                repeat 40 'columns
                    
                    data := read_byte(mem_loc)
                    if data > 128
                        printxy(col, row, $07, $00, data - 128)
                    else
                        printxy(col, row, $07, $00, data)
                    col++
                    'mem_loc := mem_loc + col
                    mem_loc++
                
                row++
                mem_loc += $58
            mem_start += $28
            

PRI print_header
    cls
    setPos(0, 1)
    str($07, $03, string("ADDR| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9| A| B| C| D| E| F|      ASCII       "))
    setPos(0, 0)
    cursor[0] := 0
    cursor_x := 0
    
PRI prompt
    
    if row_num > 58
        row_num := 0
        cls
        
    setPos(0,row_num)
    str($07, $00, string("*"))
    row_num++

PUB parse_command | addr, op, val, data, i, j, y, k, l, m, bulk_write, bulk_val, line_no
    '[address] will print value at that address
    '[address].[address] will print all values between those addresses
    '[address].[address]:[val] will write [val] to range of addresses
    '[address]:[val] will write values in consecutive memory locations starting at address
    
    line_no := 2
    setPos(0, line_no)
    
    'pull out address1, operation, and val from line_buffer
    addr := ((ascii_2bin(line_buffer[0])) << 12) | ((ascii_2bin(line_buffer[1])) << 8) | ((ascii_2bin(line_buffer[2])) << 4) | (ascii_2bin(line_buffer[3]))
    val := ((ascii_2bin(line_buffer[5])) << 12) | ((ascii_2bin(line_buffer[6])) << 8) | ((ascii_2bin(line_buffer[7])) << 4) | (ascii_2bin(line_buffer[8]))
    
    op := line_buffer[4]
    
    if op == "."
        if val > 0
            
            i :=  val - addr 'get difference between addresses and iterate
            j := addr
            
            'determine if this is a bulk write operation
            bulk_write := line_buffer[9]
            
            if bulk_write == ":"
                'get value to write
                bulk_val := ascii_2bin(line_buffer[10]) << 4 | ascii_2bin(line_buffer[11])
                repeat i + 1
                    write_byte(bulk_val, j)
                    j++
            else        
                repeat (i + 1) / 16
                    longfill(@ascii_buffer, 0, 4)
                    y := 0
                
                    hex($07, $03, j, 4)
                    str($07, $03, string(":"))
                    repeat 16 'display 16 bytes per line
                        data := read_byte(j)
                        hex($07, $00, data, 2)
                        str($07, $00, string(" "))
                        if data > 128
                            ascii_buffer[y] := (data - 128) 'convert from high ascii to low ascii
                        else
                            ascii_buffer[y] := data 
                        
                        y++
                        j++
                    y := 0
                
                    repeat 16 'display ascii
                        print($07, $00, ascii_buffer[y])
                        y++
                    if line_no > 56
                        line_no := 2
                        setPos(0, line_no)
                    else 
                        line_no++   
                        setPos(0, line_no)
                    
        else
            hex($07, $03, addr, 4)
            str($07, $03, string(":"))
            data := read_byte(addr)
            hex($07, $00, data, 2)
    elseif op == ":"
        'loop through rest of line_buffer and write each byte to incremental memory address
        l := 0
        
        repeat k from 0 to (line_count - 6) step 2
            val := ascii_2bin(line_buffer[k + 5]) << 4 | ascii_2bin(line_buffer[k + 6])
            write_byte(val, addr + l)
            l++
    else
        hex($07, $03, addr, 4)
        str($07, $03, string(":"))
        data := read_byte(addr)
        hex($07, $00, data, 2)
     
    
    'after everything, make sure to clear line_buffer
    bytefill(@line_buffer, 0, Line_Buffer_Size)
    
    
PRI ascii_2bin(ascii) | binary

    if ascii < 58                   'if ascii number (dec 48-57)
        binary := ascii -48 'subtract 48 to get dec equivalent
    else
        binary := ascii -55 'else subtract 55 for ABCDEF 
    
    return binary
   
    
PRI init | i, x, y

    current_mode := MODE_MONITOR
    row_num := 0
    dira[21..23]~~
    slave.start(SCL_pin,SDA_pin,$42) 
    vga.start(BasePin, @vgabuff, @cursor, @sync)
    cursor[2] := %010
    cursor[1] := 0
    cursor[0] := 0
    cursor_x := 0
    
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start

    cls

    'setup address/data/control lines
    dira[D0..D7]~~  'output
    outa[D0..D7] := %00000000   'low
    
    dira[A0..A7]~~  'output
    outa[A0..A7] := %00000000   'low
    dira[A8..A14]~~ 'output
    outa[A8..A14] := %0000000 'low
    
    dira[WE]~~      'output
    outa[WE]~~      'set we high to avoid writing data

PRI cls

    wordfill(@vgabuff, $0720 , vga#cols * vga#rows)


PRI setPos(x, y)

    pos := (x + y * vga#cols) * 2


PRI print(fgc, bgc, char)

    vgabuff[pos++] := char
    vgabuff[pos++] := bgc * 16 + fgc


PRI printxy(x, y, fgc, bgc, char)

    setPos(x, y)
    print(fgc, bgc, char)


PRI str(fgc, bgc, string_ptr) 

    repeat strsize(string_ptr)
        print(fgc, bgc, byte[string_ptr++]) 


PRI strxy(x, y, fgc, bgc, string_ptr)
 
    setPos(x, y)
    str(fgc, bgc, string_ptr) 


PRI dec(fgc, bgc, val) 
 
    prn(fgc, bgc, val)


PRI prn(fgc, bgc, val) | dig

    dig := 48 + (val // 10)
    val := val/10
    if val > 0
        prn(fgc, bgc, val)
    print(fgc, bgc, dig)


PRI decxy(x, y, fgc, bgc, val)

    setPos(x, y)
    dec(fgc, bgc, val)


PRI bin(fgc, bgc, value, digits)
  
    value <<= 32 - digits
    repeat digits
        print(fgc, bgc, (value <-= 1) & 1 + "0") 


PRI binxy(x, y, fgc, bgc, value, digits)

    setPos(x, y)
    bin(fgc, bgc, value, digits)


PRI hex(fgc, bgc, value, digits) 

    value <<= (8 - digits) << 2
    repeat digits
        print(fgc, bgc, lookupz((value <-= 4) & $f : "0".."9", "A".."F")) 


PRI hexxy(x, y, fgc, bgc, value, digits)

    setPos(x, y)
    hex(fgc, bgc, value, digits)

pri write_byte(data_out, address) | i, msb, lsb
    'to write:
    lsb := address 
    msb := address >> 8
    'bin($07, $00, msb, 8)
    'bin($07, $00, lsb, 8)
    'we should start high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~  'input /avoid bus contention
    'set address pins
    'outa[A0..A7] := address 
    outa[A7..A0] := lsb 
    outa[A14..A8] := msb
    'set we pin low for specified time
    outa[WE]~
    dira[D0..D7]~~  'output /avoid bus contention
    'i := 0
    'set data pins
    outa[D7..D0] := data_out
    'i := 0
    
    'bring we pin high to complete write
    outa[WE]~~
    dira[D0..D7]~  'input /avoid bus contention
    'i := 0
    outa[A0..A7] := %00000000 'low
    outa[A8..A14] := %0000000 'low

pri read_byte(address) | data_in, i, msb, lsb
    'to read:
    
    lsb := address 
    msb := address >> 8
    'set we pin high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~
    'set address pins
    'outa[A0..A7] := address 
    outa[A7..A0] := lsb
    outa[A14..A8] := msb
    'wait specified time
    'i := 0
    'read data pins
    data_in := ina[D7..D0]
    'i := 0
    outa[A0..A7] := %00000000 'low
    outa[A8..A14] := %0000000 'low
    return data_in
    
DAT

strTop   byte "VGA5PIN_Demo v1.1", 0
strDate  byte "ws 2/2017", 0
strBase  byte "BasePin    : ", 0
strRes   byte "Resolution : ", 0
strCols  byte "Cols/Rows  : ", 0 
strFont  byte "Font       : ", 0
strPort  byte "P23..P21", 0
