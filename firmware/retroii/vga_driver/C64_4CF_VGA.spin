''------------------------------------------------------------------------------------------------
'' Commodore 64 Four Color Fast VGA Display
''
'' Copyright (c) 2018 Mike Christle
'' See end of file for terms of use.
''
'' History:
'' 1.0.0 - 10/10/2018 - Original release.
'' 1.0.1 - 10/21/2018 - Fix errors in the character bit maps.
'' 1.1.0 - 10/31/2018 - Add CChar routine to better control character colors.
'' 1.2.0 - 11/02/2018 - Add blinking cursor.
'' 1.2.1 - 11/05/2018 - Fix errors in Line routine.
'' 1.3.0 - 11/12/2018 - Add LineTo routine to draw a series of lines.
'' 1.4.0 - 11/14/2018 - Add four new resolutions.
'' 1.5.0 - 11/15/2018 - Add support for back space char.
'' 2.0.0 - 11/16/2018 - Add assembly routines to replace Pixel, Char and Line functions.
''------------------------------------------------------------------------------------------------
'' Supported screen resolutions:
''      160x120 Pixels, 20x15 Chars,  4800 Byte Buffer.
''      192x120 Pixels, 24x15 Chars,  5760 Byte Buffer.
''      224x120 Pixels, 28x15 Chars,  6720 Byte Buffer.
''      256x120 Pixels, 32x15 Chars,  7680 Byte Buffer.
''      256x240 Pixels, 32x30 Chars, 15360 Byte Buffer.
''      288x240 Pixels, 36x30 Chars, 17280 Byte Buffer.
''      320x240 Pixels, 40x30 Chars, 19200 Byte Buffer.
''      384x240 Pixels, 48x30 Chars, 23040 Byte Buffer.
'' To select, uncomment the desired section of constants below. 
''
'' The character value less than 32 are ignored, except for HOME, TAB, Carriage Return and
'' Clear Screen. Constants have been defined for each of these values. Character vales from
'' 32 to 127 implement the normal ASCII character set. Character values from 128 to 255
'' implement the Commodore 64 graphics characters. There are numerus unused value in this
'' range. The Python 3 program, make_char_set.py, can be used to add custom characters.
''
'' This version uses two cogs, one for the VGA output, and one for routines that draw
'' on the bitmap.
''------------------------------------------------------------------------------------------------
'' Video Circuit:
''
'' Pin              VGA
'' Group   240Î©
''  +0 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”€â”€ï‚» 14 Vertical Sync                +5V ï‚©â”€â”€â”€â”€ï‚» 9
''         240Î©
''  +1 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”€â”€ï‚» 13 Horizontal Sync              GND ï‚©â”³â”€â”€â”€ï‚» 5
''         470Î©                                          â”‚
''  +2 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”³â”€ï‚» 3  Blue                              â”£â”€â”€â”€ï‚» 6
''         240Î© â”‚                                        â”‚
''  +3 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”˜                                        â”£â”€â”€â”€ï‚» 7
''         470Î©                                          â”‚
''  +4 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”³â”€ï‚» 2  Green                             â”£â”€â”€â”€ï‚» 8
''         240Î© â”‚                                        â”‚
''  +5 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”˜                                        â””â”€â”€â”€ï‚» 10
''         470Î©                                         
''  +6 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”³â”€ï‚» 1  Red
''         240Î© â”‚
''  +7 ï‚©â”€â”€â”€â”€ï‚½ï‚¾â”€â”€â”˜
''------------------------------------------------------------------------------------------------

CON

{ 160x120
  WIDTH  = 160
  HEIGHT = 120
  FREQ_VALUE = 337893737
  CTRA_VALUE = %0_00001_011
  FP = 4
  SP = 24
  BP = 12
}

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

{ 280x240
  WIDTH  = 280 
  HEIGHT = 240
  FREQ_VALUE = 295656502 
  CTRA_VALUE = %0_00001_100
  FP = 7 
  SP = 42
  BP = 21
}

'{ 288x240
  WIDTH  = 288 '288
  HEIGHT = 240
  FREQ_VALUE = 304103817 '304104364
  CTRA_VALUE = %0_00001_100
  FP = 7 '7
  SP = 43'43
  BP = 22'22
'}

