''*******************************
''* keyboard  9/2019                                                                    *
''* Author: Jon Thomoasson                                                              *
''* Description: firmware that runs on the keyboard processor for the RETRO ][ computer * 
''*******************************
''
''
CON
    _clkmode  = xtal1 + pll16x
    _xinfreq  = 5_000_000
    rx = 31
    tx = 30
    NUM        = %100
    RepeatRate = 40
    SDA_pin = 15
    SCL_pin = 14
    Bitrate = 400_000
    SLAVE_ID = $42
    MODE_REG = 29
    TX_FLAG = 26    'I2C register set when there's a byte being transmitted
    RX_FLAG = 27    'I2C register set when byte is received at video processor
    TX_DATA = 28    'I2C register which holds the byte being transmitted
    REG_FLAG = $FA  'this value indicates that the tx_flag or rx_flag is set
    RX_READY = 25   'this register set when video processor ready to receive
    CMD_FLAG = 24   'I2C register used to send commands to video processor
    CMD_RESET = $EA 'this value tells the video processor to reset the 6502
    CMD_RETROII = $BD 'command to set video mode to retroii mode
    CMD_DONE = $AC  'this value is an acknowledgement that the command has finished
    TXRX_TIMEOUT = 10_000
    CMD_REG = 22    'register for sending commands to the other processor
    CMD_DEBUG = $F1 'command tells video processor to toggle the debug screen
    COLOR_REG = 21
    CMD_CHANGE_COLOR = $B3
    
    {CLOCKS}
    'Btn_Phi2 = 11
    Prop_Phi2 = 12 'Clock generator output Phi0/Phi2 pin P12 - physical pin 17
    Prop_Phi1 = 16 'Phi1 to pin P15 - physical pin 20 (originally RDY) - cut trace and wire to H2 pin 5
    Prop_Q3 = 13 '2MHz clock signal for peripheral cards slots - used by floppy uController
    MAX_CLOCK = 8 'the maximum frequency in MHz that we'll overclock
    CLOCK_REG = 23 'i2c register to hold clock value
    
    {SOFT SWITCHES}
    SS_LOW = 4
    SS_HIGH = 7
    SS_REG = 30
    
    {RESET}
    RESET_pin = 24
    RESET_PERIOD  = 20_000_000 '1/2 second
    
    {KEYBOARD RETRO][}
    Strobe = 25
    K0 = 17
    K6 = 23
    KEY_REG = 31
    
    {MODES}
    MODE_MONITOR = 1
    MODE_RETROII = 2
    MODE_ASSEMBLER = 3
    MODE_SD_CARD_1 = 4 'disk selection
    MODE_SD_CARD_2 = 5 'program selection
    MODE_SD_CARD_3 = 6 'program download            
    
    {SD CARD}
    SD_PINS  = 0
    RESULTS_PER_PAGE = 56
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'limiting to 300 for now due to memory limits
    FILE_BUF_SIZE = 256 'size of file buffer. can optimize this later on.
    LINE_BUF_SIZE = 10
    
    {FILE OPTIONS FOR MODE_SD_CARD_3}
    FILE_LOAD = 1
    FILE_RUN = 2  
OBJ 
    sd: "fsrw" 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 'od or open drain method requires pull ups on sda/scl lines. But may use this if I need a speed boost.
    'I2C : "I2C PASM driver v1.8pp" 
    'button: "Button"
DAT



VAR
    word key          
    long prog_download_option     
    long phi2_stack[20]  
    long cog_phi2 
    long soft_switches_old                                         
    long kb_output_data
    long current_mode
    long current_disk 'index of currently selected disk
    long current_clock 'current frequency in MHz for clock feeding the 6502
    long cat_track
    long cat_sector
    {sd card}
    byte tbuf[14]   '
    long file_count'
    long current_page'
    long last_page'
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename '
    byte file_buffer[FILE_BUF_SIZE]
    byte tslist_buffer[FILE_BUF_SIZE]
    byte line_buffer[LINE_BUF_SIZE]
    byte ss_override
    byte ss_text
    byte ss_mix
    byte ss_page2
    byte ss_hires
    byte ss_mask
    byte ss_text_override
    byte ss_page2_override
    byte ss_hires_override
    byte ss_mix_override
    long clock_freqs[10]
    long kb_clear
    
PUB main | soft_switches, i, frq
    init
    ser.Str(string("initializing keyboard..."))
    
    'frq := frqVal(6589440, clkfreq)
    
    'ser.Dec (frq)
    
    repeat     
        
        soft_switches := ina[SS_LOW..SS_HIGH]           'send soft switch to register 30 of video processor
        
        if ss_override == 255
            if ss_text_override == 255
                'clear appropriate soft_switches bit and or in the new one
                ss_mask := (ss_text & $01)
                soft_switches &= $FE
                soft_switches |= ss_mask
                
            if ss_mix_override == 255
                ss_mask :=(ss_mix & $02)
                soft_switches &= $FD
                soft_switches |= ss_mask
                
            if ss_page2_override == 255
                ss_mask := (ss_page2 & $04)
                soft_switches &= $FB
                soft_switches |= ss_mask
                
            if ss_hires_override == 255
                ss_mask := (ss_hires & $08)
                soft_switches &= $F7
                soft_switches |= ss_mask
                
            
        'only send soft_switches when their value changes
        if soft_switches_old <> soft_switches
            ser.Str (string("soft switches updated: "))
            ser.Hex (soft_switches, 2)
            I2C.writeByte(SLAVE_ID,SS_REG,soft_switches) 
            soft_switches_old := soft_switches
            
        'key := kb.getkey 
        'ser.Hex (key,2) 
        
        key := kb.key
        
        
        if  key < 128 and key > 0
            if key > 96 and key < 123 'convert to uppercase
                key -= $20 'subtract 32
                               
            if current_mode == MODE_RETROII
                kb_write(key)
              
            elseif current_mode == MODE_SD_CARD_1
                if key == $0D 'enter
                    if i > 0 'valid input
                        I2C.writeByte(SLAVE_ID,MODE_REG,MODE_SD_CARD_2)  
                        current_mode := MODE_SD_CARD_2   
                        sd_send_catalog(i)   
                        i := 0 'start line buffer over    
                    
                        prog_download_option := 0          
                else
                    'write to line buffer
                    if key > 47 and key < 58 'valid number 0-9
                        line_buffer[i] := key
                        i++
                        
                  
            elseif current_mode == MODE_SD_CARD_2
                if key == $0D 'enter
                    if i > 0 'valid input
                        I2C.writeByte(SLAVE_ID,MODE_REG,MODE_SD_CARD_3)  
                        current_mode := MODE_SD_CARD_3   
                        sd_send_file(i)
                        i := 0 'start line buffer over  
                       
                        prog_download_option := 0
                else
                    'write to line buffer
                    if prog_download_option == 0
                        'check to make sure we get either a R or L
                        if key == "L" 
                            prog_download_option := FILE_LOAD
                        elseif key == "R"
                            prog_download_option := FILE_RUN
                    else
                        if key > 47 and key < 58 'valid number 0-9
                            line_buffer[i] := key
                            i++
            if current_mode <> MODE_RETROII       
                I2C.writeByte(SLAVE_ID,KEY_REG,key)
            'if kb_output_data == true   'determine where to send key to data bus
            '    kb_write(key)
        elseif key == 200 or key == 201 'backspace or delete
            kb_write($88) 'sending left arrow
        elseif key == 203 'send esc
            kb_write($9B) 'sending left arrow
        elseif key == 192 'send left arrow
            if current_mode == MODE_RETROII
                kb_write($88)
                
            elseif current_mode == MODE_SD_CARD_1
                if current_page > 0
                    current_page--
                    I2C.writeByte(SLAVE_ID,KEY_REG,key)
                    sd_send_filenames(current_page)
        elseif key == 193 'send right
            if current_mode == MODE_RETROII
                kb_write($95)
              
            elseif current_mode == MODE_SD_CARD_1
                if current_page < last_page
                    current_page++
                    I2C.writeByte(SLAVE_ID,KEY_REG,key)
                    sd_send_filenames(current_page)
        elseif key == 208 'f1 toggle monochrome color
            I2C.writeByte(SLAVE_ID,COLOR_REG,CMD_CHANGE_COLOR)
            'kb_output_data := !kb_output_data
            'ser.Str (string("toggling kb_output_data : "))
            'ser.Dec (kb_output_data)
        elseif key == 209 'f2 toggle debug screen
            I2C.writeByte(SLAVE_ID,CMD_REG,CMD_DEBUG)
        elseif key == 210 'f3 mode monitor
            'send i2c to video processor to tell it to switch modes
            kb_output_data := false
            I2C.writeByte(SLAVE_ID,MODE_REG,MODE_MONITOR)  
            current_mode := MODE_MONITOR
        elseif key == 211 'f4 mode RETROII
            kb_output_data := true 
            I2C.writeByte(SLAVE_ID,MODE_REG,MODE_RETROII)  
            current_mode := MODE_RETROII    
        elseif  key == 212 'f5 reset
            'toggle reset line
            reset
        elseif  key == 213 'f6 sd card
            kb_output_data := false
            i := 0 'start line buffer over
            ser.Str (string("entering sd card mode"))
            I2C.writeByte(SLAVE_ID,MODE_REG,MODE_SD_CARD_1)  
            current_mode := MODE_SD_CARD_1   
            sd_send_filenames(current_page)
        elseif  key == 216 or key == 217 or key == 218 or key == 219 'F9-F12 manual soft switch override
            if ss_override == FALSE
                'populate overriden vars with current values
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
                
                ss_override := TRUE
            if key == 216 'hires
                ss_hires_override := TRUE
                ss_hires := !ss_hires
                
            if key == 217 'page2
                ss_page2_override := TRUE
                ss_page2 := !ss_page2
                
            if key == 218 'mix
                ss_mix_override := TRUE
                ss_mix := !ss_mix
                
            if key == 219 'text
                ss_text_override := TRUE
                ss_text := !ss_text  
                
        elseif  key == 214 'F7 clear kb 
            kb_write($00)  
            kb_clear := FALSE   
        elseif key == 220 'set clear kb mode
            kb_clear := 255 '!kb_clear   
        elseif  key == 215 'F8 turn off soft switch override
            ss_override := FALSE  
            ss_text_override := FALSE
            ss_mix_override := FALSE
            ss_hires_override := FALSE
            ss_page2_override := FALSE        
        elseif  key == 194 'up arrow = increase prop clock frequency
            if current_clock < 10
                current_clock++
                'call set frequency function
                set_clock("A",Prop_Phi2,clock_freqs[current_clock])
                'pass current_clock to video processor for debug screen
                I2C.writeByte(SLAVE_ID,CLOCK_REG,current_clock) 
        elseif  key == 195 'down arrow = decrease prop clock frequency
            if current_clock > 0
                current_clock--           
                'call set frequency function 
                set_clock("A",Prop_Phi2,clock_freqs[current_clock])
                'pass current_clock to video processor for debug screen
                I2C.writeByte(SLAVE_ID,CLOCK_REG,current_clock)
                           
{{use this to get my frqa value to run the vga driver
a = frequency desired
b = clock frequency (CLKFREQ etc)

f = returns frequency value to set frqa
}}
PRI frqVal(a, b) : f      ' return f = a/b * 2^32, given a<b, a<2^30, b<2^30
  repeat 32                           ' 32 bits
     a <<= 1
     f <<= 1
     if a => b
        a -= b
        f++

PUB set_clock(CTR_AB, Pin, Freq) | s, d, ctr, frq

  Freq := Freq #> 0 <# 128_000_000     'limit frequency range
  
  if Freq < 500_000                    'if 0 to 499_999 Hz,
    ctr := constant(%00100 << 26)      '..set NCO mode
    s := 1                             '..shift = 1
  else                                 'if 500_000 to 128_000_000 Hz,
    ctr := constant(%00010 << 26)      '..set PLL mode
    d := >|((Freq - 1) / 1_000_000)    'determine PLLDIV
    s := 4 - d                         'determine shift
    ctr |= d << 23                     'set PLLDIV
    
  frq := fraction(Freq, CLKFREQ, s)    'Compute FRQA/FRQB value
  ctr |= Pin                           'set PINA to complete CTRA/CTRB value
  'ser.Str (string("frq: "))
  'ser.Dec (frq) 
  if CTR_AB == "A"
     CTRA := ctr                        'set CTRA
     FRQA := frq                        'set FRQA                   
     DIRA[Pin]~~                        'make pin output
     
  if CTR_AB == "B"
     CTRB := ctr                        'set CTRB
     FRQB := frq                        'set FRQB                   
     DIRA[Pin]~~                        'make pin output


PUB set_clock_simple
{{Set clock output to 1,0205MHz with differential output and Q3 at double that = 2,041MHz approx}}
  DIRA[Prop_Phi2]~~  'output
  OUTA[Prop_Phi2]~   'low

  DIRA[Prop_Phi1]~~
  OUTA[Prop_Phi1]~

  DIRA[Prop_Q3]~~
  OUTA[Prop_Q3]~   'low

      '         Mode             Divider        Pin B      Pin A
  CTRB := (%00011 << 26) + (%001 << 23) + (Prop_Phi1 << 9) + Prop_Phi2
  FRQB := 219_150_706 'for 1.020.500 Hz

      '         Mode             Divider        Pin B      Pin A
  CTRA := (%00010 << 26) + (%010 << 23) + (0 << 9) + Prop_Q3
  FRQA := 219_150_706
  
  
PRI fraction(a, b, shift) : f

  if shift > 0                         'if shift, pre-shift a or b left
    a <<= shift                        'to maintain significant bits while 
  if shift < 0                         'insuring proper result
    b <<= -shift
 
  repeat 32                            'perform long division of a/b
    f <<= 1
    if a => b
      a -= b
      f++           
    a <<= 1


PRI reset
    'toggle reset line
    outa[RESET_pin] := 0
    dira[RESET_pin] := 1 'set reset pin as output
    waitcnt(RESET_PERIOD + cnt)
    outa[RESET_pin] := 1
    dira[RESET_pin] := 1
    waitcnt(RESET_PERIOD + cnt)
    dira[RESET_pin] := 0 
                    
{{send the selected file to RAM}}                
PRI sd_send_file(line_size) | ready, ran_once, bytes_read, file_name, y, i, next_cat_sector, next_cat_track, index, next_data_track,next_data_sector, tslist_track, tslist_sector, file_type, offset, dsk_name, next_tslist_track, next_tslist_sector, is_basic
        'populate dsk_idx from line_buffer
    if line_size == 1
        index := ascii_2bin(line_buffer[0])
    
    else '2
        'multiply 2nd num entered by 10 and add to first number
        index := (ascii_2bin(line_buffer[0]) * 10) + ascii_2bin(line_buffer[1])
        
    'send file name, address, length, bytes
    is_basic := FALSE
    ran_once := FALSE
    'index := ascii_2bin(file_idx)
    dsk_name := sd_get_diskname_byindex(current_disk)
    ser.Str(string("disk: "))
    ser.Str(dsk_name)
    
    ready := $00
    if prog_download_option == FILE_RUN 'if file is being run, wait for command to reset
        repeat while ready <> CMD_RESET
            ready := I2C.readByte(SLAVE_ID,CMD_FLAG)   
        
        reset 'reset computer    
        ser.Str(string("computer reset"))
        I2C.writeByte(SLAVE_ID,CMD_FLAG, CMD_DONE) 'send ack back to video processor
         
    'start at first catalog sector so we can count to see where our index falls
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, cat_track, cat_sector)
    
    'fast forward to sector that holds our index file
    y := 0
    repeat 
        i := 0
        repeat i from 0 to 6 'up to 7 total file descriptive entries per sector
            if y + i == (index - 1)
                next_cat_sector := $00 'get out of loop
                quit
            if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
                next_cat_sector := $00 'get out of loop
                quit
 
        y := y + i 
            
        if next_cat_sector == $00
            quit
         
        next_cat_track := byte[@file_buffer][1]
        next_cat_sector := byte[@file_buffer][2]
        'ser.Str (string("next_cat_sector:"))
        'ser.Dec (next_cat_sector)
        if next_cat_sector <> $00
            goto_sector(dsk_name, next_cat_track, next_cat_sector)
        
    while next_cat_sector <> $00
    
    offset := 35 * i '(index - 1)
    'ser.Dec (index)
    'file_name := sd_get_filename_byindex(index)
    ser.Str(string("sending file: "))
    'ser.Str(file_name)
    set_tx_ready
    
    'waitcnt(150000 + cnt) 'adding delay for video to catch up
    'i := ascii_2bin(file_idx)
    y := 0
    repeat 30
        file_name := byte[@file_buffer][14 + y + offset]
        y++
        ser.Hex (file_name,2)
        tx_byte(file_name)
        
    'waitcnt(50000 + cnt) 'adding delay for video to catch up
    
    'address
    tslist_track := byte[@file_buffer][11 + offset]
    tslist_sector := byte[@file_buffer][12 + offset]
    file_type := byte[@file_buffer][13 + offset]
    
    'if file_type = Applesoft BASIC ($02) or Integer BASIC ($01), set is_basic flag
    if (($02 & file_type) == $02) or (($01 & file_type) == $01)
        is_basic := TRUE
    
    'navigate to first tslist track/sector of file
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, tslist_track, tslist_sector)
    
    'loop through tslist and find all data sectors and read in the file data  
    repeat 
        'move data to tslist_buffer so I can start iterating over tslist tracks/sectors?
        bytemove(@tslist_buffer, @file_buffer, FILE_BUF_SIZE)
        
        next_tslist_track := byte[@tslist_buffer][1]
        next_tslist_sector := byte[@tslist_buffer][2]
        
        'navigate to all data sectors in this list
        i := 0
        repeat 
            next_data_track := byte[@tslist_buffer][12 + i]
            next_data_sector := byte[@tslist_buffer][13 + i]
            
            bytes_read := 0
            bytes_read := goto_sector(dsk_name, next_data_track, next_data_sector)  
            
            ser.Str (string("data track/sector: "))
            ser.Hex (next_data_track, 2)
            ser.Hex (next_data_sector, 2)
            ser.Str (string(" "))
            ser.Str (string("i="))
            ser.Dec (i)
            y := 0
            'transmit first 4 bytes of data sector (address, length)
            if ran_once == FALSE
                if is_basic == TRUE
                    'for Applesoft Basic: start address is at $0801
                    'for Integer Basic: start address is ($9600 - length)
                    'unfortunately we will need a language card or some other way to 
                    'expand memory to fit Int Basic.
                    tx_byte($01) '$0801 start address for Applesoft basic files
                    tx_byte($08)
               
                    
                    repeat 2
                        ser.Hex (byte[@file_buffer][y], 2)
                        tx_byte(byte[@file_buffer][y])
                        y++
                else
                    'bin file
                       
                    repeat 4
                        ser.Hex (byte[@file_buffer][y], 2)
                        tx_byte(byte[@file_buffer][y])
                        y++  
                
                waitcnt(150000 + cnt)      
                
            ran_once := TRUE
            'transmit data from this data sector
            waitcnt(450000 + cnt) 'adding delay for video to catch up
           
            repeat while y < bytes_read
                ser.Hex (byte[@file_buffer][y], 2)
                tx_byte(byte[@file_buffer][y])
                y++
                
            i := i + 2
        while next_data_track <> $00 and i =< FILE_BUF_SIZE - 13
        
        bytes_read := 0
        bytes_read := goto_sector(dsk_name, next_tslist_track, next_tslist_sector)  
                
        'loop and list data for track/sector
        '
    while next_tslist_track <> $00 'track will read 0 when we are at the end of the file data
    
    ready := $00
    if prog_download_option == FILE_RUN 'if file is being run, wait for command to reset
        repeat while ready <> CMD_RESET
            ready := I2C.readByte(SLAVE_ID,CMD_FLAG)   
            'ser.Hex (ready, 2)
        reset 'reset computer    
        ser.Str(string("computer reset"))
        I2C.writeByte(SLAVE_ID,CMD_FLAG, CMD_DONE) 'send ack back to video processor
        
        if is_basic == FALSE
            ready := $00
            repeat while ready <> CMD_RETROII
                ready := I2C.readByte(SLAVE_ID,CMD_FLAG)   
                'ser.Hex (ready, 2)
            I2C.writeByte(SLAVE_ID,MODE_REG,MODE_RETROII) 
            current_mode := MODE_RETROII    
            ser.Str(string("mode set to retroii"))
            'I2C.writeByte(SLAVE_ID,CMD_FLAG, CMD_DONE) 'send ack back to video processor
                                                          
