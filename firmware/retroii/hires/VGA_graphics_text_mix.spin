{{
***************************************
*  Graphics/Text Mix Example          *
*  Author: Albert Emanuel Milani      *
*  Copyright (c) 2014 AEM             *
*  See end of file for terms of use.  *
***************************************
}}

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  _stack = (gr_screensize*128 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16
  y_tiles = 12

  screensize = x_tiles * y_tiles
  lastrow = screensize - x_tiles

  minx = 0
  maxx = 15
  miny = 8
  maxy = 15

  gr_x_tiles = maxx - minx + 1
  gr_y_tiles = maxy - miny + 1

  gr_screensize = gr_x_tiles * gr_y_tiles

  paramcount = 21       
  bitmap_base = $8000-(gr_screensize*64)
  display_base = $8000-(gr_screensize*128)
  

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

  word  screen[x_tiles * y_tiles]

  long  txt_x, txt_y, color, flag
  

OBJ

  vga   : "vga"
  gr    : "graphics"

PUB start | i,dx,dy

  'start vga
  longmove(@vga_status,@vgaparams,paramcount)
  vga_videobase:=@screen
  vga_colorbase:=@colors
  vga.start(@vga_status)

  out($00)

  'init tile screen
  repeat dx from minx to maxx
    repeat dy from miny to maxy
      screen[dy*vga_hc+dx]:=display_base>>6 + (dy-miny)+(dx-minx)*gr_y_tiles + (17<<10)            'base>>6 + index + color<<10

  'start and setup graphics
  gr.start
  gr.setup(gr_x_tiles,gr_y_tiles,gr_x_tiles*8,gr_y_tiles*8,bitmap_base)
  gr.colorwidth(3,0)
  gr.textmode(3,3,6,%0101)

'----------[insert your code after here, this is just an example]------------------------------------------------------

  txt_x:=0
  txt_y:=0
  'str(string("Example Text"))
  i:=0
  
  repeat
    gr.box(1,-10,20,16)
    'display some text
    'txt_x:=0
    'txt_y:=1
    'dec(i++)
    
    'clear bitmap
    gr.clear

    'draw some stuff
    'gr.plot(-16,-16+(i&31))
    'gr.line(16,16)
    'gr.plot (1,30)
    'copy bitmap to display
    gr.plot (i,i)
    i++
    gr.copy(display_base)
    
    waitcnt(clkfreq/4 + cnt)

'----------[text functions from VGA_Text.spin, somewhat modified]------------------------------------------------------
PUB str(stringptr)

'' Print a zero-terminated string

  repeat strsize(stringptr)
    out(byte[stringptr++])


PUB dec(value) | i

'' Print a decimal number

  if value < 0
    -value
    out("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      out(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      out("0")
    i /= 10


PUB hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    out(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PUB bin(value, digits)

'' Print a binary number

  value <<= 32 - digits
  repeat digits
    out((value <-= 1) & 1 + "0")


PUB out(c) | i, k

'' Output a character
''
''     $00 = clear screen
''     $01 = home
''     $08 = backspace
''     $09 = tab (8 spaces per)
''     $0A = set X position (X follows)
''     $0B = set Y position (Y follows)
''     $0C = set color (color follows)
''     $0D = return
''  others = printable characters

  case flag
    $00: case c
           $00: wordfill(@screen, $220 + 17<<10, screensize)
                txt_x := txt_y := 0
           $01: txt_x := txt_y := 0
           $08: if txt_x
                  txt_x--
           $09: repeat
                  print(" ")
                while txt_x & 7
           $0A..$0C: flag := c
                     return
           $0D: newline
           other: print(c)
    $0A: txt_x := c // x_tiles
    $0B: txt_y := c // y_tiles
    $0C: color := c & 7
  flag := 0

PRI print(c)

  screen[txt_y * x_tiles + txt_x] := (color << 1 + c & 1) << 10 + $200 + c & $FE
  if ++txt_x == x_tiles
    newline

PRI newline | i

  txt_x := 0
  if ++txt_y == y_tiles
    txt_y--
    wordmove(@screen, @screen[x_tiles], lastrow)   'scroll lines                ''BAD - will also scroll your graphics!!!!
    wordfill(@screen[lastrow], $220, x_tiles)      'clear new line

DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %010_101        'pins
                        long    %0011           'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    x_tiles         'hc
                        long    y_tiles         'vc
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

colors                  long    $C000C000       'red
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
                        long    $FFA8FFA8       'grey/black
                        long    $FFFFA8A8

                        long    %%3330_2220_1110_0000   'graphics

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