{ 320x240
  WIDTH  = 320
  HEIGHT = 240
  FREQ_VALUE = 337893130 '337893737
  CTRA_VALUE = %0_00001_100
  FP = 8' 9  '8
  SP = 48 '47 '48
  BP = 24 '25 '24
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

  COLS   = WIDTH / 8 '8            'Width of screen in characters
  ROWS   = HEIGHT / 8           'Height of screen in characters
  MAX_C  = COLS - 1             'Maximum column
  MAX_R  = ROWS - 1             'Maximum row

  PSIZE  = WIDTH * HEIGHT       'Total number of pixels
  LSIZE  = PSIZE / 16           'Size of screen buffer in longs
  LPROW  = COLS / 4             'Longs per screen line
  WPROW  = COLS / 2             'Words per screen line
  COLS2  = COLS * 2

  MAX_X  = WIDTH - 1            'Maximum value of x coordinate
  MAX_Y  = HEIGHT - 1           'Maximum value of y coordinate

  SCROFF = WIDTH * 2            'Scroll offset
  SCRCNT = LSIZE - (SCROFF / 4) 'Scroll long count

  'char       8       0
  'xpos       9       8
  'ypos       8       17
  'fg color   2       25
  'bg color   2       27
  'command    3       29
  CMD_CHAR  = $00_00_00_00
  CMD_PIXEL = $20_00_00_00
  CMD_START = $40_00_00_00
  CMD_LINE  = $60_00_00_00

VAR

  long  pixel_bfr[LSIZE]
  long  pixel_colors, frame_count, draw_command
  long  cursor_pos, cursor_mask
  byte  cursorx, cursory, cog0, cog1, cursor_state

PUB Char(ch)
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, then advance the cursor.
'' Used 0 for background color and 1 for foreground color.
''
'' ch - Character to print.
'------------------------------------------------------------------------------------------------
  CChar(ch, 1, 0)

PUB CChar(ch, fg, bg) | i, j, ptr, val, pix
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, in the fg and bg colors, then advance the cursor.
''
'' ch - Character to print, 0 to 255.
'' fg - Foreground color number, 0 to 3.
'' bg - Background color number, 0 to 3.
'------------------------------------------------------------------------------------------------
  'If a printable character
  if ch > 31
    repeat while draw_command <> 0
    draw_command := ch | (cursorx << 8) | (cursory << 17) | (fg << 25) | (bg << 27)
    'draw_command := ch | (cursorx << 8) | (cursory << 17) | (fg << 25) | (bg << 27)
    cursorx += 1

  'elseif ch == CR
  '  cursorx := 0
  '  cursory += 1

  'elseif ch == BS
  '  if cursorx > 0
  '    cursorx -= 1
  '    repeat while draw_command <> 0
  '  draw_command := 32 | (cursorx << 8) | (cursory << 17) | (bg << 27)
       
  'elseif ch == CLS
  '  longfill(@pixel_bfr, 0, LSIZE)
  '  cursorx := 0
  '  cursory := 0

  'elseif ch == HOME
  '  cursorx := 0
  '  cursory := 0
    
  'elseif ch == TAB
  '  cursorx := (cursorx + 4) & $FC

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

PUB Str(s, fg, bg) | b
'------------------------------------------------------------------------------------------------
'' Write a NULL terminated string starting at the current cursor position.
''
'' s  - Address of a Null terminated string.
'' fg - Foreground color number, 0 to 3.
'' bg - Background color number, 0 to 3.
'------------------------------------------------------------------------------------------------
  repeat
    b := byte[s]
    if b == 0
      return
    CChar(b, fg, bg)
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

  longfill(@pixel_bfr + (COLS2 * first_line), 0, line_count * WPROW)

PUB ClearScreen
    longfill(@pixel_bfr, 0, LSIZE)
    
PUB Pixel(c, x, y) | p, q
'------------------------------------------------------------------------------------------------
'' Plots a single pixel on the screen.
''
'' c - Color number, 0 to 3.
'' x - The X pixel coordinate.
'' y - The Y pixel coordinate.
'------------------------------------------------------------------------------------------------
  repeat while draw_command <> 0
  draw_command := (c & 3) | (x << 8) | (y << 17) | CMD_PIXEL

PUB Line(c, x1, y1, x2, y2) | dx, dy, df, a, b, d1, d2
'------------------------------------------------------------------------------------------------
'' Draw a line on the screen.
''
'' c      - Color number, 0 to 3.
'' x1, y1 - XY coordinates of start of line.
'' x2, y2 - XY coordinates of end of line.
'------------------------------------------------------------------------------------------------
  repeat while draw_command <> 0
  draw_command := c | (x1 << 8) | (y1 << 17) | CMD_START
  repeat while draw_command <> 0
  draw_command := c | (x2 << 8) | (y2 << 17) | CMD_LINE

PUB LineTo(c, x, y)
'------------------------------------------------------------------------------------------------
'' Draw a line on the screen starting from the end of the last line.
''
'' c    - Color number, 0 or 1.
'' x, y - XY coordinates of end of line.
'------------------------------------------------------------------------------------------------
  repeat while draw_command <> 0
  draw_command := c | (x << 8) | (y << 17) | CMD_LINE

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
'' color_num - The color number to change for the whole screen, 0 to 3.
'' new_color - A color byte (%RR_GG_BB_xx) describing the pixel's new color.
'------------------------------------------------------------------------------------------------
  color_num &= 3
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
  'output_enables := ($FF << (pin_group << 3))
  'vcfg_reg := $30_00_00_FF | (pin_group << 9)
  
  output_enables := ($FF << (pin_group << 3))
  vcfg_reg := $30_00_04_1F  'check prop manual for vcfg for more details on configuring video
    
  colors_ptr := @pixel_colors
  frame_cntr_ptr := @frame_count
   
  cursorx := 0
  cursory := 0
  cursor_state := FALSE
  cursor_pos := 0
  cursor_pos_ptr := @cursor_pos
  cursor_mask := 0
  cursor_mask_ptr := @cursor_mask

  cog0 := cognew(@asm_start, @pixel_bfr) + 1

  draw_cmnd_ptr := @draw_command
  draw_map_ptr := @C64CharMap
  cog1 := cognew(@draw_start, @pixel_bfr) + 1

  return cog0 <> 0 and cog1 <> 0
   
PUB Stop
'------------------------------------------------------------------------------------------------
'' Shuts down the C64 driver running on a cog.
'------------------------------------------------------------------------------------------------
  if cog0 > 0
    cogstop(cog0 - 1)

  if cog1 > 0
    cogstop(cog1 - 1)

PRI UpdateCursor | cpos
'------------------------------------------------------------------------------------------------
'' Update the cursor position.
'------------------------------------------------------------------------------------------------
  if cursor_state
    cpos := @pixel_bfr + (cursory * WIDTH * 2) + constant(14 * COLS)
    cpos := cpos + ((cursorx & $FFFE) << 1)
    cursor_mask := $5555 << ((cursorx & 1) << 4)
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
                        mov     pixel_cntr, #WPROW
                        mov     pixel_ptr1, pixel_ptr0

video_loop3             rdlong  pixel_values, pixel_ptr1
                        cmp     pixel_ptr1, cursor_pos0  wz
              if_z      or      pixel_values, cursor_mask0
              if_z      and     pixel_values, cursor_mask0
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
video_scale             long    $000_01_010

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

'------------------------------------------------------------------------------------------------
' Routines to draw on the bitmap
'------------------------------------------------------------------------------------------------
                        org     0

'---- Wait for a command, then decode -----------------------------------------------------------
draw_start              rdlong  draw_cmnd, draw_cmnd_ptr  wz 'read command from pointer location. if result is 0, z flag will be set.
              if_z      jmp     #draw_start                  'if z flag is set (0) then loop back to draw_start

                        mov     draw_cntr0, #0               'set draw_cntr0 to 0
                        wrlong  draw_cntr0, draw_cmnd_ptr    'setting draw_cmnd_ptr to 0 (frees up calling procedure)

                        mov     draw_val, draw_cmnd          'set draw_val to draw_cmnd
                        and     draw_val, #255               'and draw_val by 255 (1111_1111) mask
                        shr     draw_cmnd, #8                'shift 8 bits over to the right
                        mov     draw_xpos, draw_cmnd         'set draw_xpos to draw_cmnd
                        and     draw_xpos, #511              'and draw_xpos with 511(1_1111_1111) 9 bits mask
                        shr     draw_cmnd, #9                'shift 9 bits right for draw_cmnd
                        mov     draw_ypos, draw_cmnd         'set draw_ypos = draw_cmnd
                        and     draw_ypos, #255              'apply 8 bit mask to draw_ypos
                        shr     draw_cmnd, #8                '...
                        mov     draw_fg, draw_cmnd
                        and     draw_fg, #3
                        shr     draw_cmnd, #2
                        mov     draw_bg, draw_cmnd
                        and     draw_bg, #3
                        shr     draw_cmnd, #2                'get command, go to appropriate routine

                        cmp     draw_cmnd, #3  wz
              if_z      jmp     #draw_line

                        cmp     draw_cmnd, #1  wz
              if_z      jmp     #draw_pixel

                        cmp     draw_cmnd, #2  wz
              if_z      jmp     #draw_set                    'if command is char, will just fall through to below routine

'---- Draw a character --------------------------------------------------------------------------
'    ch := (ch - 32) << 3
draw_char               sub     draw_val, #32                'draw_val just holds the char value from draw_start routine
                        shl     draw_val, #3

'    ptr1 := @C64CharMap + ch
                        mov     draw_ptr1, draw_map_ptr      'take value and add it to map pointer to get pointer to char rom
                        add     draw_ptr1, draw_val          'draw_ptr1 is the pointer to the char rom

'    ptr0 := @pixel_bfr + ((cursorx + (cursory * WIDTH)) << 1)
                        mov     draw_ptr0, draw_xpos         'draw_ptr0 is the x,y pointer to the pixel buffer

draw_char1              test    draw_ypos, #255  wz          'AND 255 with draw_ypos
              if_nz     sub     draw_ypos, #1                'if Z flag not set, subtract 1 from draw_ypos and add #width to draw_ptr0
              if_nz     add     draw_ptr0, #WIDTH            'finds the y starting point for the char
              if_nz     jmp     #draw_char1

                        shl     draw_ptr0, #1
                        add     draw_ptr0, par               'once y is found, store the pointer to shared ram (pixel buf)

'    repeat i from 0 to 7
                        mov     draw_cntr0, #8               'counter to hold num rows to iterate

'      pix := byte[ptr1 + i]
draw_char2              rdbyte  draw_pix, draw_ptr1          'reads one byte from font rom char
                        add     draw_ptr1, #1 '#1            'increment font rom pointer by 1

'      val := 0 
                        mov     draw_val, #0 '#0
'      repeat j from 0 to 7
                        mov     draw_cntr1, #7 '#8           'counter to hold num cols to iterate

'        val <<= 2
draw_char3              shl     draw_val, #2                 'iterates font row
                                                             'draw fg or bg depending on whether bit is set in font rom
'        if pix & $80 val |= fg
                        test    draw_pix, #$80  wz
              if_nz     or      draw_val, draw_fg

'        else val |= bg
              if_z      or      draw_val, draw_bg

'        pix <<= 1
                        shl     draw_pix, #1
                        djnz    draw_cntr1, #draw_char3     'decrement x counter, go to next column

'      word[ptr0] := val
'      ptr += COLS2
                        wrword  draw_val, draw_ptr0         'write value to pixel buffer
                        add     draw_ptr0, #COLS2           'updates pix buffer pointer to next column?

                        djnz    draw_cntr0, #draw_char2     'decrement y counter, go to next row
                        jmp     #draw_start                 'if done, go to draw_start routine

'---- Draw a pixel ------------------------------------------------------------------------------
'  p1 := (WIDTH * y) + x
draw_pixel_sub          mov     draw_ptr1, draw_xpos

draw_pixel1             test    draw_ypos, #255  wz
              if_nz     sub     draw_ypos, #1
              if_nz     add     draw_ptr1, #WIDTH
              if_nz     jmp     #draw_pixel1

'  p0 := (p1 & 3) << 1
                        mov     draw_ptr0, draw_ptr1
                        and     draw_ptr0, #3
                        shl     draw_ptr0, #1
'  t := c << p0
                        mov     draw_tmp, draw_val
                        shl     draw_tmp, draw_ptr0

'  y := 3 << p0
                        mov     draw_ypos, #3
                        shl     draw_ypos, draw_ptr0

'  p1 := p1 >> 2
                        shr     draw_ptr1, #2

'  p1 := @pixel_bfr + p1
                        add     draw_ptr1, par

'  byte[p1] := (byte[p1] & !y) | t
                        rdbyte  draw_pix, draw_ptr1
                        andn    draw_pix, draw_ypos
                        or      draw_pix, draw_tmp
                        wrbyte  draw_pix, draw_ptr1
draw_pixel_sub_ret      ret

draw_pixel              call    #draw_pixel_sub
                        jmp     #draw_start

'---- Set the coordinates of the start of a line ------------------------------------------------
draw_set                mov     draw_lastx, draw_xpos
                        mov     draw_lasty, draw_ypos
                        jmp     #draw_start

'---- Draw a line -------------------------------------------------------------------------------
draw_line

'  dy := y2 - y1
                        mov     draw_dy, draw_ypos
                        sub     draw_dy, draw_lasty

'  dx := x2 - x1
                        mov     draw_dx, draw_xpos
                        sub     draw_dx, draw_lastx  wc

'  if dx >= 0
              if_nc     mov     draw_x1, draw_lastx
              if_nc     mov     draw_x2, draw_xpos
              if_nc     mov     draw_y1, draw_lasty
              if_nc     mov     draw_y2, draw_ypos

'  else dx < 0
              if_c      mov     draw_x1, draw_xpos
              if_c      mov     draw_x2, draw_lastx
              if_c      mov     draw_y1, draw_ypos
              if_c      mov     draw_y2, draw_lasty
              if_c      neg     draw_dx, draw_dx
              if_c      neg     draw_dy, draw_dy

'  lastx := xpos
'  lasty := ypos
                        mov     draw_lastx, draw_xpos
                        mov     draw_lasty, draw_ypos

'  d1 := 1
'  if dy < 0
'    d1 := -1
'    dy := -dy
                        mov     draw_d1, #1
                        neg     draw_dy, draw_dy  wc, nr
              if_c      neg     draw_d1, draw_d1
              if_c      neg     draw_dy, draw_dy

'  a := b := 0

'  if dx > dy df := 1
'  else       df := -1
                        cmp     draw_dy, draw_dx  wc
              if_c      mov     draw_df, #1
              if_nc     neg     draw_df, #1

'  repeat
draw_line1

'    Pixel(c, x1, y1)
                        mov     draw_xpos, draw_x1
                        mov     draw_ypos, draw_y1
                        call    #draw_pixel_sub

'    if df < 0
'      y1 += d1
'      df += dx
                        neg     draw_df, draw_df  wc, nr
              if_c      add     draw_y1, draw_d1
              if_c      add     draw_df, draw_dx

'    else df >= 0
'      x1 += 1
'      df -= dy
              if_nc     add     draw_x1, #1
              if_nc     sub     draw_df, draw_dy

'  until (x1 >= x2) and (y1 == y2)
                        cmp     draw_x2, draw_x1  wz
        if_nz_and_nc    jmp     #draw_line1
                        cmp     draw_y1, draw_y2  wz
        if_nz           jmp     #draw_line1

draw_line2
'  Pixel(c, x1 + a, y1 + b)
                        mov     draw_xpos, draw_x1
                        mov     draw_ypos, draw_y1
                        call    #draw_pixel_sub
                        jmp     #draw_start

draw_cmnd_ptr           long    0
draw_map_ptr            long    0
draw_reverse_ptr        long    0
draw_lastx              long    0
draw_lasty              long    0

draw_cmnd               res     1
draw_fg                 res     1
draw_bg                 res     1
draw_val                res     1
draw_tmp                res     1
draw_xpos               res     1
draw_ypos               res     1
draw_ptr0               res     1
draw_ptr1               res     1
draw_cntr0              res     1
draw_cntr1              res     1
draw_pix                res     1
draw_a                  res     1
draw_b                  res     1
draw_x1                 res     1
draw_y1                 res     1
draw_x2                 res     1
draw_y2                 res     1
draw_dx                 res     1
draw_dy                 res     1
draw_d1                 res     1
draw_df                 res     1
                        fit

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
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                       TERMS OF USE: MIT License                            â”‚                                                            
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚Permission is hereby granted, free of charge, to any person obtaining       â”‚
â”‚a copy of this software and associated documentation files (the "Software"),â”‚
â”‚to deal in the Software without restriction, including without limitation   â”‚
â”‚the rights to use, copy, modify, merge, publish, distribute, sublicense,    â”‚
â”‚and/or sell copies of the Software, and to permit persons to whom the       â”‚
â”‚Software is furnished to do so, subject to the following conditions:        â”‚                                                           â”‚
â”‚                                                                            â”‚                                                  â”‚
â”‚The above copyright notice and this permission notice shall be included in  â”‚
â”‚all copies or substantial portions of the Software.                         â”‚
â”‚                                                                            â”‚                                                  â”‚
â”‚THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  â”‚
â”‚IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,    â”‚
â”‚FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL     â”‚
â”‚THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  â”‚
â”‚LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     â”‚
â”‚FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         â”‚
â”‚DEALINGS IN THE SOFTWARE.                                                   â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
}}