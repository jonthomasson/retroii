''------------------------------------------------------------------------------------------------
'' Commodore 64 Two Color VGA Display
''
'' Copyright (c) 2018 Mike Christle
'' See end of file for terms of use.
''
'' History:
'' 1.0.0 - 10/10/2018 - Original release.
'' 1.0.1 - 10/21/2018 - Fix errors in the character bit maps.
'' 1.1.0 - 10/31/2018 - Add RChar routine to print in reverse.
'' 1.2.0 - 11/02/2018 - Add blinking cursor.
'' 1.2.1 - 11/05/2018 - Fix errors in Line routine.
'' 1.3.0 - 11/12/2018 - Add LineTo routine to draw a series of lines.
'' 1.4.0 - 11/14/2018 - Add four new resolutions.
'' 1.5.0 - 11/15/2018 - Add support for back space char.
''------------------------------------------------------------------------------------------------
'' Supported screen resolutions:
''      160x120 Pixels, 20x15 Chars,  2400 Byte Buffer.
''      192x120 Pixels, 24x15 Chars,  2880 Byte Buffer.
''      224x120 Pixels, 28x15 Chars,  3360 Byte Buffer.
''      256x120 Pixels, 32x15 Chars,  3840 Byte Buffer.
''      256x240 Pixels, 32x30 Chars,  7680 Byte Buffer.
''      288x240 Pixels, 36x30 Chars,  8640 Byte Buffer.
''      320x240 Pixels, 40x30 Chars,  9600 Byte Buffer.
''      384x240 Pixels, 48x30 Chars, 11520 Byte Buffer.
'' To select, uncomment the desired section of constants below. 
''
'' The character value less than 32 are ignored, except for HOME, TAB, Carriage Return and
'' Clear Screen. Constants have been defined for each of these values. Character vales from
'' 32 to 127 implement the normal ASCII character set. Character values from 128 to 255
'' implement the Commodore 64 graphics characters. There are numerus unused value in this
'' range. The Python 3 program, make_char_set.py, can be used to add custom characters.
''
'' This version uses one cog to drive the VGA output.
''------------------------------------------------------------------------------------------------
'' Video Circuit:
''
'' Pin              VGA                                        VGA
'' Group   240Ω
''  +0 ──────── 14 Vertical Sync                +5V ──── 9
''         240Ω
''  +1 ──────── 13 Horizontal Sync              GND ┳─── 5
''         470Ω                                          │
''  +2 ──────┳─ 3  Blue                              ┣─── 6
''         240Ω │                                        │
''  +3 ──────┘                                        ┣─── 7
''         470Ω                                          │
''  +4 ──────┳─ 2  Green                             ┣─── 8
''         240Ω │                                        │
''  +5 ──────┘                                        └─── 10
''         470Ω                                         
''  +6 ──────┳─ 1  Red
''         240Ω │
''  +7 ──────┘
''------------------------------------------------------------------------------------------------

CON

'{ 160x120
  WIDTH  = 160
  HEIGHT = 120
  FREQ_VALUE = 337893737
  CTRA_VALUE = %0_00001_011
  FP = 4
  SP = 24
  BP = 12
'}

{ 192x120
  WIDTH  = 192
  HEIGHT = 120
  FREQ_VALUE = 405472485
  CTRA_VALUE = %0_00001_011
  FP = 5
  SP = 29
  BP = 14
}

{ 224x120
  WIDTH  = 224
  HEIGHT = 120
  FREQ_VALUE = 473051232
  CTRA_VALUE = %0_00001_011
  FP = 6
  SP = 33
  BP = 17
}

{ 256x120
  WIDTH  = 256
  HEIGHT = 120
  FREQ_VALUE = 270314990
  CTRA_VALUE = %0_00001_100
  FP = 5
  SP = 29
  BP = 14
}

{ 256x240
  WIDTH  = 256
  HEIGHT = 240
  FREQ_VALUE = 270314990
  CTRA_VALUE = %0_00001_100
  FP = 5
  SP = 29
  BP = 14
}

{ 288x240
  WIDTH  = 288
  HEIGHT = 240
  FREQ_VALUE = 304104364
  CTRA_VALUE = %0_00001_100
  FP = 7
  SP = 43
  BP = 22
}

{ 320x240
  WIDTH  = 320
  HEIGHT = 240
  FREQ_VALUE = 337893737
  CTRA_VALUE = %0_00001_100
  FP = 8
  SP = 48
  BP = 24
}