{{parse the Apple DOS dsk image and send the catalog data for the selected program}}
PRI sd_send_catalog(line_size) | dsk_idx, is_done, dsk_name,i, y, file_type, file_name, file_length_ls, file_length_ms, bytes_read,tslist_track, tslist_sector, dos_ver, dsk_vol, next_cat_track, next_cat_sector
    'populate dsk_idx from line_buffer
    if line_size == 1
        dsk_idx := ascii_2bin(line_buffer[0])
    
    else '2
        'multiply 2nd num entered by 10 and add to first number
        dsk_idx := (ascii_2bin(line_buffer[0]) * 10) + ascii_2bin(line_buffer[1])
       
    'ser.Bin (dsk_idx, 32)
    'send catalog for dsk index entered
    'set current disk
    current_disk := dsk_idx
    dsk_name := sd_get_diskname_byindex(dsk_idx)
    ser.Str(string("sending file: "))
    ser.Str(dsk_name)
    
    set_tx_ready 'wait for tx ready
    'send disk name
    
    'each file name is 4 longs which should be 16 bytes total
    i := 0
    repeat 16
        tx_byte(byte[dsk_name][i])
        waitcnt(50000 + cnt) 'add delay for video to catch up
        i++
    'navigate to catalog of file
    'each Apple DOS formatted dsk consists of 35 tracks
    'each track consists of 16 sectors
    'each sector is 256 bytes in size
    'this yields a total disk size of 146,360
    'track 17 is the VTOC or table of contents which has the 
    'info about where each file is located
    
    'read in the first sector for track 17 (VTOC)
    'we want to fast forward to track 17 sector 1
    'to do this we loop 17 x 16 = 272 (17 tracks x 16 sectors per track)
    'For more info, read "Beneath Apple DOS" 4-4
    
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, 17, 0)
            
    'we should now be at the first sector of VTOC
    'we may use more data from the vtoc once we start writing back to the disk etc.
    cat_track := byte[@file_buffer][1]
    cat_sector := byte[@file_buffer][2]
    dos_ver := byte[@file_buffer][3]
    dsk_vol := byte[@file_buffer][6]
    
    
    ser.Str (string("Catalog Track:"))
    ser.Hex (cat_track, 2)
    ser.Str (string("Catalog Sector:"))
    ser.Hex (cat_sector, 2)
    ser.Str (string("DOS Ver:"))
    ser.Hex (dos_ver, 2)
    ser.Str (string("Volume #:"))
    ser.Hex (dsk_vol, 2)
    tx_byte(dos_ver)
    tx_byte(dsk_vol)
    
    'we have our data from the vtoc, now go to catalog and get our files list
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, cat_track, cat_sector)
    
    'next_cat_track := byte[@file_buffer][1]
    'next_cat_sector := byte[@file_buffer][2]
    
    'get count of catalog contents
    'loop through all of the catalog tracks/sectors to get total count of files
    
    y := 0
    repeat 
        i := 0
        repeat i from 0 to 6 'up to 7 total file descriptive entries per sector
            
            if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
                next_cat_sector := $00 'get out of loop
                quit
 
        y := y + i  
        if next_cat_sector == $00
            quit
         
        next_cat_track := byte[@file_buffer][1]
        next_cat_sector := byte[@file_buffer][2]
        'ser.Str (string("next_cat_sector:"))
        'ser.Dec (next_cat_sector)
        if next_cat_sector <> $00
            goto_sector(dsk_name, next_cat_track, next_cat_sector)
        
    while next_cat_sector <> $00
    tx_byte(y) 'send count of files           
    'rewind back to the first sector of the catalog track
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, cat_track, cat_sector)
    
                    
    is_done := false
    'loop through catalog and print file info
    i := 0  
    repeat  
        
        repeat i from 0 to 6 'up to 7 total file descriptive entries per sector
            if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
                is_done := true
                next
                'next_cat_sector := $00 'get out of loop
                'quit
            
            tslist_track := byte[@file_buffer][11 + (35 * i)]
            tslist_sector := byte[@file_buffer][12 + (35 * i)]
            file_type := byte[@file_buffer][13 + (35 * i)]
            file_name := byte[@file_buffer][14 + (35 * i)]
            file_length_ls := byte[@file_buffer][44 + (35 * i)]
            file_length_ms := byte[@file_buffer][45 + (35 * i)]
        
            ser.Str (string("File Track:"))
            ser.Hex (tslist_track, 2)
            ser.Str (string("File Sector:"))
            ser.Hex (tslist_sector, 2)
            ser.Str (string("File Type:"))
            ser.Hex (file_type, 2)
            ser.Str (string("File Name:"))
            'ser.Hex (file_name, 2)
            waitcnt(150000 + cnt)
            y := 0
            repeat 20 'sending 20 of 30 chars of filename
                waitcnt(150000 + cnt) 'add delay for video to catch up
                file_name := byte[@file_buffer][14 + y + (35 * i)]
                y++
            
                ser.Hex (file_name,2)
                tx_byte(file_name)
            
                                 
            tx_byte(file_type)
            waitcnt(50000 + cnt)
            tx_byte(file_length_ls)
            
            
            ser.Str (string("File Length:"))
            ser.Hex (file_length_ls, 2)
            ser.Hex (file_length_ms, 2)
        
        if is_done == true
            quit
           
        next_cat_track := byte[@file_buffer][1]
        next_cat_sector := byte[@file_buffer][2]
        ser.Str (string("next_cat_sector:"))
        ser.Dec (next_cat_sector) 
        if next_cat_sector <> $00
            goto_sector(dsk_name, next_cat_track, next_cat_sector)
            
    while next_cat_sector <> $00 

