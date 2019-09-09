''*******************************
''* retroii_kb_test  8/2019   *
''* Author: Jon Thomoasson    *
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
    
    SD_PINS  = 0
    NUM_COLUMNS = 80 'number of columns in tile map
    NUM_ROWS = 30 'number of rows in tile map
    RESULTS_PER_PAGE = 29
    ROWS_PER_FILE = 4 'number of longs it takes to store 1 file name
    MAX_FILES = 300 'limiting to 300 games for now due to memory limits
    FILE_BUF_SIZE = 256 'size of file buffer. can optimize this later on.
    'commands sent from fpga to prop...
    CMD_PREV_PAGE = $80
    CMD_NEXT_PAGE = $81
    CMD_FIRST_PAGE = $82
    CMD_LAST_PAGE = $83
    CMD_READY = $84 'used to tell prop that it's ready for bitstream/new packet
    CMD_ERROR = $85 'error receiving packet
  
OBJ 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 
    sd[2]: "fsrw" 
DAT



VAR
    word key                                                           
    byte tbuf[14]   
    byte file_buffer[FILE_BUF_SIZE]
    byte tslist_buffer[FILE_BUF_SIZE]
    long file_count
    long current_page
    long last_page
    long file_sizes[MAX_FILES] 'byte array to hold index and file sizes in bits
    long files[MAX_FILES * ROWS_PER_FILE] 'byte array to hold index and filename
  

PUB main 
    init
    
    parse_dsk(string("chplft.dsk"))
    'ser.Str(string("keyboard test..."))
    'ser.Str(string("connect keyboard to ps2 port and type a message."))
    'repeat
    '    key := kb.key 
    '    if key <128 and key > 0
    '        ser.Tx (key) 
    '        I2C.writeByte($42,31,key)

PRI init 
    ' set initial values
    file_count := 0
    current_page := 0
    last_page := 1
    
    I2C.start(SCL_pin,SDA_pin,Bitrate)
    ser.Start(rx, tx, 0, 115200)
    kb.startx(26, 27, NUM, RepeatRate)  
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start

 
             '
PRI get_stats | index
  sd.mount(SD_PINS) ' Mount SD card
  sd.opendir    'open root directory for reading
  
  'loading file names from sd card into ram for faster paging              
  repeat while 0 == sd.nextfile(@tbuf) 
    
      ' so I need a second file to open and query filesize
      sd[1].popen( @tbuf, "r" )
      
      'save file size in file_sizes array
      file_sizes[file_count] := sd[1].get_filesize
      sd[1].pclose      
      
      'move tbuf to files. each file takes up 4 rows of files
      'each row can hold 4 bytes (32 bit long / 8bit bytes = 4)
      'since the short file name needs 13 bytes (8(name)+1(dot)+3(extension)+1(zero terminate))
      bytemove(@files[ROWS_PER_FILE*file_count],@tbuf,strsize(@tbuf))
      
      file_count++
  
  last_page := file_count / RESULTS_PER_PAGE
  
  sd.unmount 'unmount the sd card
             '

PRI parse_dsk(dsk_name) | bytes_read, count, i, y, cat_track, cat_sector, dos_ver, dsk_vol, next_cat_track, next_cat_sector, tslist_track, tslist_sector, file_type, file_name, file_length, next_tslist_track, next_tslist_sector, next_data_track, next_data_sector
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
    
    'we have our data from the vtoc, now go to catalog and get our files list
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, cat_track, cat_sector)
    
    next_cat_track := byte[@file_buffer][1]
    next_cat_sector := byte[@file_buffer][2]
    
    'loop through catalog and print file info
    
    repeat i from 0 to 6
        if byte[@file_buffer][11 + (35 * i)] == $00 'if tslist_track is 0 then skip
            next
            
        tslist_track := byte[@file_buffer][11 + (35 * i)]
        tslist_sector := byte[@file_buffer][12 + (35 * i)]
        file_type := byte[@file_buffer][13 + (35 * i)]
        file_name := byte[@file_buffer][14 + (35 * i)]
        file_length := byte[@file_buffer][33 + (35 * i)]
        
        ser.Str (string("File Track:"))
        ser.Hex (tslist_track, 2)
        ser.Str (string("File Sector:"))
        ser.Hex (tslist_sector, 2)
        ser.Str (string("File Type:"))
        ser.Hex (file_type, 2)
        ser.Str (string("File Name:"))
        ser.Hex (file_name, 2)
        ser.Str (string("File Length:"))
        ser.Hex (file_length, 2)
        
    
    'navigate to first tslist track/sector of last file
    bytes_read := 0
    bytes_read := goto_sector(dsk_name, tslist_track, tslist_sector)
    
    
    
    'move data to tslist_buffer so I can start iterating over tslist tracks/sectors?
    bytemove(@tslist_buffer, @file_buffer, FILE_BUF_SIZE)
    'i := 0
    'repeat while i < bytes_read
    '  ser.Hex (byte[@tslist_buffer][i], 2)
    '  i++
    
    
    'loop through tslist and find all data sectors and read in the file data
    
    repeat
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
            
            'y := 0
            'repeat while y < bytes_read
            '    ser.Hex (byte[@file_buffer][y], 2)
            '    y++
                
            i := i + 2
        while next_data_track <> $00 and i =< FILE_BUF_SIZE - 13
        
        quit    
        'loop and list data for track/sector
        '
    while next_tslist_track <> $00 'track will read 0 when we are at the end of the file data
    
    'ser.Str (string("Catalog:"))
    'send bytes_read to serial 
    'i := 0
    'repeat while i < bytes_read
    '  'ser.Tx (byte[@file_buffer][i])
    '  ser.Hex (byte[@file_buffer][i], 2)
    '  i++
    
    
    ser.Str (string("done sending file "))
   
    
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
    
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}} 