{ 384x240
  WIDTH  = 384
  HEIGHT = 240
  FREQ_VALUE = 405472485
  CTRA_VALUE = %0_00001_100
  FP = 10
  SP = 58
  BP = 28
}

  HOME =   1    'Move cursor to 0, 0
  BS   =   8    'Backspace
  TAB  =   9    'Tab 4 spaces
  CR   =  13    'Carrage Return
  CLS  =  16    'Clear Screen

  'Color value constants
  #$FC, LT_GRAY, #$A8, GRAY, #$54, DK_GRAY
  #$C0, LT_RED, #$80, RED, #$40, DK_RED
  #$30, LT_GREEN, #$20, GREEN, #$10, DK_GREEN
  #$0C, LT_BLUE, #$08, BLUE, #$04, DK_BLUE
  #$F0, LT_ORANGE, #$A0, ORANGE, #$50, DK_ORANGE
  #$CC, LT_PURPLE, #$88, PURPLE, #$44, DK_PURPLE
  #$3C, LT_TEAL, #$28, TEAL, #$14, DK_TEAL
  #$FF, WHITE, #$00, BLACK

  PC_FP  = WIDTH + FP
  BLKS   = 480 / HEIGHT         'Number of times to repeat each video line

  COLS   = WIDTH / 8            'Width of screen in characters
  ROWS   = HEIGHT / 8           'Height of screen in characters
  MAX_C  = COLS - 1             'Maximum column
  MAX_R  = ROWS - 1             'Maximum row

  PSIZE  = WIDTH * HEIGHT       'Total number of pixels
  LSIZE  = PSIZE / 32           'Size of screen buffer in longs
  LPROW  = COLS / 4             'Longs per screen line

  MAX_X  = WIDTH - 1            'Maximum value of x coordinate
  MAX_Y  = HEIGHT - 1           'Maximum value of y coordinate

  SCROFF = WIDTH                'Scroll offset
  SCRCNT = LSIZE - (SCROFF / 4) 'Scroll long count

VAR

  long  pixel_bfr[LSIZE]
  long  pixel_colors, frame_count, cursor_pos, cursor_mask
  word  lastx, lasty
  byte  cursorx, cursory, cog, reverse, cursor_state

PUB Char(c) | idx, ptr, tmp
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, then advance the cursor.
''
'' c - Character to print.
'------------------------------------------------------------------------------------------------
  c &= 255

  'If a printable character
  if c > 31
    c := (c - 32) * 8
    ptr := @pixel_bfr + (cursorx + (cursory * WIDTH))
    repeat idx from 0 to 7
      tmp := byte[@C64CharMap][idx + c]
      byte[ptr] := tmp ^ reverse
      ptr += COLS
    cursorx += 1

  elseif c == CR
    cursorx := 0
    cursory += 1

  elseif c == BS
    if cursorx > 0
      cursorx -= 1
      ptr := @pixel_bfr + (cursorx + (cursory * WIDTH))
      repeat idx from 0 to 7
        byte[ptr] := 0
        ptr += COLS
         
  elseif c == CLS
    longfill(@pixel_bfr, 0, LSIZE)
    cursorx := 0
    cursory := 0

  elseif c == HOME
    cursorx := 0
    cursory := 0
    
  elseif c == TAB
    cursorx := (cursorx + 4) & $FC

  'If at end of line, goto next line
  if cursorx => COLS
    cursorx := 0
    cursory += 1

  'If at bottom of screen, scroll
  if cursory => ROWS
    cursory -= 1
    longmove(@pixel_bfr, @pixel_bfr + SCROFF, SCRCNT)
    longfill(@pixel_bfr + constant(SCRCNT << 2), 0, constant(SCROFF >> 2))

  UpdateCursor