PRI ascii_2bin(ascii) | binary

    if ascii < 58                   'if ascii number (dec 48-57)
        binary := ascii -48 'subtract 48 to get dec equivalent
    else
        binary := ascii -55 'else subtract 55 for ABCDEF 
    
    return binary
    
PRI goto_sector(file_name, track_num, sector_num)| sector_count, open_error, bytes_read
    sd.mount(SD_PINS)
    
    open_error := sd.popen(file_name, "r") ' Open file
    
    if open_error == -1 'error opening file
        ser.Str (string("error opening file "))
        sd.unmount
        return 'exit sub
    
    'get sector location 
    sector_count := (track_num * 16) + sector_num
    
    bytes_read := 0
    repeat sector_count
        bytes_read := sd.pread(@file_buffer,FILE_BUF_SIZE)
        
    'navigate to desired sector  
    bytes_read := sd.pread(@file_buffer,FILE_BUF_SIZE)
    
    sd.unmount
    
    return bytes_read

PRI sd_get_filename_byindex(index) | file_name, y
    
    'i := ascii_2bin(index)
    'i := 1
    'ser.dec (i)
    y := 0
    repeat 30
        file_name := byte[@file_buffer][14 + y + (35 * (index - 1))]
        y++
        ser.Hex (file_name,2)
        
    return file_name
    
    

