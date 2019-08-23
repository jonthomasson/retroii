''*******************************
''* VGA5PIN_Demo v1.1  2/2017   *
''* Author: Werner L. Schneider *
''*******************************
''
''
CON
    _clkmode  = xtal1 + pll16x
    _xinfreq  = 5_000_000

    BasePin   = 16                          ' P16-P20 VGA
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
  
OBJ

'    vga :   "VGA5PIN_Text_160x120_20x15_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_160x120_20x10_8x12_FG8_BG8"    ' VGA Driver       Font 8x12    

'    vga :   "VGA5PIN_Text_256x192_32x24_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_320x200_40x25_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_320x240_40x30_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_640x400_80x50_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_640x400_80x25_8x16_FG8_BG8"    ' VGA Driver       Font 8x16    

    vga :   "VGA5PIN_Text_640x480_80x60_8x8_FG8_BG8"     ' VGA Driver       Font 8x8    

'    vga :   "VGA5PIN_Text_640x480_80x40_8x12_FG8_BG8"    ' VGA Driver       Font 8x12    

'    vga :   "VGA5PIN_Text_640x480_80x30_8x16_FG8_BG8"    ' VGA Driver       Font 8x16    


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
    byte data

PUB main | a, d, i
    init

    str($04, $03, string("starting ram test..."))
    
    'loop through ram addresses
    'increment data and write to address
    'read ram addresses
    'display read data
    a := 1 'init address to 1
    d := 1 'init data to 1
    
    repeat 80 'number of rows
        write_byte(d, a)
        d := d + 1
        if d == 9
            d := 1
        a := a + 1
    
    i := 1
    
    repeat 80 'now read from data
        data := read_byte(i)
        str($04, $03, string("address: "))
        hex($04, $03, i, 2)
        str($04, $03, string(" data: "))
        hex($04, $03, data, 2)
        i := i + 1
         
    'write_byte(%10011001, %11111111)
    
    'write_byte(%10101011, %00000111)
    
    'data := read_byte(%11111111)
    
    'display read data
    'hex($04, $03, data, 2)
       
    
    'data := read_byte(%00000111)
    'hex($04, $03, data, 2)


PRI init | i, x, y

    dira[21..23]~~

    vga.start(BasePin, @vgabuff, @cursor, @sync)
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
                    '
'    cursor[2] := %110 
'    cursor[5] := %011 

'    repeat i from 0 to vga#cols-1         
'        printxy(i, 0, $04, $03, $20)               ' " "

'    strxy(1, 0, $04, $03, @strTop)

'    if vga#cols > 20
'        strxy(vga#cols-10, 0, $04, $03, @strDate)
'
'    strxy(0, 2, $07, $00, @strBase)                ' "BasePin:"
'
'    print($01, $00, $50)                           ' "P"    
'    dec($01, $00, BasePin)
'    print($01, $00, $2D)                           ' "-"    
'    print($01, $00, $50)                           ' "P"    
'    dec($01, $00, BasePin+4)
'
'    strxy(0, 3, $07, $00, @strRes)                 ' "Resolution: "
'    dec($02, $00, vga#xpix)
'    print($02, $00, $78)                           ' "x"    
'    dec($02, $00, vga#ypix)
'
'    strxy(0, 4, $07, $00, @strCols)                ' "Cols/Rows: "
'    dec($03, $00, vga#cols)
'    print($03, $00, $2F)                           ' "/"    
'    dec($03, $00, vga#rows)
'
'    strxy(0, 5, $07, $00, @strFont)                ' " Font: "
'    print($04, $00, $38)                           ' "8"
'    print($04, $00, $78)                           ' "x"
'    dec($04, $00, vga#fsize)
'
'
'    if vga#cols < 21
'        if vga#fsize < 12
'            setPos(0, 7)
'        else
'            setPos(0, 6)
'
'    else
'        setPos(0, 7)
'        repeat i from 0 to 255                     ' Print Char 0 - 255
'            print($07, $00, i)    
'
'    y := pos / (vga#cols * 2)
'    x := (pos - y * (vga#cols * 2)) / 2
'
'    cursor[3] := x 
'    cursor[4] := y 
'
'    if vga#cols < 21
'        if vga#fsize < 12
'
'            strxy(0, y+2, $05, $00, @strPort)      ' "P23..P21"
'            bpos := y+4
'
'        else
'            strxy(0, y+1, $05, $00, @strPort)      ' "P23..P21"
'            bpos := y+2
'
'    else
'        strxy(0, y+2, $05, $00, @strPort)          ' "P23..P21"
'        bpos := y+4
'
'    binxy(0, bpos, $06, $00, 1, 3)                 ' "001"
'
'    cursor[0] := 3 
'    cursor[1] := bpos 
'
'    if vga#cols < 21
'        repeat i from 0 to vga#cols-1         
'            printxy(i, vga#rows-1, $04, $03, $20)  ' " "
'        strxy(1, vga#rows-1, $04, $03, @strDate) 
'        repeat i from 11 to vga#cols-1             ' Last Line
'            printxy(i, vga#rows-1, $04, $03, $2A)  ' "*"
'    else
'        repeat i from 0 to vga#cols-1              ' Last Line
'            printxy(i, vga#rows-1, $04, $03, $2A)  ' "*"


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

pri write_byte(data_out, address) | i
    'to write:
    
    'we should start high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~  'input /avoid bus contention
    'set address pins
    outa[A0..A7] := address 
    'set we pin low for specified time
    outa[WE]~
    dira[D0..D7]~~  'output /avoid bus contention
    'i := 0
    'set data pins
    outa[D0..D7] := data_out
    'i := 0
    
    'bring we pin high to complete write
    outa[WE]~~
    dira[D0..D7]~  'input /avoid bus contention
    'i := 0
    outa[A0..A7] := %0000000 'low

pri read_byte(address) | data_in, i
    'to read:
    
    
    'set we pin high
    outa[WE]~~
    'set data pins as input
    dira[D0..D7]~
    'set address pins
    outa[A0..A7] := address 
    'wait specified time
    'i := 0
    'read data pins
    data_in := ina[D0..D7]
    'i := 0
    outa[A0..A7] := %0000000 'low
    return data_in
    
DAT

strTop   byte "VGA5PIN_Demo v1.1", 0
strDate  byte "ws 2/2017", 0
strBase  byte "BasePin    : ", 0
strRes   byte "Resolution : ", 0
strCols  byte "Cols/Rows  : ", 0 
strFont  byte "Font       : ", 0
strPort  byte "P23..P21", 0


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