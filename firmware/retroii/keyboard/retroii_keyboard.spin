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
    SDA_pin = 14
    SCL_pin = 13
    Bitrate = 400_000
    TX_FLAG = 26    'I2C register set when there's a byte being transmitted
    RX_FLAG = 27    'I2C register set when byte is received at video processor
    TX_DATA = 28    'I2C register which holds the byte being transmitted
    REG_FLAG = $FA  'this value indicates that the tx_flag or rx_flag is set
    RX_READY = 25   'this register set when video processor ready to receive
    TXRX_TIMEOUT = 1_000
    {CLOCK}
    Btn_Phi2 = 11
    Prop_Phi2 = 12
    {SOFT SWITCHES}
    SS_LOW = 4
    SS_HIGH = 7
    {RESET}
    RESET_pin = 24
    RESET_PERIOD  = 20_000_000 '1/2 second
    {KEYBOARD RETRO][}
    Strobe = 25
    K0 = 17
    K6 = 23
    {MODES}
    MODE_MONITOR = 1
    MODE_RETROII = 2
    MODE_ASSEMBLER = 3
    MODE_SD_CARD_1 = 4 'disk selection
    MODE_SD_CARD_2 = 5 'program selection
    MODE_SD_CARD_3 = 6 'program download            
    {SD CARD}
    SD_PINS  = 0
    RESULTS_PER_PAGE = 29
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'limiting to 300 for now due to memory limits
OBJ 
    sd: "fsrw" 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 'od or open drain method requires pull ups on sda/scl lines. But may use this if I need a speed boost.
    'I2C : "I2C PASM driver v1.8pp" 
    button: "Button"
DAT



VAR
    word key               
    long phi2_stack[20]  
    long cog_phi2 
    long soft_switches_old                                         
    long kb_output_data
    long current_mode
    {sd card}
    byte tbuf[14]   '
    long file_count'
    long current_page'
    long last_page'
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename '

PUB main | soft_switches
    init
    ser.Str(string("initializing keyboard..."))
    
    repeat     
        soft_switches := ina[SS_LOW..SS_HIGH]           'send soft switch to register 30 of video processor
        'only send soft_switches when their value changes
        if soft_switches_old <> soft_switches
            ser.Str (string("soft switches updated: "))
            ser.Hex (soft_switches, 2)
            I2C.writeByte($42,30,soft_switches) 
            soft_switches_old := soft_switches
            
        'key := kb.getkey 
        'ser.Dec (key) 
        
        key := kb.key
        
        if key == 200 or key == 201 'backspace or delete
            if current_mode == MODE_RETROII
                kb_write($88) 'sending left arrow
        if key == 208 'f1 toggle kb to data bus
            kb_output_data := !kb_output_data
            ser.Str (string("toggling kb_output_data : "))
            ser.Dec (kb_output_data)
        if key == 209 'f2 toggle clock speed
        
        if key == 210 'f3 mode monitor
            'send i2c to video processor to tell it to switch modes
            I2C.writeByte($42,29,MODE_MONITOR)  
            current_mode := MODE_MONITOR
            kb_output_data := false
        if key == 211 'f4 mode RETROII
            I2C.writeByte($42,29,MODE_RETROII)  
            current_mode := MODE_RETROII    
            kb_output_data := true   
        if  key == 212 'f5 reset
            'toggle reset line
            outa[RESET_pin] := 0
            dira[RESET_pin] := 1 'set reset pin as output
            waitcnt(RESET_PERIOD + cnt)
            outa[RESET_pin] := 1
            dira[RESET_pin] := 1
            waitcnt(RESET_PERIOD + cnt)
            dira[RESET_pin] := 0 
            'ser.Str (string("reset pressed"))
        if  key == 213 'f6 sd card
            ser.Str (string("entering sd card mode"))
            I2C.writeByte($42,29,MODE_SD_CARD_1)  
            current_mode := MODE_SD_CARD_1   
            kb_output_data := false
            sd_send_filenames(0)
        if key < 128 and key > 0
            I2C.writeByte($42,31,key)
            if kb_output_data == true   'determine where to send key to data bus
                kb_write(key)