PRI sd_get_diskname_byindex(index) | open_error, file_name
    file_name := @files[ROWS_PER_FILE * ((current_page * RESULTS_PER_PAGE) + (index - 1))]
    'ser.dec (index)
    return file_name
       
{{read file names for page number from sd card and send them to video processor}}
PRI sd_send_filenames(page) | count, page_count, count2, count_files_sent, ready, i
    'determine if this is the first read of the card
    'if it is, fill buffer with file names and indexes
    'else send the appropriate page to video processor
    current_page := page
    if file_count == 0
        ser.Str (string("loading files into memory"))
        sd_load_files
    
    ser.Str (string("files loaded")) 
    ser.Dec (file_count)   
    count := 0  
    count2 := 0  
    count_files_sent := 0
    page_count := page * RESULTS_PER_PAGE
    ready := 0
    
    if file_count < RESULTS_PER_PAGE
        count_files_sent := file_count
    elseif page < last_page
        count_files_sent := RESULTS_PER_PAGE
    else
        count_files_sent := file_count - page_count
    waitcnt(100000 + cnt)
    set_tx_ready 'wait for tx ready
    'send header info  
    'tx_byte($01)      
    'tx_byte($01)
    'tx_byte($03)   
    waitcnt(100000 + cnt) 'add delay for video to catch up
    tx_byte(last_page + 1)
    'ser.Str(string("sent last_page="))
    'ser.Hex(last_page,2)
    waitcnt(50000 + cnt)
    tx_byte(page + 1)
    'ser.Str(string("sent current_page="))
    'ser.Hex(page,2)
    waitcnt(50000 + cnt)
    tx_byte(count_files_sent)
    'ser.Str(string("sent count_files_sent="))
    'ser.Hex(count_files_sent,2)
    'stop_tx_ready 'stop rx for now
                  '
    waitcnt(250000 + cnt) 'add delay for video to catch up              
    repeat while count < RESULTS_PER_PAGE and (count2 < file_count - 1)
      count2 := page_count + count
      
      'send filename
      
      ser.Str (@files[ROWS_PER_FILE * count2])
      'each file name is 4 longs which should be 16 bytes long
      i := 0
      repeat 16
        tx_byte(byte[@files[ROWS_PER_FILE * count2]][i])
        waitcnt(50000 + cnt) 'add delay for video to catch up
        i++
        
      tx_byte($03) 'end of text
      
      count++
    'update sd card mode to next phase
     
    tx_byte($04) 'end of transmission
    'stop_tx_ready
    
