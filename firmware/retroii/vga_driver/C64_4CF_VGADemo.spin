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

OBJ

  C64 : "r2_video.spin"
  pst : "Parallax Serial Terminal"

PUB Main | I, J, C, frq
  init
  'pst.Start(115200)
  
  'Set the pin_group number for your board
  C64.Start(2)
  
  'C64.Start(%010101)
  'Backgound and foreground colors
  C64.Color(0, C64#BLACK) 'BLACK
  C64.Color(1, C64#GREEN) 'GREEN
  C64.Color(2, C64#RED)
  C64.Color(3, C64#BLUE) 'GREEN

  'Test String
  'C64.Pos(0, 0)
  'C64.StrA2(string(" String  "))
  'C := 65
  'repeat J from 0 to 25
  '  C64.Char(156)
  '  C += 1
  write_byte($FF, $0000)
  I := read_byte($0000)
  dec(I)
  return
  
  C64.HiRes
  C64.Pos (0,1)
  dec(C64.DebugOutput)
  'pst.Dec(C64.DebugOutput)
  return
  I := C64.LowRes2 ($CF, 5, 10)
  pst.Hex(I,8)
  'return
  C64.Pos (6,11)
  C64.Char ($E0)
  C64.LowRes2 ($FF, 6, 12)
  C64.LowRes2 ($FF, 6, 9)
  C64.LowRes2 ($FF, 4, 9)
  'C64.LowRes2 ($FF, 4, 10)
  'pst.Hex(C64.DebugOutput,2)
  return  
  'C64.Pos(0,0)
  'C64.Char(65)
  'pst.Hex(C64.DebugOutput,8)
  repeat 1
    repeat I from 0 to 39
        C64.PixelByte ($7F, I, 0)
  'repeat 1
  '  repeat I from 0 to 39
  '      C64.Pixel ($7F, I, 0)
        
  C64.PixelByte($43, 2, 1)
  
  C64.Pixel($83, 2, 0)
  C64.Pixel($7F, 2, 0)
  C64.Pixel($43, 2, 0)
  pst.Hex(C64.DebugOutput, 8)
  
  return
  
  I := C64.PixelByte($FF, 5, 0)
  pst.Hex(I,8)
  return
  
  repeat J from 1 to 40
    C64.PixelByte($00, J, 0)
  
  repeat J from 1 to 40
    C64.PixelByte($FF, J, 0)  

  repeat J from 1 to 40
    C64.PixelByte($2A, J, 5)
    
  return
  I := C64.PixelByte($7F, 7, 0) 'COL 1
  'pst.Dec(I)
  'return
  C64.PixelByte($7F, 14, 2) 'COL 2
  C64.PixelByte($7F, 21, 3) 'COL 2
  C64.PixelByte($7F, 28, 4) 'COL 2
  C64.PixelByte($7F, 35, 5) 'COL 2
  C64.PixelByte($7F, 42, 6) 'COL 2
  C64.PixelByte($7F, 49, 7) 'COL 2
  C64.PixelByte($7F, 56, 8) 'COL 2
  C64.PixelByte($7F, 63, 9) 'COL 2
  C64.PixelByte($7F, 70, 10) 'COL 2
  C64.PixelByte($7F, 77, 11) 'COL 2
  C64.PixelByte($7F, 84, 12) 'COL 2
  C64.PixelByte($7F, 91, 13) 'COL 2
  C64.PixelByte($7F, 98, 14) 'COL 2
  C64.PixelByte($7F, 105, 15) 'COL 2
  C64.PixelByte($7F, 112, 16) 'COL 2
  C64.PixelByte($7F, 119, 17) 'COL 2
  C64.PixelByte($7F, 126, 18) 'COL 2
  C64.PixelByte($7F, 133, 19)
  C64.PixelByte($7F, 140, 20)
  C64.PixelByte($7F, 147, 21)
  C64.PixelByte($7F, 154, 22)
  C64.PixelByte($7F, 161, 23)
  C64.PixelByte($7F, 168, 24)
  C64.PixelByte($7F, 175, 25)
  C64.PixelByte($7F, 182, 26)
  C64.PixelByte($7F, 189, 27)
  C64.PixelByte($7F, 196, 28)
  C64.PixelByte($7F, 203, 29)
  C64.PixelByte($7F, 210, 30)
  C64.PixelByte($7F, 217, 31)
  C64.PixelByte($7F, 224, 32)
  C64.PixelByte($7F, 231, 33)
  C64.PixelByte($7F, 238, 34)
  C64.PixelByte($7F, 245, 35)
  C64.PixelByte($7F, 252, 36)
  C64.PixelByte($7F, 259, 37)
  C64.PixelByte($7F, 266, 38)
  C64.PixelByte($7F, 273, 39)
  C64.PixelByte($7F, 280, 40)
  C64.PixelByte($7F, 287, 41)

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  'C64.PixelByte($04, 0, 0)
  'pst.Dec(C64.DebugOutput)
  'C64.Pos(39,23)
  'C64.Char(65)
    
  'C64.Pos(0,0)
  'C64.Char(65)
  'C64.Pos(1,0)
  'C64.Char(65)
  'C64.Pos(2,0)
  'C64.Char(65)
  'C64.Pos(3,0)
  'C64.Char(65)
  'C64.Pos(4,0)
  'C64.Char(65)
  'C64.Pos(5,0)
  'C64.Char(65)
  'C64.Pos(6,0)
  'C64.Char(65)
  'C64.Pos(7,0)
  'C64.Char(65)
  'C64.Pos(8,0)
  'C64.Char(65)
  'C64.Pos(9,0)
  'C64.Char(65)
  
  'C64.Pos(10, 10)
  'C64.Str(string("HELLO WORLDD"))
  'C64.Pos(15, 12)
  'C64.Str(string("APPLE ]["))
  'C := 65
  'C64.Pos(0, 0)
  'repeat J from 0 to 25
  '  C64.Char(C)
  '  C += 1
    
PUB init
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

PRI dec(val) 
 
    prn(val)


PRI prn(val) | dig

    dig := 48 + (val // 10)
    val := val/10
    if val > 0
        prn(val)
    print(dig)
    
PRI print(char)
    C64.Char(char)        
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