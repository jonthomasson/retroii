''***************************************
''*  VGA Terminal 40x15 v1.0            *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

CON

  _clkmode = xtal1+pll16x
  _clkfreq = 80_000_000

  vga_params = 21
  cols = 32
  rows = 16
  screensize = cols * rows

VAR

  long  vga_status      'status: off/visible/invisible  read-only       (21 contiguous longs)
  long  vga_enable      'enable: off/on                 write-only
  long  vga_pins        'pins: byte(2),topbit(3)        write-only
  long  vga_mode        'mode: interlace,hpol,vpol      write-only
  long  vga_videobase   'video base @word               write-only
  long  vga_colorbase   'color base @long               write-only              
  long  vga_hc          'horizontal cells               write-only
  long  vga_vc          'vertical cells                 write-only
  long  vga_hx          'horizontal cell expansion      write-only
  long  vga_vx          'vertical cell expansion        write-only
  long  vga_ho          'horizontal offset              write-only
  long  vga_vo          'vertical offset                write-only
  long  vga_hd          'horizontal display pixels      write-only
  long  vga_hf          'horizontal front-porch pixels  write-only
  long  vga_hs          'horizontal sync pixels         write-only
  long  vga_hb          'horizontal back-porch pixels   write-only
  long  vga_vd          'vertical display lines         write-only
  long  vga_vf          'vertical front-porch lines     write-only
  long  vga_vs          'vertical sync lines            write-only
  long  vga_vb          'vertical back-porch lines      write-only
  long  vga_rate        'pixel rate (Hz)                write-only

  word  screen[screensize]

  long  col, row, color
  long  boxcolor,ptr
  long  stack[100]

OBJ

  vga : "vga"

pub launch

  cognew(begin, @stack)


PUB begin: I
  start(%010101)
  print($112)
  repeat i from 0 to $FF
   'print(i)
   print(altscreen[i])
'return
  boxcolor := $10
  box(25,5,4,2)
  col := 26
  row := 6
  print($114)
  print("M")
  print("e")
  print("o")
  print("w")

  boxcolor := $11
  box(15,5,4,2)
  col := 16
  row := 6
  print($115)
  print("W")
  print("o")
  print("o")
  print("f")

  boxcolor := $12
  box(5,5,4,2)
  col := 6
  row := 6
  print($116)
  print("W")
  print("o")
  print("o")
  print("f")
  boxcolor := $14
  ptr := 8 * cols + 6
  boxchr($D)

  boxcolor := $13
  box(15,10,4,2)
  col := 16
  row := 11
  print($117)
  print("E")
  print("X")
  print("I")
  print("T")

  repeat
    i := cnt
    waitcnt(i += 22500000)
    spcl := $30101020
    waitcnt(i += 22500000)
    spcl := $10301020


'' Start terminal - starts a cog
'' returns false if no cog available

PUB start(pins)

  print($100)
  longmove(@vga_status, @vgaparams, vga_params)
  vga_pins := pins
  vga_videobase := @screen
  vga_colorbase := @vgacolors
  result := vga.start(@vga_status)


'' Stop terminal - frees a cog

PUB stop

  vga.stop

'' Draw a box

PUB box(left,top,width,height) | x, y, i

  ptr := top * cols + left
  boxchr($0)
  repeat i from 1 to width
    boxchr($C)
  boxchr($8)
  repeat i from 1 to height
    ptr := (top + i) * cols + left
    boxchr($A)
    ptr += width
    boxchr($B)
  ptr := (top + height + 1) * cols + left
  boxchr($1)
  repeat i from 1 to width
    boxchr($D)
  boxchr($9)

PRI boxchr(c): i

  screen[ptr++] := boxcolor << 10 + $200 + c

  

'' Print a character
''
''  $00..$FF = character
''      $100 = clear screen
''      $108 = backspace
''      $10D = new line
''$110..$11F = select color

