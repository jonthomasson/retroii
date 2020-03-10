''------------------------------------------------------------------------------------------------
'' RETRO ][ video driver
''
'' Copyright (c) 2020 Jon Thomasson
''
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
    CMD_FLAG = 24   'I2C register used to send commands to video processor
    CMD_RESET = $EA 'this value tells the video processor to reset the 6502
    CMD_DONE = $AC  'this value is an acknowledgement that the command has finished
    CMD_RETROII = $BD 'command to set video mode to retroii mode
    TX_BYTE = 28    'I2C register which holds the byte being transmitted
    REG_FLAG = $FA  'this value indicates that the tx_flag or rx_flag is set                                  ' 
    RX_READY = 25   'I2C register set when ready  to receive from keyboard
    TXRX_TIMEOUT = 35_000
    
    {DATA PINS}
    D0 = 0
    D7 = 7
    
    {CLOCK}
    CLOCK_REG = 23 'i2c register to hold clock value
    
    {ADDRESS PINS}
    A0 = 8
    A7 = 15
    A8 = 21
    A14 = 27
    A15 = 31
    
    {WRITE ENABLE PIN}
    WE = 30
    
    {MODES}
    MODE_MONITOR = 1
    MODE_RETROII = 2
    MODE_ASSEMBLER = 3
    MODE_SD_CARD_1 = 4 'disk selection
    MODE_SD_CARD_2 = 5 'program selection
    MODE_SD_CARD_3 = 6 'program download 
    
    {FILE OPTIONS FOR MODE_SD_CARD_3}
    FILE_LOAD = 1
    FILE_RUN = 2   
                    '
    {RETROII_MODES}
    RETROII_TEXT = 1
    RETROII_HIRES = 2
    RETROII_LORES = 3
    
    {PAGE_LOCATIONS}
    TEXT_PAGE1 = $400
    TEXT_PAGE2 = $800
    HIRES_PAGE1 = $2000
    HIRES_PAGE2 = $4000
    
    ROWS_PER_PAGE = 28

VAR
                                                                         
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
    long soft_switches
    byte ss_text
    byte ss_mix
    byte ss_page2
    byte ss_hires
    byte soft_switches_updated 
    long cog_soft_switches
    long cog_ss_stack[20]
    long prog_download_option
    long current_clock 'current frequency in Hz for clock feeding the 6502
    long old_clock 
    long clock_freqs[10]
OBJ

    R2 : "r2_video.spin"
    slave : "I2C slave v1.2"

PUB Main 
    init
    repeat 
        case current_mode
            MODE_MONITOR: 
                run_monitor
            MODE_RETROII:
                run_retroii
            MODE_SD_CARD_1:
                run_sd_disk_select
            MODE_SD_CARD_2:
                run_sd_prog_select
            MODE_SD_CARD_3:
                run_sd_file_download
{{
Summary: Converts an ASCII character into its binary equivalent
Params: ascii: the ascii char to convert
Returns: binary: the binary number for the ascii char
}}
PRI ascii_2bin(ascii) | binary

    if ascii < 58           'if ascii number (dec 48-57)
        binary := ascii -48 'subtract 48 to get dec equivalent
    else
        binary := ascii -55 'else subtract 55 for ABCDEF 
    
    return binary
   
    
PRI init | i, x, y
    current_clock := 7
    'init clock freq array
    clock_freqs[0]  := 0
    clock_freqs[1]  := 1_000
    clock_freqs[2]  := 10_000
    clock_freqs[3]  := 50_000
    clock_freqs[4]  := 100_000
    clock_freqs[5]  := 250_000
    clock_freqs[6]  := 500_000
    clock_freqs[7]  := 1_020_500 'original clock speed of the Apple ][. Taken from "Understanding The Apple" page 3-3.
    clock_freqs[8]  := 2_000_000
    clock_freqs[9]  := 3_000_000
    clock_freqs[10] := 4_000_000
    
    soft_switches_updated := FALSE
    ss_hires := FALSE
    ss_page2 := FALSE
    ss_mix := FALSE
    ss_text := TRUE
    
    current_mode := MODE_RETROII
    row_num := 0
    dira[21..23]~~
    slave.start(SCL_pin,SDA_pin,$42) 
    R2.Start(2)
    'Backgound and foreground colors
    R2.Color(0, R2#RED) 'BLACK
    R2.Color(1, R2#BLUE) 'GREEN
    
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start

    cls

    'setup address/data/control lines
    dira[D0..D7]~~  'output
    outa[D0..D7] := %00000000   'low
    
    dira[A0..A7]~~  'output
    outa[A0..A7] := %00000000   'low
    dira[A8..A14]~~ 'output
    outa[A8..A14] := %0000000 'low
    dira[A15]~~ 'output
    outa[A15]~ 'low
                              
    dira[WE]~~      'output
    outa[WE]~~      'set we high to avoid writing data
    
    cog_soft_switches := cognew(check_soft_switches, @cog_ss_stack) 

{{
Summary: 
    Runs in its own cog and continually checks for changes to the soft switches
    or video modes.
}}
PRI check_soft_switches | index
   
    repeat
        waitcnt(500000 + cnt)
        index := slave.check_reg(30) 'check for soft switch changes
    
        if index > -1
            soft_switches := index
            soft_switches_updated := TRUE
            
            if ($08 & soft_switches) == $08
                ss_hires := TRUE
            else
                ss_hires := FALSE
            
            if ($04 & soft_switches) == $04
                ss_page2 := TRUE
            else
                ss_page2 := FALSE
                
            if ($02 & soft_switches) == $02
                ss_mix := TRUE
            else
                ss_mix := FALSE 
                
            if ($01 & soft_switches) == $01
                ss_text := TRUE
            else
                ss_text := FALSE    
            
              
        index := -1
        
        index := slave.check_reg(29) 'check for new mode
    
        if index > -1
            if index == MODE_MONITOR or index == MODE_SD_CARD_3 or index == MODE_RETROII or index == MODE_SD_CARD_1 or index == MODE_SD_CARD_2
                current_mode := index
                
        index := -1
        index := slave.check_reg(CLOCK_REG)   
        
        if index > -1
            current_clock := index             
{{
Summary: 
    Starts th memory monitor program.
}}                
PRI run_monitor | i, index
    
    R2.Cursor(TRUE)
    i := 0
    line_count := 0
   
    print_header
    
    repeat while current_mode == MODE_MONITOR
        index := slave.check_reg(31)
        if index > -1
            if index == $0D 'enter key detected
                
                i := 0
                print_header
                parse_command
                setPos(0, 0)
                'cursor_x := 0
                line_count := 0
            else   
                print( index)
                line_buffer[i] := index
                'cursor_x++
                'cursor[0] := cursor_x
                line_count++
                i++

{{
Summary: 
    Parses the input for the memory monitor program.
Usage:
    [address] will print value at that address
    [address].[address] will print all values between those addresses
    [address].[address]:[val] will write [val] to range of addresses
    [address]:[val] will write values in consecutive memory locations starting at address
}}
PUB parse_command | addr, op, val, data, i, j, y, k, l, m, bulk_write, bulk_val, line_no
    '[address] will print value at that address
    '[address].[address] will print all values between those addresses
    '[address].[address]:[val] will write [val] to range of addresses
    '[address]:[val] will write values in consecutive memory locations starting at address
    R2.Cursor (FALSE)
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
                repeat (i + 1) / 8
                    longfill(@ascii_buffer, 0, 4)
                    y := 0
                
                    hex( j, 4)
                    str( string(":"))
                    repeat 8 'display 8 bytes per line
                        data := read_byte(j)
                        hex( data, 2)
                        str( string(" "))
                        if data > 128
                            ascii_buffer[y] := (data - 128) 'convert from high ascii to low ascii
                        else
                            ascii_buffer[y] := data 
                        
                        y++
                        j++
                    y := 0
                
                    repeat 8 'display ascii
                        print( ascii_buffer[y])
                        y++
                    if line_no > 28
                        line_no := 2
                        setPos(0, line_no)
                    else 
                        line_no++   
                        setPos(0, line_no)
                    
        else
            hex( addr, 4)
            str( string(":"))
            data := read_byte(addr)
            hex( data, 2)
    elseif op == ":"
        'loop through rest of line_buffer and write each byte to incremental memory address
        l := 0
        
        repeat k from 0 to (line_count - 6) step 2
            val := ascii_2bin(line_buffer[k + 5]) << 4 | ascii_2bin(line_buffer[k + 6])
            write_byte(val, addr + l)
            l++
    else
        hex( addr, 4)
        str( string(":"))
        data := read_byte(addr)
        hex( data, 2)
     
    
    'after everything, make sure to clear line_buffer
    bytefill(@line_buffer, 0, Line_Buffer_Size)
    R2.Cursor (TRUE)

{{
Summary:
    Prints out the header row for the memory monitor program. 
}} 
PRI print_header
    cls
    setPos(0, 1)
    str( string("ADDR| 0| 1| 2| 3| 4| 5| 6| 7| ASCII"))
    setPos(0, 0)
    'cursor[0] := 0
    'cursor_x := 0

{{
Summary:
    Downloads the selected program from the DOS disk image on the 
    sd card and writes it to the appropriate memory in RAM. 
}}     
PRI run_sd_file_download | addr, done, index, i, adr_lsb, adr_msb,address, length_lsb, length_msb, length, reset_vector_check
    
    cls
    R2.Cursor(FALSE)
    setPos(0,0)
    done := 0
    slave.flush 'clears all 32 registers to 0    
    
    'get file name/address location/length 
    'start downloading to ram
    if prog_download_option == FILE_LOAD
        str( string("LOADING FILE"))
    else
        str( string("RUNNING PROGRAM"))
        '1. clear ram 0000-BFFF
        setPos(0,5)
        str( string("STAT: CLEARING MEMORY SPACE"))
        repeat addr from 0 to 49151 '48KB
            write_byte($00, addr)
        '2. reset (send command to keyboard controller)
        setPos(0,5)
        str( string("STAT: SENDING RESET         "))
        slave.put(CMD_FLAG,CMD_RESET)
        
        'wait till we know there's been a reset
        repeat while done <> CMD_DONE
            done := slave.check_reg(CMD_FLAG)
        slave.put(CMD_FLAG, $00)'reset flag    
    setPos(0,2)
    str( string("NAME: "))
    is_rx_ready 'setup receiver
    'receive file name
    repeat 30
        index := rx_byte                
        print( index - 128)
    
    'read address
    adr_lsb := rx_byte
    adr_msb := rx_byte
    'read file length
    length_lsb := rx_byte
    length_msb := rx_byte
    
    setPos(0,3)
    str( string("ADDR: $"))
    
    address := adr_msb << 8 | adr_lsb
    hex( address,4)
    str( string("("))
    dec( address)
    str( string(")"))
    length := length_msb << 8 | length_lsb
    
    setPos(0,4)
    str( string("SIZE: "))
    dec( length)
    
    setPos(0,5)
    str( string("STAT: DOWNLOADING FROM DISK"))
    'read data
    'start at address. for i = 0 to length: write_byte(rx_byte,addr + i)
    i := 0
    repeat length
        index := rx_byte
        if rx_error == false 'only write valid data
            write_byte(index, address + i)
            i++     
    
    rx_done 'rx finished
    
    setPos(0,5)
    if prog_download_option == FILE_LOAD
        str( string("STAT: COMPLETE                        "))
    else 
        if address == $0801 'Applesoft BASIC
            'perform reset
            slave.put(CMD_FLAG,CMD_RESET)
        
            'wait till we know there's been a reset
            done := 0
            repeat while done <> CMD_DONE
                done := slave.check_reg(CMD_FLAG)
            slave.put(CMD_FLAG, $00)'reset flag
            
            str( string("STAT: FINISHED                        "))
            setPos(0,7)
            'print instructions for running
            str( string("FOLLOW INSTRUCTIONS BELOW TO RUN:"))
            setPos(0,8)
            str(string("1. PRESS F4 KEY"))
            setPos(0,9)
            str(string("2. AT THE ] TYPE RUN AND PRESS ENTER"))
            
            
        else
            str( string("STAT: RUNNING...PLEASE WAIT"))
            slave.flush 'clears all 32 registers to 0 
            'steps to auto-run program:
            '1. store address to jump to on reset to: $03F2(lsb), $03F3(msb)
            write_byte(adr_lsb, $03F2)
            write_byte(adr_msb, $03F3)
            '2. $03F4 = BYTE STORED AT $3F3 XOR CONSTANT $A5
            reset_vector_check := read_byte($03F3) ^ $A5
            write_byte(reset_vector_check, $03F4)
            '4. Toggle Reset (send command to keyboard controller)
            slave.put(CMD_FLAG,CMD_RESET)
        
            'wait till we know there's been a reset
            done := 0
            repeat while done <> CMD_DONE
                done := slave.check_reg(CMD_FLAG)
            slave.put(CMD_FLAG, $00)'reset flag
            '5. Restore reset vectors
            write_byte($03, $03F2)
            write_byte($E0, $03F3)
            write_byte($45, $03F4)
            '6. Switch video mode to Retro_II (send command to keyboard controller)
            slave.put(CMD_FLAG,CMD_RETROII)
        
        
    repeat while current_mode == MODE_SD_CARD_3
                   
{{
Summary:
    Reads the DOS catalog from the selected disk image and displays the
    contents of the disk. 
}}                 
PRI run_sd_prog_select | index, i, rx_char, dos_ver, vol_num, cat_count, file_length, file_type, file_access
    cls
    R2.Cursor(FALSE)
    setPos(0,0)
    cat_count := 0
    file_length := 0
    prog_download_option := 0
                 
    str( string("DISK "))
    
    'read in catalog
    is_rx_ready 'setup receiver
    
    i := 0
    repeat 16
        rx_char := rx_byte
        print( rx_char)
        i++
    
   
            
    str( string(" DOS 3."))
    dec( rx_byte)
    
    str( string(" VOL: "))
    dec( rx_byte)
    
    cat_count := rx_byte
    
    setPos(0,1)
    
    'str( string("SELECT FILE:                 COUNT: "))
    str( string("(L)OAD or (R)UN?:            COUNT: "))
    dec( cat_count)
    setPos(0, 2)
    str( string("   FILE                TYPE  PERM SIZE "))
      
    
    setPos(0,3)
    i := 1
    
    repeat cat_count 'end of transmission
        index := rx_byte
        if i < 10
            dec( 0)
            
        dec( i)
        str( string(". "))
        print( index - 128)
            
        repeat 19 'get rest of file name
            index := rx_byte
            print( index - 128)
            
        
        index := rx_byte
        file_access := index & $80 'bitwise and to mask lock bit
        file_type := index & $0F 'mask first nibble which holds the file type
        
        if file_type == $04
            str( string("BIN"))
        elseif file_type == $02
            str( string("BAS"))
        else    
            str( string("NA "))
            
        str( string("   "))
       
        if file_access == $80
            str( string(" R"))
        else
            str( string("WR"))
        str( string("   "))
        file_length := rx_byte 'file length ls byte (length in sectors)
        
        
        dec( file_length * 256)
        
        setPos(0, i+3)
        i++
       
                                
    rx_done 'rx finished
    
    'setPos(21,1)
    
    'R2.Cursor(FALSE)
    'get download option to run or load file
    repeat while current_mode == MODE_SD_CARD_2 and prog_download_option == 0
        index := slave.check_reg(31)
        if index > -1  
            if index == "L" or index == "R" 'load or run
                if index == "L"
                    prog_download_option := FILE_LOAD
                else
                    prog_download_option := FILE_RUN   
            'else 
                 
            '    print( index)
    
    setPos(0,1)
    str( string("SELECT FILE TO "))
    
    if prog_download_option == FILE_LOAD
        str( string("LOAD: "))
        setPos(21,1)
    else
        str( string("RUN: "))
        setPos(20,1)
    
    
    'get file index to load/run
    R2.Cursor(TRUE)
    repeat while current_mode == MODE_SD_CARD_2
        index := slave.check_reg(31)
        if index > -1  
            if index > 47 and index < 58
                print( index)
        
{{
Summary:
    Displays a list of DOS formatted disk images from the sd card. 
}} 
PRI run_sd_disk_select | index, total_pages, current_page, count_files_sent, i, y
    cls
    R2.Cursor(FALSE)
    setPos(0,0)
    index := 0
    slave.flush 'clears all 32 registers to 0                
    str( string("SELECT DISK: "))
    
    
    
    
    'receive the header
    'tell kb processor we're ready to rx
    is_rx_ready 'setup receiver
    total_pages := rx_byte
    str( string(" "))
    current_page := rx_byte
    str( string(" "))
    count_files_sent := rx_byte
    str( string(" "))
     
    setPos(0,1)
    str( string("PAGE "))
    dec( current_page)
    str( string(" OF "))
    dec( total_pages)
    setPos(0,2)
    i := 2
    y := 1
    if count_files_sent == 0
        dec( string("no disks found"))
        return
        
    str( string("01. "))
    repeat while index <> $04 'end of transmission
        
        index := rx_byte
        if index == $03 'end of line
            if i =< count_files_sent
                if i > ROWS_PER_PAGE
                    setPos(20, y)
                else
                    setPos(0,i+1)
                
                if i < 10
                    dec( 0)
                        
                dec( i)
            
                str( string(". "))
            i++
            if i > ROWS_PER_PAGE
                y++
        elseif index <> $04 'end of transmission
            print( index)
                                
    rx_done 'rx finished
   
    setPos(13,0)
    
    R2.Cursor(TRUE)                          
    repeat while current_mode == MODE_SD_CARD_1
        index := slave.check_reg(31)
        if index > -1 
            if index > 47 and index < 58 'valid number 0-9   
                print( index)
    
{{
Summary: Used to tell keyboard/sd card controller that the data has been received.
}}           
PRI rx_done
    'clear flags
    slave.put(RX_FLAG,$00)
    slave.put(RX_READY,$00)

{{
Summary: Used to tell keyboard/sd card controller that it is ready to receive data.
}}   
PRI is_rx_ready             
    'clear flags
    slave.put(RX_FLAG,$00)
    slave.put(RX_READY,REG_FLAG)

{{
Summary: receives a byte of data from the sd card controller
}}                   
PRI rx_byte | tx_ready, data, i, new_data
    'wait till tx_flag is set
    rx_error := false
    
    i := 0
    
    new_data := -1
    repeat while new_data == -1 'until we have something new
        i++
        if i > TXRX_TIMEOUT
            rx_error := true 'flag system we had an error receiving
            str( string("rx error"))
            return 'timeout
        new_data := slave.check_reg(TX_BYTE)
        
    data := new_data
    
    return data    

{{
Summary: 
    Entry point to run the Retro][ video mode. In this mode, the 
    soft switches are monitored and the video ram is polled and displayed
    in the appropriate video mode.
}}   
PRI run_retroii | retroii_mode, retroii_mode_old,mem_section, index, col_7, mem_loc, mem_box, mem_row, mem_start, mem_page_start, data, row, col, cursor_toggle, cursor_timer
    cls 
    R2.Cursor(FALSE)
    cursor_toggle := false
    cursor_timer := 0
    
    'check out the Apple ][ Reference Manual Page 13 for details on soft switch configs and video modes.
    repeat while current_mode == MODE_RETROII

        retroii_mode_old := retroii_mode 
        
        if ss_text == $FF and ss_hires == $00 'TEXT MODE
            retroii_mode := RETROII_TEXT
            mem_loc := TEXT_PAGE1    'set starting address  
            mem_start := $00         
            mem_page_start := TEXT_PAGE1
             
            row := 0  
            col := 0  
        
            if ss_page2 == $FF
                mem_page_start := TEXT_PAGE2
            
            cursor_timer++
            if cursor_timer > 0
                cursor_toggle := !cursor_toggle
                cursor_timer := 0
            'read Apple II Computer Graphics page 41 for example memory map of text/lores graphics
            repeat 3
                mem_loc := mem_page_start + mem_start
                repeat 8
                    display_retroii_textrow(row, mem_loc, cursor_toggle)
                    row++
                    mem_loc += $80
                mem_start += $28
        
            
        elseif ss_hires == $FF 'HIRES MODE
            retroii_mode := RETROII_HIRES
            mem_loc := HIRES_PAGE1    'set starting address  
            mem_start := $00         
            mem_page_start := HIRES_PAGE1
            row := 0  
            
            if ss_mix == $FF
                cursor_timer++
                if cursor_timer > 0
                    cursor_toggle := !cursor_toggle
                    cursor_timer := 0
        
            if ss_page2 == $FF
                mem_page_start := HIRES_PAGE2
               
                
            repeat mem_section from 1 to 3 '3 sections
                
                mem_box := 0
                repeat 8 '8 box rows per section
                    'mix mode
                    if ss_mix == $FF
                        'when we're at row 5 and section 3, exec mix mode
                        'check mem_box and mem_start
                        if mem_section == 3 and mem_box == $200
                            display_retroii_mixed(cursor_toggle)
                            'jump out of loops
                            mem_section := 3
                            quit
                    mem_row := 0
                    repeat 8 '8 rows within box row
                           
                        mem_loc := mem_page_start + mem_start + mem_box + mem_row
                        col := 0 '1'moving column a little to the right to center within frame
                        repeat 40 '40 columns/bytes per row
                            data := read_byte(mem_loc)
                            'col_7 := col * 7
                            'the msb is ignored since it's the color grouping bit
                            'the other bits are displayed opposite to where they appear
                            'ie the lsb bit appears on the left and each subsequent bit moves to the right.
                            'read Apple II Computer Graphics page 70ish for more details.
                            R2.Pixel (data, col, row)
                            
                        
                            col++
                            mem_loc++
                        row++
                        mem_row += $400
                        
                    mem_box += $80
                mem_start += $28
                          
        elseif ss_text == $00 and ss_hires == $00 'LORES MODE
            retroii_mode := RETROII_LORES
            mem_loc := TEXT_PAGE1    'set starting address  
            mem_start := $00         
            mem_page_start := TEXT_PAGE1
            
            if ss_mix == $FF
                cursor_timer++
                if cursor_timer > 0
                    cursor_toggle := !cursor_toggle
                    cursor_timer := 0
             
            row := 0  
            col := 0  
        
            if ss_page2 == $FF
                mem_page_start := TEXT_PAGE2
            
            'read Apple II Computer Graphics page 41 for example memory map of text/lores graphics
            repeat mem_section from 1 to 3 '3 sections
                mem_loc := mem_page_start + mem_start
                repeat 8
                    'mix mode
                    if ss_mix == $FF
                        'when we're at row 5 and section 3, exec mix mode
                        'check mem_box and mem_start
                        if row > 19
                            display_retroii_mixed(cursor_toggle)
                            'jump out of loops
                            mem_section := 3
                            quit
                    display_retroii_loresrow(row, mem_loc)
                    row++
                    mem_loc += $80
                mem_start += $28                                      
    
        printDebug   

{{
Summary: sends a row of Lores pixels to the screen
}}                                        
PRI display_retroii_loresrow(row, mem_loc) | data, col
    col := 0
      
    repeat 40 'columns
        data := read_byte(mem_loc)
        R2.LowRes (data, col, row)                 
                           
        col++
        mem_loc++

{{
Summary: Routine called by Lores and Hires modes to display mixed text
    when the ss_mixed soft switch is set to true. Mixed mode displays 4 columns
    of text at the bottom of the screen. 
}}         
PRI display_retroii_mixed(cursor_toggle) | row, mem_loc
    mem_loc := $650
    row := 20
    repeat 4 '4 rows of text
        display_retroii_textrow(row, mem_loc, cursor_toggle)
        row++
        mem_loc += $80

{{
Summary: displays a row of text. Used for the Retro][ text video mode.
}} 
PRI display_retroii_textrow(row, mem_loc, blink) | data, col, flashing, inverse, type
    col := 0
    
    
    repeat 40 'columns
        flashing := false
        inverse := false
        data := read_byte(mem_loc)
        type := $C0 & data
        if type == $40 'flashing text
            flashing := true
            if data == $60 'cursor
                data := $DB
            else
                if data > 95
                    data -= $40 
                 
        elseif type == $00 'inverse
            inverse := true
            if data < 32
                data += $40  
        else
            data -= $80
                         
        if flashing == true 
            if blink == true
                printxy(col, row,  data)   'print char
            else
                printxy(col, row,  32)    'print space   
        elseif inverse == true
            printxy_inverse(col, row,  data)
        else
            printxy(col, row,  data)
                            
        col++
        mem_loc++
    

{{
Summary: Prints general debug info to the bottom of the screen. 
    Right now this is only displaying the state of the soft switches.
}} 
PRI printDebug
    'display current clock freq
    if old_clock <> current_clock 'only run when the clock value has changed to avoid flicker.
        old_clock := current_clock
        setPos(0, 29)
        str( string("CLOCK(HZ): "))
        str( string("           ")) 'clear screen value
        setPos(10, 29)
        dec( clock_freqs[current_clock])
  
    'display soft switches
    setPos(28, 26)
    str( string("HIRES: "))
    hex( ss_hires, 2)
    setPos(28, 27)
    str( string("PAGE2: "))
    hex( ss_page2, 2)
    setPos(28, 28)
    str( string("MIX:   "))
    hex( ss_mix, 2)
    setPos(28, 29)
    str( string("TEXT:  "))
    hex( ss_text, 2)  

{{
Summary: Clears the screen
}}                                                   
PRI cls
    R2.ClearScreen

{{
Summary: Sets the position of the text pointer on the screen. 
}} 
PRI setPos(x, y)
    R2.Pos(x, y)

PRI print_inverse( char)
    R2.RChar (char)
    
PRI print( char)
    R2.Char(char)

PRI printxy(x, y,  char)
    setPos(x, y)
    print( char)

PRI printxy_inverse(x, y,  char)
    setPos(x, y)
    print_inverse( char)
    
PRI str( string_ptr) 
    repeat strsize(string_ptr)
        print( byte[string_ptr++]) 


PRI strxy(x, y,  string_ptr)
 
    setPos(x, y)
    str( string_ptr) 


PRI dec( val) 
 
    prn( val)


PRI prn( val) | dig

    dig := 48 + (val // 10)
    val := val/10
    if val > 0
        prn( val)
    print( dig)


PRI decxy(x, y,  val)

    setPos(x, y)
    dec( val)


PRI bin( value, digits)
  
    value <<= 32 - digits
    repeat digits
        print( (value <-= 1) & 1 + "0") 


PRI binxy(x, y,  value, digits)

    setPos(x, y)
    bin( value, digits)


PRI hex( value, digits) 

    value <<= (8 - digits) << 2
    repeat digits
        print( lookupz((value <-= 4) & $f : "0".."9", "A".."F")) 


PRI hexxy(x, y,  value, digits)

    setPos(x, y)
    hex( value, digits)

{{
Summary: writes a byte of memory to external RAM
Params:
    data_out:   the byte of data to write
    address:    the address to write the data to
}} 
pri write_byte(data_out, address) | i, msb, lsb
    'to write:
    lsb := address 
    msb := address >> 8

    'we should start high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~  'input /avoid bus contention
    'set address pins
    outa[A7..A0] := lsb 
    outa[A14..A8] := msb
    outa[A15] := msb >> 7
    'set we pin low for specified time
    outa[WE]~
    dira[D0..D7]~~  'output /avoid bus contention
    'set data pins
    outa[D7..D0] := data_out
    'bring we pin high to complete write
    outa[WE]~~
    dira[D0..D7]~  'input /avoid bus contention
    outa[A0..A7] := %00000000 'low
    outa[A8..A14] := %0000000 'low
    outa[A15]~ 'low

{{
Summary: reads a byte of memory from external RAM
Params:
    address:    the address to read from
Returns:
    byte of data read from memory address
}} 
pri read_byte(address) | data_in, i, msb, lsb
    'to read:   
    lsb := address 
    msb := address >> 8
    'set we pin high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~
    'set address pins
    outa[A7..A0] := lsb
    outa[A14..A8] := msb
    outa[A15] := msb >> 7
    'wait specified time
    'read data pins
    data_in := ina[D7..D0]
    outa[A0..A7] := %00000000 'low
    outa[A8..A14] := %0000000 'low
    outa[A15]~ 'low                          
    return data_in
     
