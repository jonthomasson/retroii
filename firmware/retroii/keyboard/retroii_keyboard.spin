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
    TXRX_TIMEOUT = 10_000
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
    FILE_BUF_SIZE = 256 'size of file buffer. can optimize this later on.

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
    byte file_buffer[FILE_BUF_SIZE]
    byte tslist_buffer[FILE_BUF_SIZE]
    
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
            if current_mode == MODE_SD_CARD_1
                I2C.writeByte($42,29,MODE_SD_CARD_2)  
                current_mode := MODE_SD_CARD_2   
                sd_send_catalog(key)     
            I2C.writeByte($42,31,key)
            if kb_output_data == true   'determine where to send key to data bus
                kb_write(key)
                
{{parse the Apple DOS dsk image and send the catalog data for the selected program}}
PRI sd_send_catalog(dsk_idx) | dsk_name,i, y,file_type, file_name, file_length_ls, file_length_ms, bytes_read,tslist_track, tslist_sector, cat_track, cat_sector, dos_ver, dsk_vol, next_cat_track, next_cat_sector
    'send catalog for dsk index entered
    dsk_name := sd_get_filename_byindex(ascii_2bin(dsk_idx))
    ser.Str(string("sending file: "))
    ser.Str(dsk_name)
    
    set_tx_ready 'wait for tx ready
    'send disk name
    
    'each file name is 4 longs which should be 16 bytes total
    i := 0
    repeat 16
        tx_byte(byte[dsk_name][i])
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
    
    next_cat_track := byte[@file_buffer][1]
    next_cat_sector := byte[@file_buffer][2]
    
    'get count of catalog contents
    i := 0
    repeat i from 0 to 6
        if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
            quit
        'i++
            
    tx_byte(i) 'send count of files
                       
    'loop through catalog and print file info
    i := 0    
    repeat i from 0 to 6
        if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
            next
            
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
        
        y := 0
        repeat 30
            file_name := byte[@file_buffer][14 + y + (35 * i)]
            y++
            ser.Hex (file_name,2)
            tx_byte(file_name)
        
        tx_byte(file_type)
        tx_byte(file_length_ls)
        'tx_byte(file_length_ms)
            
        ser.Str (string("File Length:"))
        ser.Hex (file_length_ls, 2)
        ser.Hex (file_length_ms, 2)
    'tx_byte($04) 'end of transmission

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

PRI sd_get_filename_byindex(index) | open_error, file_name
    file_name := @files[ROWS_PER_FILE * ((current_page * RESULTS_PER_PAGE) + (index - 1))]
    
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
            ser.Str(string("rxtimed out"))
            return 'timeout
    'need to wait till tx_flag is cleared by video processor
    ready := REG_FLAG
    i := 0
    repeat while ready == REG_FLAG
        ready := I2C.readByte($42,TX_FLAG)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("txtimed out"))
            return 'timeout
        
    I2C.writeByte($42,RX_FLAG,$00)      'clear rx flag
    I2C.writeByte($42,TX_DATA,data)     'place data in tx_byte register  
    I2C.writeByte($42,TX_FLAG,REG_FLAG)      'set tx flag
    ser.Str (string("sending "))
    ser.Hex (data, 2)
    'read rx_flag until the flag is set
    success := $00
    i := 0
    repeat while success <> REG_FLAG
        success := I2C.readByte($42,RX_FLAG)
        i++
        if i > TXRX_TIMEOUT
            ser.Str(string("noresponsetimed out"))
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
