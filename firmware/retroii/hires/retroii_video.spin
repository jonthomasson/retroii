''------------------------------------------------------------------------------------------------
'' Commodore 64 Two Color Fast VGA Display Demo
''
'' Copyright (c) 2018 Mike Christle
'' See end of file for terms of use.
''
'' History:
'' 1.0.0 - 10/10/2018 - Original release.
'' 1.1.0 - 10/31/2018 - Add CChar routine to better control character colors.
'' 1.2.0 - 11/02/2018 - Add blinking cursor.
'' 1.3.0 - 11/12/2018 - Add LineTo routine to draw a series of lines.
'' 2.0.0 - 11/16/2018 - Add assembly routines to replace Pixel, Char and Line functions.
''------------------------------------------------------------------------------------------------

CON

    _clkmode = xtal1 + pll16x
    _xinfreq = 5_000_000
    BasePin   = 16                          ' P16-P20 VGA
    SDA_pin = 29
    SCL_pin = 28      
    
    Line_Buffer_Size = 60
    TX_FLAG = 26    'I2C register set when there's a byte being transmitted
    RX_FLAG = 27    'I2C register set when byte is received at video processor
    TX_BYTE = 28    'I2C register which holds the byte being transmitted
    REG_FLAG = $FA  'this value indicates that the tx_flag or rx_flag is set                                  ' 
    RX_READY = 25   'I2C register set when ready  to receive from keyboard
    TXRX_TIMEOUT = 15_000
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
    MODE_SD_CARD_1 = 4 'disk selection
    MODE_SD_CARD_2 = 5 'program selection
    MODE_SD_CARD_3 = 6 'program download 

VAR
                                            '                             
'    byte vgabuff[vga#cols * vga#rows * 2]   ' VGA Text-Buffer 1. Byte = Character, 2. Byte = Color (bgc * 16 + fgc)           
'    byte cursor[6]                          ' Cursor info array 
    long sync                               ' sync used by VGA routine

    long pos                                ' Global Screen-Pointer
    long bpos                               ' Global Screen-Pointer
    byte line_buffer[Line_Buffer_Size]
    long row_num
    byte ascii_buffer[16]
    byte cursor_x
    byte line_count
    long current_mode
    byte rx_error  

OBJ

    C64 : "C64_4CF_VGA.spin"
    slave : "I2C slave v1.2"

PUB Main | I, J, C
    init
    repeat
        'index := slave.check_reg(29) 'check for new mode
        'if index > -1
        '    current_mode := index
            
        case current_mode
            'MODE_MONITOR: 
            '    run_monitor
            MODE_RETROII:
                run_retroii
            'MODE_SD_CARD_1:
            '    run_sd_disk_select
            'MODE_SD_CARD_2:
            '    run_sd_prog_select
            'MODE_SD_CARD_3:
            '    run_sd_file_download

PRI ascii_2bin(ascii) | binary

    if ascii < 58                   'if ascii number (dec 48-57)
        binary := ascii -48 'subtract 48 to get dec equivalent
    else
        binary := ascii -55 'else subtract 55 for ABCDEF 
    
    return binary
   
    
PRI init | i, x, y

    current_mode := MODE_RETROII
    row_num := 0
    dira[21..23]~~
    slave.start(SCL_pin,SDA_pin,$42) 
    C64.Start(2)
    'Backgound and foreground colors
    C64.Color(0, C64#RED) 'BLACK
    C64.Color(1, C64#BLUE) 'GREEN
    C64.Color(2, C64#RED)
    C64.Color(3, C64#BLUE) 'GREEN
'    vga.start(BasePin, @vgabuff, @cursor, @sync)
'    cursor[2] := %010
'    cursor[1] := 0
'    cursor[0] := 0
'    cursor_x := 0
    
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

PRI run_retroii | index, mem_loc, mem_start, data, row, col, cursor_toggle, cursor_timer
    cls
    'cursor[2] := 0   
    C64.Cursor(FALSE)
    cursor_toggle := false
    cursor_timer := 0
    
    repeat
        index := slave.check_reg(29) 'check for new mode
        if index > -1
            current_mode := index
            QUIT 'mode changed, so exit out
             '
        mem_loc := $400    'set starting address  
        mem_start := $00              
        row := 1  
        col := 0  
        
        cursor_timer++
        if cursor_timer == 2
            cursor_toggle := !cursor_toggle
            cursor_timer := 0
        'read Apple II Computer Graphics page 41 for example memory map of text/lores graphics
        repeat 3
            mem_loc := $400 + mem_start
            repeat 8
                col := 0
                repeat 40 'columns
                    data := read_byte(mem_loc)
                    if data == $60 'cursor
                        if cursor_toggle == true
                            printxy(col, row, $07, $00, 219)   'print cursor
                        else
                            printxy(col, row, $07, $00, 32)    'print space   
                    else
                        printxy(col, row, $07, $00, data - 128)'convert high ascii to low ascii
                        
                    col++
                    mem_loc++
                row++
                mem_loc += $58
            mem_start += $28

PRI cls
    C64.ClearScreen
    'wordfill(@vgabuff, $0720 , vga#cols * vga#rows)


PRI setPos(x, y)
    C64.Pos(x, y)
    'pos := (x + y * vga#cols) * 2


PRI print(fgc, bgc, char)
    C64.Char(char)
    'vgabuff[pos++] := char
    'vgabuff[pos++] := bgc * 16 + fgc


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
     

{{
┌──────────────────────────────────────────────────────────────────────────┐
│                       TERMS OF USE: MIT License                          │                                                            
├──────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a   │
│copy of this software and associated documentation files (the "Software"),│
│to deal in the Software without restriction, including without limitation │
│the rights to use, copy, modify, merge, publish, distribute, sublicense,  │
│and/or sell copies of the Software, and to permit persons to whom the     │
│Software is furnished to do so, subject to the following conditions:      │                                                           │
│                                                                          │                                                  │
│The above copyright notice and this permission notice shall be included in│
│all copies or substantial portions of the Software.                       │
│                                                                          │                                                  │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR│
│IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  │
│FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   │
│THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER│
│LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   │
│FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       │
│DEALINGS IN THE SOFTWARE.                                                 │
└──────────────────────────────────────────────────────────────────────────┘
}}