PRI stop_tx_ready 
    I2C.writeByte(SLAVE_ID,RX_READY,$00) 'put rx back in non receiving state
                                    
PRI set_tx_ready | ready, i
    'clear flags
    I2C.writeByte(SLAVE_ID,TX_FLAG,$00)
    I2C.writeByte(SLAVE_ID,RX_FLAG,$00)
    i := 0
    'wait for receiver to be ready
    repeat while ready <> REG_FLAG
        ready := I2C.readByte(SLAVE_ID,RX_READY)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("timed out"))
            return 'timeout

PRI tx_byte(data) | success, ready, i
    
    I2C.writeByte(SLAVE_ID,TX_DATA,data)     'place data in tx_byte register  
    
                                        
    
PRI sd_load_files | index
  sd.mount(SD_PINS) ' Mount SD card
  sd.opendir    'open root directory for reading
  
  'loading file names from sd card into ram for faster paging              
  repeat while 0 == sd.nextfile(@tbuf) 
    
      ' so I need a second file to open and query filesize
      'sd[1].popen( @tbuf, "r" )
      
      'save file size in file_sizes array
      'file_sizes[file_count] := sd[1].get_filesize
      'sd[1].pclose      
      
      'move tbuf to files. each file takes up 4 rows of files
      'each row can hold 4 bytes (32 bit long / 8bit bytes = 4)
      'since the short file name needs 13 bytes (8(name)+1(dot)+3(extension)+1(zero terminate))
      bytemove(@files[ROWS_PER_FILE*file_count],@tbuf,strsize(@tbuf))
      
      file_count++
  
  last_page := file_count / RESULTS_PER_PAGE
  
  sd.unmount 'unmount the sd card
             '