PUB CharA2(c,x,y) | idx, ptr, tmp, graphicx, offset
'------------------------------------------------------------------------------------------------
'' Print an Apple ][ 7x8 character on the screen, then advance the cursor.
''
'' c - Character to print.
'' x - The 7x8 column to write to.
'' y - The row to write to.
'------------------------------------------------------------------------------------------------
  c &= 255

  'If a printable character
  if c > 31
    c := (c - 32) * 8
    'need to determine which 8x8 graphic tile(s) we need to update
    x := x * 3
    graphicx := byte[@FontToGraphicMap][x + 1]
    offset := byte[@FontToGraphicMap][x + 2]
    
    
    'prn(offset)
    if offset > 0
        ptr := @pixel_bfr + (graphicx + (cursory * WIDTH))
        repeat idx from 0 to 7 'y
            tmp := byte[@C64CharMap][idx + c]
            'only display left most offset
      
            byte[ptr] |= (tmp ^ reverse) << (7 - offset)
            ptr += COLS
    
        graphicx++
        
    ptr := @pixel_bfr + (graphicx + (cursory * WIDTH))
    repeat idx from 0 to 7 'y
      tmp := byte[@C64CharMap][idx + c]
      'only display right most offset
      
      byte[ptr] |= (tmp ^ reverse) >> (offset + 1)
      ptr += COLS
      
    'ptr := @pixel_bfr + (cursorx + (cursory * WIDTH))
    'repeat idx from 0 to 7
    '  tmp := byte[@C64CharMap][idx + c]
    '  byte[ptr] := tmp ^ reverse
    '  ptr += COLS
    cursorx += 1

  elseif c == CR
    cursorx := 0
    cursory += 1

  elseif c == BS
    if cursorx > 0
      cursorx -= 1
      ptr := @pixel_bfr + (cursorx + (cursory * WIDTH))
      repeat idx from 0 to 7
        byte[ptr] := 0
        ptr += COLS
         
  elseif c == CLS
    longfill(@pixel_bfr, 0, LSIZE)
    cursorx := 0
    cursory := 0

  elseif c == HOME
    cursorx := 0
    cursory := 0
    
  elseif c == TAB
    cursorx := (cursorx + 4) & $FC

  'If at end of line, goto next line
  if cursorx => COLS
    cursorx := 0
    cursory += 1

  'If at bottom of screen, scroll
  if cursory => ROWS
    cursory -= 1
    longmove(@pixel_bfr, @pixel_bfr + SCROFF, SCRCNT)
    longfill(@pixel_bfr + constant(SCRCNT << 2), 0, constant(SCROFF >> 2))

  UpdateCursor

PRI prn(val) | dig

    dig := 48 + (val // 10)
    val := val/10
    if val > 0
        prn(val)
    Char(dig)
    
PUB RChar(c)
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, in reverse video, then advance the cursor.
''
'' c - Character to print.
'------------------------------------------------------------------------------------------------
  reverse := 255
  Char(c)
  reverse := 0

PUB Str(s) | b
'------------------------------------------------------------------------------------------------
'' Write a NULL terminated string starting at the current cursor position.
''
'' s - Address of a Null terminated string.
'------------------------------------------------------------------------------------------------
  repeat
    b := byte[s]
    if b == 0
      return
    Char(b)
    s += 1

PUB Pos(X, Y)
'------------------------------------------------------------------------------------------------
'' Set the XY position of the character cursor.
'------------------------------------------------------------------------------------------------
  cursorx := (X <# MAX_C) #> 0 
  cursory := (Y <# MAX_R) #> 0 
  UpdateCursor

PUB GetX
'------------------------------------------------------------------------------------------------
'' Returns the x cursor coordinate.
'------------------------------------------------------------------------------------------------
  return cursorx

PUB GetY
'------------------------------------------------------------------------------------------------
'' Returns the y cursor coordinate.
'------------------------------------------------------------------------------------------------
  return cursory

PUB Cursor(state)
'------------------------------------------------------------------------------------------------
'' Sets the cursor state.
''
'' state - True to turn cursor on. Default is off.
'------------------------------------------------------------------------------------------------
  cursor_state := state
  cursor_mask := 0
  UpdateCursor

PUB Clear(first_line, line_count)
'------------------------------------------------------------------------------------------------
'' Clear a number of scan lines in the pixel buffer.
''
'' first_line - The first scan line to clear.
'' line_count - The number of scan lines to clear.
'------------------------------------------------------------------------------------------------
  first_line := (first_line <# MAX_Y) #> 0 
  line_count := (line_count <# HEIGHT) #> 0 

  longfill(@pixel_bfr + (COLS * first_line), 0, line_count * LPROW)

PUB Pixel(c, x, y) | p
'------------------------------------------------------------------------------------------------
'' Plots a single pixel on the screen.
''
'' c - Color number, 0 or 1.
'' x - The X pixel coordinate.
'' y - The Y pixel coordinate.
'------------------------------------------------------------------------------------------------
  x := (x <# MAX_X) #> 0
  y := (y <# MAX_Y) #> 0

  p := (WIDTH * y) + x
  x := |<(p & 7)
  p := @pixel_bfr + (p >> 3)

  if c
    byte[p] |= x
  else
    byte[p] &= (!x)

PUB Line(c, x1, y1, x2, y2) | dx, dy, df, a, b, d1, d2
'------------------------------------------------------------------------------------------------
'' Draw a line on the screen.
''
'' c      - Color number, 0 or 1.
'' x1, y1 - XY coordinates of start of line.
'' x2, y2 - XY coordinates of end of line.
'------------------------------------------------------------------------------------------------
  lastx := x2
  lasty := y2

  if x1 > x2
    a := x1
    x1 := x2
    x2 := a
    a := y1
    y1 := y2
    y2 := a
     
  dx := x2 - x1
  dy := y2 - y1

  d1 := 1
  if dy < 0
    d1 := -1
    dy := -dy

  a := 0
  b := 0

  if dx > dy
    df := 1
  else
    df := -1

  repeat while (a < dx) or ((b + y1) <> y2)
    Pixel(c, x1 + a, y1 + b)
    if df < 0
      b += d1
      df += dx
    else
      a += 1
      df -= dy
  Pixel(c, x1 + a, y1 + b)

PUB LineTo(c, x, y)
'------------------------------------------------------------------------------------------------
'' Draw a line on the screen starting from the end of the last line.
''
'' c    - Color number, 0 or 1.
'' x, y - XY coordinates of end of line.
'------------------------------------------------------------------------------------------------
  Line(c, lastx, lasty, x, y)

PUB FrameCount
'------------------------------------------------------------------------------------------------
'' Returns the current frame counter.
'' Frame counter is incremented after the last video line is output.
'' Frame counter is an 32 bit integer.
'------------------------------------------------------------------------------------------------
  return frame_count

PUB Color(color_num, new_color)
'------------------------------------------------------------------------------------------------
'' Change a color value.
''
'' color_num - The color number to change for the whole screen, 0 or 1.
'' new_color - A color byte (%RR_GG_BB_xx) describing the pixel's new color.
'------------------------------------------------------------------------------------------------
  color_num &= 1
  pixel_colors.byte[color_num] := new_color

PUB Start(pin_group) | hres, vres
'------------------------------------------------------------------------------------------------
'' Starts up the C64 driver running on a cog.
'' Returns true on success and false on failure.
''
'' pin_group - Pin group to use to drive the video circuit. Between 0 and 3.
'------------------------------------------------------------------------------------------------
  Stop

  colors_ptr := @pixel_colors 

  pin_group &= 3
  output_enables := ($FF << (pin_group << 3))
  vcfg_reg := $20_00_04_1F '| (pin_group << 9)
   
  colors_ptr := @pixel_colors
  frame_cntr_ptr := @frame_count
   
  cursorx := 0
  cursory := 0
  cursor_state := FALSE
  cursor_pos := 0
  cursor_pos_ptr := @cursor_pos
  cursor_mask := 0
  cursor_mask_ptr := @cursor_mask
  reverse := 0
   
  cog := cognew(@asm_start, @pixel_bfr) + 1
  result := cog
   
PUB Stop
'------------------------------------------------------------------------------------------------
'' Shuts down the C64 driver running on a cog.
'------------------------------------------------------------------------------------------------

  if cog > 0
    cogstop(cog - 1)

PRI UpdateCursor | cpos
'------------------------------------------------------------------------------------------------
'' Update the cursor position.
'------------------------------------------------------------------------------------------------
  if cursor_state
    cpos := @pixel_bfr + (cursory * WIDTH) + constant(7 * COLS)
    cpos := cpos + (cursorx & $FFFC)
    cursor_mask := $FF << ((cursorx & 3) << 3)
    cursor_pos := cpos

DAT
'------------------------------------------------------------------------------------------------
                        org     0

asm_start               mov     frqa, freq_reg
                        movi    ctra, #CTRA_VALUE
                        mov     vcfg, vcfg_reg
                        mov     dira, output_enables

'--- Vertical Sync ------------------------------------------------------------------------------
vsync_loop              mov     line_cntr, #2

vs_loop                 mov     vscl, #PC_FP
                        waitvid vs_colors, #0
                        mov     vscl, #SP
                        waitvid vs_colors, #1
                        mov     vscl, #BP
                        waitvid vs_colors, #0
                        djnz    line_cntr, #vs_loop

'--- Vertical Sync Back Porch -------------------------------------------------------------------
                        mov     line_cntr, #33

vsbp_loop               mov     vscl, #PC_FP
                        waitvid hs_colors, #0
                        mov     vscl, #SP
                        waitvid hs_colors, #1
                        mov     vscl, #BP
                        waitvid hs_colors, #0
                        djnz    line_cntr, #vsbp_loop

'--- Prep for Active Video ----------------------------------------------------------------------
                        mov     vscl, #PC_FP

                        mov     pixel_ptr0, par
                        mov     line_cntr, #HEIGHT
                        rdlong  vid_colors, colors_ptr
                        or      vid_colors, blank_colors

                        mov     cursor_mask0, frame_cntr
                        and     cursor_mask0, #$20  wz
              if_nz     mov     cursor_mask0, #0
              if_z      rdlong  cursor_mask0, cursor_mask_ptr
                        rdlong  cursor_pos0, cursor_pos_ptr

                        waitvid hs_colors, #0
                        mov     vscl, #SP
                        waitvid hs_colors, #1
                        mov     vscl, #BP
                        waitvid hs_colors, #0

'--- Active Video Lines -------------------------------------------------------------------------
video_loop1             mov     block_cntr, #BLKS
video_loop2             mov     vscl, video_scale
                        mov     pixel_cntr, #LPROW
                        mov     pixel_ptr1, pixel_ptr0

video_loop3             rdlong  pixel_values, pixel_ptr1
                        cmp     pixel_ptr1, cursor_pos0  wz
              if_z      or      pixel_values, cursor_mask0
                        add     pixel_ptr1, #4
                        waitvid vid_colors, pixel_values
                        djnz    pixel_cntr, #video_loop3

                        mov     vscl, #FP
                        waitvid hs_colors, #0
                        mov     vscl, #SP
                        waitvid hs_colors, #1
                        mov     vscl, #BP
                        waitvid hs_colors, #0


                        djnz    block_cntr, #video_loop2
                        add     pixel_ptr0, #COLS
                        djnz    line_cntr, #video_loop1

'----Vertical Sync Front Porch ------------------------------------------------------------------
                        mov     line_cntr, #10
                        add     frame_cntr, #1
                        wrlong  frame_cntr, frame_cntr_ptr 

vsfp_loop               mov     vscl, #PC_FP
                        waitvid hs_colors, #0
                        mov     vscl, #SP
                        waitvid hs_colors, #1
                        mov     vscl, #BP
                        waitvid hs_colors, #0
                        djnz    line_cntr, #vsfp_loop

                        jmp     #vsync_loop


hs_colors               long    $01_03_01_03
vs_colors               long    $00_02_00_02
blank_colors            long    $03_03_03_03
colors_ptr              long    0
cursor_pos_ptr          long    0
cursor_mask_ptr         long    0
freq_reg                long    FREQ_VALUE
vcfg_reg                long    0
output_enables          long    0
frame_cntr_ptr          long    0
video_scale             long    $000_01_020

vid_colors              res     1
pixel_ptr0              res     1
pixel_ptr1              res     1
pixel_cntr              res     1
pixel_values            res     1
line_cntr               res     1
block_cntr              res     1
frame_cntr              res     1
cursor_pos0             res     1
cursor_mask0            res     1

DAT

'------------------------------------------------------------------------------------------------
' LUT To map between 7x8 font tiles and 8x8 graphic tiles ((xpos x 7) / 8)
'------------------------------------------------------------------------------------------------
'                      FONT COL, GRAPH COL, OFFSET
FontToGraphicMap
                       byte     $00, $00, $00   'col 0
                       byte     $01, $00, $01   'col 1
                       byte     $02, $01, $02   'col 2
                       byte     $03, $02, $03   'col 3
                       byte     $04, $03, $04   'col 4
                       byte     $05, $04, $05   'col 5
                       byte     $06, $05, $06   'col 6
                       byte     $07, $06, $07   'col 7
                       byte     $08, $07, $00   'col 8
                       byte     $09, $07, $01   'col 9
                       byte     $0A, $08, $02   'col 10
                       byte     $0B, $09, $03   'col 11
                       byte     $0C, $0A, $04   'col 12
                       byte     $0D, $0B, $05   'col 13
                       byte     $0E, $0C, $06   'col 14
                       byte     $0F, $0D, $07   'col 15
                       byte     $10, $0E, $00   'col 16
                       byte     $11, $0E, $01   'col 17
                       byte     $12, $0F, $02   'col 18
                       byte     $13, $10, $03   'col 19
                       byte     $14, $11, $04   'col 20
                       byte     $15, $12, $05   'col 21
                       byte     $16, $13, $06   'col 22
                       byte     $17, $14, $07   'col 23
                       byte     $18, $15, $00   'col 24
                       byte     $19, $15, $01   'col 25
                       byte     $1A, $16, $02   'col 26
                       byte     $1B, $17, $03   'col 27
                       byte     $1C, $18, $04   'col 28
                       byte     $1D, $19, $05   'col 29
                       byte     $1E, $1A, $06   'col 30
                       byte     $1F, $1B, $07   'col 31
                       byte     $20, $1C, $00   'col 32
                       byte     $21, $1C, $01   'col 33
                       byte     $22, $1D, $02   'col 34
                       byte     $23, $1E, $03   'col 35
                       byte     $24, $1F, $04   'col 36
                       byte     $25, $20, $05   'col 37
                       byte     $26, $21, $06   'col 38
                       byte     $27, $22, $07   'col 39
                       byte     $28, $23, $00   'col 40                        
                       byte     $29, $23, $01   'col 41                         
                                                
                                                                                                                                                    
'------------------------------------------------------------------------------------------------
' C64 Character Map
'------------------------------------------------------------------------------------------------
C64CharMap
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 32 Space 
                        byte    $18, $18, $18, $18, $00, $00, $18, $00 ' 33 ! 
                        byte    $66, $66, $66, $00, $00, $00, $00, $00 ' 34 " 
                        byte    $66, $66, $FF, $66, $FF, $66, $66, $00 ' 35 # 
                        byte    $18, $7C, $06, $3C, $60, $3E, $18, $00 ' 36 $ 
                        byte    $46, $66, $30, $18, $0C, $66, $62, $00 ' 37 % 
                        byte    $3C, $66, $3C, $1C, $E6, $66, $FC, $00 ' 38 & 
                        byte    $60, $30, $18, $00, $00, $00, $00, $00 ' 39 ' 
                        byte    $30, $18, $0C, $0C, $0C, $18, $30, $00 ' 40 ( 
                        byte    $0C, $18, $30, $30, $30, $18, $0C, $00 ' 41 ) 
                        byte    $00, $66, $3C, $FF, $3C, $66, $00, $00 ' 42 * 
                        byte    $00, $18, $18, $7E, $18, $18, $00, $00 ' 43 + 
                        byte    $00, $00, $00, $00, $00, $18, $18, $0C ' 44 , 
                        byte    $00, $00, $00, $7E, $00, $00, $00, $00 ' 45 - 
                        byte    $00, $00, $00, $00, $00, $18, $18, $00 ' 46 . 
                        byte    $00, $C0, $60, $30, $18, $0C, $06, $00 ' 47 / 
                        byte    $3C, $66, $76, $6E, $66, $66, $3C, $00 ' 48 0 
                        byte    $18, $18, $1C, $18, $18, $18, $7E, $00 ' 49 1 
                        byte    $3C, $66, $60, $30, $0C, $06, $7E, $00 ' 50 2 
                        byte    $3C, $66, $60, $38, $60, $66, $3C, $00 ' 51 3 
                        byte    $60, $70, $78, $66, $FE, $60, $60, $00 ' 52 4 
                        byte    $7E, $06, $3E, $60, $60, $66, $3C, $00 ' 53 5 
                        byte    $3C, $66, $06, $3E, $66, $66, $3C, $00 ' 54 6 
                        byte    $7E, $66, $30, $18, $18, $18, $18, $00 ' 55 7 
                        byte    $3C, $66, $66, $3C, $66, $66, $3C, $00 ' 56 8 
                        byte    $3C, $66, $66, $7C, $60, $66, $3C, $00 ' 57 9 
                        byte    $00, $00, $18, $00, $00, $18, $00, $00 ' 58 : 
                        byte    $00, $00, $18, $00, $00, $18, $18, $0C ' 59 ; 
                        byte    $70, $18, $0C, $06, $0C, $18, $70, $00 ' 60 < 
                        byte    $00, $00, $7E, $00, $7E, $00, $00, $00 ' 61 = 
                        byte    $0E, $18, $30, $60, $30, $18, $0E, $00 ' 62 > 
                        byte    $3C, $66, $60, $30, $18, $00, $18, $00 ' 63 ? 
                        byte    $3C, $66, $76, $76, $06, $46, $3C, $00 ' 64 @ 
                        byte    $18, $3C, $66, $7E, $66, $66, $66, $00 ' 65 A 
                        byte    $3E, $66, $66, $3E, $66, $66, $3E, $00 ' 66 B 
                        byte    $3C, $66, $06, $06, $06, $66, $3C, $00 ' 67 C 
                        byte    $1E, $36, $66, $66, $66, $36, $1E, $00 ' 68 D 
                        byte    $7E, $06, $06, $1E, $06, $06, $7E, $00 ' 69 E 
                        byte    $7E, $06, $06, $1E, $06, $06, $06, $00 ' 70 F 
                        byte    $3C, $66, $06, $76, $66, $66, $3C, $00 ' 71 G 
                        byte    $66, $66, $66, $7E, $66, $66, $66, $00 ' 72 H 
                        byte    $3C, $18, $18, $18, $18, $18, $3C, $00 ' 73 I 
                        byte    $78, $30, $30, $30, $30, $36, $1C, $00 ' 74 J 
                        byte    $66, $36, $1E, $0E, $1E, $36, $66, $00 ' 75 K 
                        byte    $06, $06, $06, $06, $06, $06, $7E, $00 ' 76 L 
                        byte    $C6, $EE, $FE, $D6, $C6, $C6, $C6, $00 ' 77 M 
                        byte    $66, $6E, $7E, $7E, $76, $66, $66, $00 ' 78 N 
                        byte    $3C, $66, $66, $66, $66, $66, $3C, $00 ' 79 O 
                        byte    $3E, $66, $66, $3E, $06, $06, $06, $00 ' 80 P 
                        byte    $3C, $66, $66, $66, $66, $3C, $70, $00 ' 81 Q 
                        byte    $3E, $66, $66, $3E, $1E, $36, $66, $00 ' 82 R 
                        byte    $3C, $66, $06, $3C, $60, $66, $3C, $00 ' 83 S 
                        byte    $7E, $18, $18, $18, $18, $18, $18, $00 ' 84 T 
                        byte    $66, $66, $66, $66, $66, $66, $3C, $00 ' 85 U 
                        byte    $66, $66, $66, $66, $66, $3C, $18, $00 ' 86 V 
                        byte    $C6, $C6, $C6, $D6, $FE, $EE, $C6, $00 ' 87 W 
                        byte    $66, $66, $3C, $18, $3C, $66, $66, $00 ' 88 X 
                        byte    $66, $66, $66, $3C, $18, $18, $18, $00 ' 89 Y 
                        byte    $7E, $60, $30, $18, $0C, $06, $7E, $00 ' 90 Z 
                        byte    $3C, $0C, $0C, $0C, $0C, $0C, $3C, $00 ' 91 [ 
                        byte    $00, $06, $0C, $18, $30, $60, $C0, $00 ' 92 \ 
                        byte    $3C, $30, $30, $30, $30, $30, $3C, $00 ' 93 ] 
                        byte    $18, $3C, $66, $00, $00, $00, $00, $00 ' 94 ^ 
                        byte    $00, $00, $00, $00, $00, $00, $00, $FF ' 95 _ 
                        byte    $06, $0C, $18, $00, $00, $00, $00, $00 ' 96 ` 
                        byte    $00, $00, $3C, $60, $7C, $66, $7C, $00 ' 97 a 
                        byte    $00, $06, $06, $3E, $66, $66, $3E, $00 ' 98 b 
                        byte    $00, $00, $3C, $06, $06, $06, $3C, $00 ' 99 c 
                        byte    $00, $60, $60, $7C, $66, $66, $7C, $00 ' 100 d 
                        byte    $00, $00, $3C, $66, $7E, $06, $3C, $00 ' 101 e 
                        byte    $00, $70, $18, $7C, $18, $18, $18, $00 ' 102 f 
                        byte    $00, $00, $7C, $66, $66, $7C, $60, $3E ' 103 g 
                        byte    $00, $06, $06, $3E, $66, $66, $66, $00 ' 104 h 
                        byte    $00, $18, $00, $1C, $18, $18, $3C, $00 ' 105 i 
                        byte    $00, $60, $00, $60, $60, $60, $60, $3C ' 106 j 
                        byte    $00, $06, $06, $36, $1E, $36, $66, $00 ' 107 k 
                        byte    $00, $1C, $18, $18, $18, $18, $3C, $00 ' 108 l 
                        byte    $00, $00, $66, $FE, $FE, $D6, $C6, $00 ' 109 m 
                        byte    $00, $00, $3E, $66, $66, $66, $66, $00 ' 110 n 
                        byte    $00, $00, $3C, $66, $66, $66, $3C, $00 ' 111 o 
                        byte    $00, $00, $3E, $66, $66, $3E, $06, $06 ' 112 p 
                        byte    $00, $00, $7C, $66, $66, $7C, $60, $60 ' 113 q 
                        byte    $00, $00, $3E, $66, $06, $06, $06, $00 ' 114 r 
                        byte    $00, $00, $7C, $06, $3C, $60, $3E, $00 ' 115 s 
                        byte    $00, $18, $7E, $18, $18, $18, $70, $00 ' 116 t 
                        byte    $00, $00, $66, $66, $66, $66, $7C, $00 ' 117 u 
                        byte    $00, $00, $66, $66, $66, $3C, $18, $00 ' 118 v 
                        byte    $00, $00, $C6, $D6, $FE, $7C, $6C, $00 ' 119 w 
                        byte    $00, $00, $66, $3C, $18, $3C, $66, $00 ' 120 x 
                        byte    $00, $00, $66, $66, $66, $7C, $30, $1E ' 121 y 
                        byte    $00, $00, $7E, $30, $18, $0C, $7E, $00 ' 122 z 
                        byte    $30, $0C, $0C, $03, $0C, $0C, $30, $00 ' 123 { 
                        byte    $18, $18, $18, $18, $18, $18, $18, $18 ' 124 | 
                        byte    $0C, $30, $30, $C0, $30, $30, $0C, $00 ' 125 } 
                        byte    $00, $00, $DC, $76, $00, $00, $00, $00 ' 126 ~ 
                        byte    $00, $08, $0C, $FE, $FE, $0C, $08, $00 ' 127 Left Arrow 
                        byte    $30, $48, $0C, $3E, $0C, $46, $3F, $00 ' 128 British Pound 
                        byte    $00, $18, $3C, $7E, $18, $18, $18, $18 ' 129 Up Arrow 
                        byte    $00, $08, $0C, $FE, $FE, $0C, $08, $00 ' 130 Left Arrow 
                        byte    $55, $AA, $55, $AA, $55, $AA, $55, $AA ' 131 Checker Board 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 132 
                        byte    $00, $00, $4E, $62, $46, $42, $E2, $00 ' 133 F1 
                        byte    $00, $00, $EE, $82, $C6, $82, $E2, $00 ' 134 F3 
                        byte    $00, $00, $EE, $22, $66, $82, $62, $00 ' 135 F5 
                        byte    $00, $00, $EE, $82, $86, $42, $42, $00 ' 136 F7 
                        byte    $00, $00, $6E, $82, $66, $22, $E2, $00 ' 137 F2 
                        byte    $00, $00, $4E, $62, $F6, $42, $42, $00 ' 138 F4 
                        byte    $00, $00, $CE, $22, $E6, $A2, $E2, $00 ' 139 F6 
                        byte    $00, $00, $EE, $A2, $E6, $A2, $E2, $00 ' 140 F8 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 141 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 142 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 143 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 144 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 145 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 146 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 147 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 148 
                        byte    $00, $00, $00, $E0, $F0, $38, $18, $18 ' 149 
                        byte    $C3, $E7, $7E, $3C, $3C, $7E, $E7, $C3 ' 150 
                        byte    $00, $3C, $7E, $66, $66, $7E, $3C, $00 ' 151 
                        byte    $18, $18, $66, $66, $18, $18, $3C, $00 ' 152 Club 
                        byte    $60, $60, $60, $60, $60, $60, $60, $60 ' 153 
                        byte    $10, $38, $7C, $FE, $7C, $38, $10, $00 ' 154 Diamond 
                        byte    $18, $18, $18, $FF, $FF, $18, $18, $18 ' 155 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 156 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 157 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 158 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 159 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 160 
                        byte    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F ' 161 
                        byte    $00, $00, $00, $00, $FF, $FF, $FF, $FF ' 162 
                        byte    $FF, $00, $00, $00, $00, $00, $00, $00 ' 163 
                        byte    $00, $00, $00, $00, $00, $00, $00, $FF ' 164 
                        byte    $01, $01, $01, $01, $01, $01, $01, $01 ' 165 
                        byte    $33, $33, $CC, $CC, $33, $33, $CC, $CC ' 166 
                        byte    $80, $80, $80, $80, $80, $80, $80, $80 ' 167 
                        byte    $00, $00, $00, $00, $33, $33, $CC, $CC ' 168 
                        byte    $FF, $7F, $3F, $1F, $0F, $07, $03, $01 ' 169 
                        byte    $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0 ' 170 
                        byte    $18, $18, $18, $F8, $F8, $18, $18, $18 ' 171 
                        byte    $00, $00, $00, $00, $F0, $F0, $F0, $F0 ' 172 
                        byte    $18, $18, $18, $F8, $F8, $00, $00, $00 ' 173 
                        byte    $00, $00, $00, $1F, $1F, $18, $18, $18 ' 174 
                        byte    $00, $00, $00, $00, $00, $00, $FF, $FF ' 175 
                        byte    $00, $00, $00, $F8, $F8, $18, $18, $18 ' 176 
                        byte    $18, $18, $18, $FF, $FF, $00, $00, $00 ' 177 
                        byte    $00, $00, $00, $FF, $FF, $18, $18, $18 ' 178 
                        byte    $18, $18, $18, $1F, $1F, $18, $18, $18 ' 179 
                        byte    $03, $03, $03, $03, $03, $03, $03, $03 ' 180 
                        byte    $07, $07, $07, $07, $07, $07, $07, $07 ' 181 
                        byte    $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0 ' 182 
                        byte    $FF, $FF, $00, $00, $00, $00, $00, $00 ' 183 
                        byte    $FF, $FF, $FF, $00, $00, $00, $00, $00 ' 184 
                        byte    $00, $00, $00, $00, $00, $FF, $FF, $FF ' 185 
                        byte    $C0, $C0, $C0, $C0, $C0, $C0, $FF, $FF ' 186 
                        byte    $00, $00, $00, $00, $0F, $0F, $0F, $0F ' 187 
                        byte    $F0, $F0, $F0, $F0, $00, $00, $00, $00 ' 188 
                        byte    $18, $18, $18, $1F, $1F, $00, $00, $00 ' 189 
                        byte    $0F, $0F, $0F, $0F, $00, $00, $00, $00 ' 190 
                        byte    $0F, $0F, $0F, $0F, $F0, $F0, $F0, $F0 ' 191 
                        byte    $00, $00, $00, $FF, $FF, $00, $00, $00 ' 192 
                        byte    $10, $38, $7C, $FE, $FE, $38, $7C, $00 ' 193 Spade 
                        byte    $18, $18, $18, $18, $18, $18, $18, $18 ' 194 
                        byte    $00, $00, $00, $FF, $FF, $00, $00, $00 ' 195 
                        byte    $00, $00, $FF, $FF, $00, $00, $00, $00 ' 196 
                        byte    $00, $FF, $FF, $00, $00, $00, $00, $00 ' 197 
                        byte    $00, $00, $00, $00, $FF, $FF, $00, $00 ' 198 
                        byte    $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C ' 199 
                        byte    $30, $30, $30, $30, $30, $30, $30, $30 ' 200 
                        byte    $00, $00, $00, $07, $0F, $1C, $18, $18 ' 201 
                        byte    $18, $18, $38, $F0, $E0, $00, $00, $00 ' 202 
                        byte    $18, $18, $1C, $0F, $07, $00, $00, $00 ' 203 
                        byte    $03, $03, $03, $03, $03, $03, $FF, $FF ' 204 
                        byte    $03, $07, $0E, $1C, $38, $70, $E0, $C0 ' 205 
                        byte    $C0, $E0, $70, $38, $1C, $0E, $07, $03 ' 206 
                        byte    $FF, $FF, $03, $03, $03, $03, $03, $03 ' 207 
                        byte    $FF, $FF, $C0, $C0, $C0, $C0, $C0, $C0 ' 208 
                        byte    $00, $3C, $7E, $7E, $7E, $7E, $3C, $00 ' 209 
                        byte    $00, $00, $00, $00, $00, $FF, $FF, $00 ' 210 
                        byte    $6C, $FE, $FE, $FE, $7C, $38, $10, $00 ' 211 Heart 
                        byte    $06, $06, $06, $06, $06, $06, $06, $06 ' 212 
                        byte    $00, $00, $00, $E0, $F0, $38, $18, $18 ' 213 
                        byte    $C3, $E7, $7E, $3C, $3C, $7E, $E7, $C3 ' 214 
                        byte    $00, $3C, $7E, $66, $66, $7E, $3C, $00 ' 215 
                        byte    $18, $18, $66, $66, $18, $18, $3C, $00 ' 216 Club 
                        byte    $60, $60, $60, $60, $60, $60, $60, $60 ' 217 
                        byte    $10, $38, $7C, $FE, $7C, $38, $10, $00 ' 218 Diamond 
                        byte    $18, $18, $18, $FF, $FF, $18, $18, $18 ' 219 
                        byte    $03, $03, $0C, $0C, $03, $03, $0C, $0C ' 220 
                        byte    $18, $18, $18, $18, $18, $18, $18, $18 ' 221 
                        byte    $00, $00, $C0, $7C, $6E, $6C, $6C, $00 ' 222 PI 
                        byte    $FF, $FE, $FC, $F8, $F0, $E0, $C0, $80 ' 223 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 224 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 225 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 226 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 227 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 228 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 229 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 230 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 231 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 232 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 233 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 234 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 235 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 236 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 237 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 238 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 239 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 240 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 241 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 242 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 243 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 244 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 245 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 246 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 247 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 248 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 249 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 250 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 251 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 252 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 253 
                        byte    $00, $00, $00, $00, $00, $00, $00, $00 ' 254 
                        byte    $3C, $42, $A5, $81, $A5, $99, $42, $3C ' 255 Smiley 
{{
┌────────────────────────────────────────────────────────────────────────────┐
│                       TERMS OF USE: MIT License                            │                                                            
├────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining       │
│a copy of this software and associated documentation files (the "Software"),│
│to deal in the Software without restriction, including without limitation   │
│the rights to use, copy, modify, merge, publish, distribute, sublicense,    │
│and/or sell copies of the Software, and to permit persons to whom the       │
│Software is furnished to do so, subject to the following conditions:        │                                                           │
│                                                                            │                                                  │
│The above copyright notice and this permission notice shall be included in  │
│all copies or substantial portions of the Software.                         │
│                                                                            │                                                  │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  │
│IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,    │
│FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL     │
│THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  │
│LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     │
│FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         │
│DEALINGS IN THE SOFTWARE.                                                   │
└────────────────────────────────────────────────────────────────────────────┘
}}