PUB print(c) | i, k

  case c
    $00..$FF:           'character?
      k := color << 1 + c & 1
      i := k << 10 + $200 + c & $FE
      screen[row * cols + col] := i
      screen[(row + 1) * cols + col] := i | 1
      if ++col == cols
        newline

    $100:               'clear screen?
      wordfill(@screen, $200, screensize)
      col := row := 0

    $108:               'backspace?
      if col
        col--

    $10D:               'return?
      newline

    $110..$11F:         'select color?
      color := c & $F


' New line

PRI newline : i

  col := 0
  if (row += 2) == rows
    row -= 2
    'scroll lines
    repeat i from 0 to rows-3
'      wordmove(@screen[i*cols], @screen[(i+2)*cols], cols)
    'clear new line
'    wordfill(@screen[(rows-2)*cols], $200, cols<<1)


' Data

DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %010_111        'pins
                        long    %011            'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    cols            'hc
                        long    rows            'vc
                        long    1               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    512             'hd
                        long    16              'hf
                        long    96              'hs
                        long    48              'hb
                        long    380             'vd
                        long    11              'vf
                        long    2               'vs
                        long    31              'vb
                        long    20_000_000      'rate

vgacolors               long
                        long    $C000C000       'red
                        long    $C0C00000
                        long    $08A808A8       'green
                        long    $0808A8A8
                        long    $50005000       'blue
                        long    $50500000
                        long    $FC00FC00       'white
                        long    $FCFC0000
                        long    $FF80FF80       'red/white
                        long    $FFFF8080
                        long    $FF20FF20       'green/white
                        long    $FFFF2020
                        long    $FF28FF28       'cyan/white
                        long    $FFFF2828
                        long    $00A800A8       'grey/black
                        long    $0000A8A8
                        long    $C0408080       'redbox
spcl                    long    $30100020       'greenbox
                        long    $3C142828       'cyanbox
                        long    $FC54A8A8       'greybox
                        long    $3C14FF28       'cyanbox+underscore
                        long    0

altscreen               byte    $15,$6E,$20,$14,$20,$B1,$6D,$16,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5F,$5F,$5F,$5F,$5F,$20
                        byte    $20,$81,$82,$86,$87,$8B,$80,$8b,$80,$8B,$20,$20,$AF,$BD,$BE,$9B,$7F,$9B,$A6,$A8,$AA,$20,$20,$17,$20,$20,$53,$54,$41,$52,$54,$20
                        byte    $20,$20,$20,$20,$20,$20,$20,$20,$20,$17,$20,$20,$20,$20,$20,$AC,$20,$AC,$20,$20,$20,$20,$1D,$1E,$20,$20,$20,$20,$20,$20,$20,$20
                        byte    $20,$20,$42,$49,$41,$53,$20,$A0,$1A,$1B,$20,$20,$20,$20,$20,$18,$20,$18,$20,$20,$20,$20,$20,$91,$20,$23,$24,$38,$30,$30,$30,$20
                        byte    $3A,$3D,$20,$20,$20,$20,$20,$20,$20,$99,$BB,$20,$56,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$BC,$20,$23,$25,$31,$30,$30,$31,$20
                        byte    $20,$50,$30,$20,$BA,$BB,$90,$94,$20,$B6,$20,$31,$30,$30,$6B,$13,$20,$17,$20,$20,$20,$20,$20,$18,$20,$70,$5B,$69,$5D,$20,$20,$20
                        byte    $20,$20,$20,$20,$20,$20,$20,$20,$20,$18,$20,$20,$20,$20,$20,$20,$AB,$AC,$AD,$31,$30,$B5,$46,$20,$20,$20,$20,$20,$20,$20,$20,$20
                        byte    $12,$10,$13,$41,$2F,$44,$20,$20,$20,$20,$58,$B2,$2D,$20,$31,$20,$20,$18,$20,$20,$20,$20,$20,$20,$63,$61,$74,$5F,$64,$6F,$70,$65

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