PRI kb_write(data_out) | i
    'if current_mode == MODE_RETROII
    outa[K6..K0] := data_out 'had to reverse order for it to show on data bus correctly
    outa[Strobe]~~ 'strobe high should set K7 high   
    'clear strobe
    outa[Strobe]~
    
    if kb_clear == 255
        waitcnt(2000000 + cnt)
        outa[K6..K0] := $00
        outa[Strobe]~~
        outa[Strobe]~
    '    waitcnt(2000000 + cnt)
    '    kb_write($00)
        
PRI init 
    
    dira[K0..K6]~~ 'set keyboard data pins to output
    dira[Strobe]~~ 'set strobe pin to output
    outa[K0..K6] := %0000000 'low
    outa[Strobe]~ 'strobe low
    dira[SS_LOW..SS_HIGH]~
    kb_output_data := true
    dira[RESET_pin]~ 'input
    'outa[RESET_pin]~~ 'high           
    I2C.start(SCL_pin,SDA_pin,Bitrate)
    ser.Start(rx, tx, 0, 115200)
    kb.startx(26, 27, NUM, RepeatRate) 
    kb_clear := FALSE
    
    'init clock freq array
    clock_freqs[0]  := 0
    clock_freqs[1]  := 1_000
    clock_freqs[2]  := 10_000
    clock_freqs[3]  := 50_000
    clock_freqs[4]  := 100_000
    clock_freqs[5]  := 250_000
    clock_freqs[6]  := 500_000
    clock_freqs[7]  := 1_020_500 'original clock speed of the Apple ][. Taken from "Understanding The Apple" page 3-3.
    clock_freqs[8]  := 2_041_000
    clock_freqs[9]  := 3_000_000
    clock_freqs[10] := 4_000_000
    
    dira[Prop_Phi2]~~  'output
    outa[Prop_Phi2]~   'low 
    dira[Prop_Phi1]~~  'output
    outa[Prop_Phi1]~   'low
    dira[Prop_Q3]~~  'output
    outa[Prop_Q3]~   'low
    
    set_clock_simple                   
    
    'set_clock("A",Prop_Phi2,clock_freqs[7])
    current_clock := 7 'default to 1MHz
    I2C.writeByte(SLAVE_ID,CLOCK_REG,current_clock) 
    
    soft_switches_old := ina[SS_LOW..SS_HIGH] 'populate our soft switch var so we can tell if it changes later
    ss_page2_override := FALSE
    ss_mix_override := FALSE
    ss_text_override := FALSE
    ss_hires_override := FALSE
    
    current_mode := MODE_RETROII
    file_count := 0
    ss_override := FALSE
    prog_download_option := 0
    'cog_phi2 := cognew(process_phi2, @phi2_stack)   
    'cog_i2c := cognew(process_i2c, @i2c_stack)  
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start


'pri process_phi2
'  dira[Prop_Phi2]~~  'output
'  outa[Prop_Phi2]~   'low
'  repeat
'    '!outa[Prop_Phi2]
'    'Returns true only if button pressed, held for at least 80ms and released.
'    if button.ChkBtnPulse(Btn_Phi2, 1, 80)
'        'ser.Str (string("button pushed"))
'        !outa[Prop_Phi2] 'toggle phi2