{{read file names for page number from sd card and send them to video processor}}
PRI sd_send_filenames(page) | count, page_count, count2, count_files_sent, ready, i
    'determine if this is the first read of the card
    'if it is, fill buffer with file names and indexes
    'else send the appropriate page to video processor
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
    
    set_tx_ready 'wait for tx ready
    'send header info  
    'tx_byte($01)      
    'tx_byte($01)
    'tx_byte($03)   
    tx_byte(last_page + 1)
    'ser.Str(string("sent last_page="))
    'ser.Hex(last_page,2)
    tx_byte(page + 1)
    'ser.Str(string("sent current_page="))
    'ser.Hex(page,2)
    tx_byte(count_files_sent)
    'ser.Str(string("sent count_files_sent="))
    'ser.Hex(count_files_sent,2)
    'stop_tx_ready 'stop rx for now
                  '
                  
    repeat while count < RESULTS_PER_PAGE and (count2 < file_count - 1)
      count2 := page_count + count
      
      'send filename
      
      ser.Str (@files[ROWS_PER_FILE * count2])
      'each file name is 4 longs which should be 16 bytes long
      i := 0
      repeat 16
        tx_byte(byte[@files[ROWS_PER_FILE * count2]][i])
        i++
        
      tx_byte($03) 'end of text
      
      count++
    'update sd card mode to next phase
     
    tx_byte($04) 'end of transmission
    'stop_tx_ready
    
PRI stop_tx_ready 
    I2C.writeByte($42,RX_READY,$00) 'put rx back in non receiving state
                                    
PRI set_tx_ready | ready, i
    'clear flags
    I2C.writeByte($42,TX_FLAG,$00)
    I2C.writeByte($42,RX_FLAG,$00)
    i := 0
    'wait for receiver to be ready
    repeat while ready <> REG_FLAG
        ready := I2C.readByte($42,RX_READY)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("timed out"))
            return 'timeout

PRI tx_byte(data) | success, ready, i
    'make sure receiver is ready
    ready := 0
    i := 0
    repeat while ready <> REG_FLAG
        ready := I2C.readByte($42,RX_READY)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("timed out"))
            return 'timeout
    'need to wait till tx_flag is cleared by video processor
    ready := REG_FLAG
    i := 0
    repeat while ready == REG_FLAG
        ready := I2C.readByte($42,TX_FLAG)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("timed out"))
            return 'timeout
        
    I2C.writeByte($42,RX_FLAG,$00)      'clear rx flag
    I2C.writeByte($42,TX_DATA,data)     'place data in tx_byte register  
    I2C.writeByte($42,TX_FLAG,REG_FLAG)      'set tx flag
    ser.Str (string("data sent="))
    ser.Hex (data, 2)
    'read rx_flag until the flag is set
    success := $00
    i := 0
    repeat while success <> REG_FLAG
        success := I2C.readByte($42,RX_FLAG)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("timed out"))
            return 'timeout
                                        
    
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
    outa[K6..K0] := data_out 'had to reverse order for it to show on data bus correctly
    
    outa[Strobe]~~ 'strobe high should set K7 high
    
    'clear strobe
    outa[Strobe]~
    
PRI init 
    'dira[Prop_Phi2]~~  'output
    'outa[Prop_Phi2]~   'low
    'dira[Btn_Phi2]~  'input
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
    soft_switches_old := ina[SS_LOW..SS_HIGH] 'populate our soft switch var so we can tell if it changes later
    current_mode := MODE_RETROII
    file_count := 0
    'cog_phi2 := cognew(process_phi2, @phi2_stack)   
    'cog_i2c := cognew(process_i2c, @i2c_stack)  
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start


pri process_phi2
  dira[Prop_Phi2]~~  'output
  outa[Prop_Phi2]~   'low
  repeat
    '!outa[Prop_Phi2]
    'Returns true only if button pressed, held for at least 80ms and released.
    if button.ChkBtnPulse(Btn_Phi2, 1, 80)
        'ser.Str (string("button pushed"))
        !outa[Prop_Phi2] 'toggle phi2
