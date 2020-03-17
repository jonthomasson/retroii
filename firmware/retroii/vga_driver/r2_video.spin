''------------------------------------------------------------------------------------------------
'' RETRO ][ video driver
''
'' Copyright (c) 2020 Jon Thomasson
''
''------------------------------------------------------------------------------------------------

'' This version uses two cogs, one for the VGA output, and one for routines that draw
'' on the bitmap.
''------------------------------------------------------------------------------------------------
'' Video Circuit:
''
'' Pin              VGA
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

  '288x240 resolution
  WIDTH  = 288 '288
  HEIGHT = 240
  FREQ_VALUE = 608207634 '304103817 '304104364
  CTRA_VALUE = %0_00001_011 '%0_00001_100
  FP = 7 '7
  SP = 43'43
  BP = 22'22

  'Color value constants
  #$04, BLUE, #$08, GREEN
  #$10, RED, #$0C, LT_BLUE
  #$18, YELLOW, #$14, LT_RED
  #$00, BLACK, #$1C, WHITE 

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

  CMD_CHAR  = $00_00_00_00
  CMD_PIXEL = $04_00_00_00
  CMD_LORES = $10_00_00_00
  CMD_LINE  = $20_00_00_00
  
VAR 

  long  pixel_bfr[LSIZE]
  long  pixel_colors, frame_count, cursor_pos, cursor_mask, draw_command, debug_val
  byte  cursorx, cursory, cog1, cog2, reverse, cursor_state

PUB Char(c) | idx, ptr, tmp
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, then advance the cursor.
''
'' c - Character to print.
'------------------------------------------------------------------------------------------------
  c &= 255

  'If a printable character
  if c > 31
    repeat while draw_command <> 0
    draw_command := c | (cursorx << 8) | (cursory << 17)
    cursorx += 1

  UpdateCursor

PUB RChar(c)
'------------------------------------------------------------------------------------------------
'' Print a character on the screen, in reverse video, then advance the cursor.
''
'' c - Character to print.
'------------------------------------------------------------------------------------------------
  reverse := 255
  Char(c)
  reverse := 0

PUB LowRes(c, x, y) 
'------------------------------------------------------------------------------------------------
'' Plots a lores byte of data on the screen.
''
'' c - data byte.
'' x - The X coordinate.
'' y - The Y coordinate.
'------------------------------------------------------------------------------------------------
  repeat while draw_command <> 0
  draw_command := c | (x << 8) | (y << 17) | CMD_LORES

PUB LowRes2(data, x, y)|bottom, top,idx, ptr, ptr2, graphicx, offset, tmp
    'bottom block = left nibble
    bottom := data >> 4
    bottom |= (data & $F0) 'duplicate nibble on both s
    bottom &= $0FE
    'top block = right nibble
    top := data << 4
    top |= (data & $0F) 'duplicate nibble on both sides
    top &= $0FE
    'need to determine which 8x8 graphic tile(s) we need to update
    x := x << 1 'x * 2
    graphicx := byte[@FontToGraphicMap][x] 'graphic tile column
    offset := byte[@FontToGraphicMap][x + 1] 'offset for our font tile
    
    ptr := @pixel_bfr + (graphicx + (Y * WIDTH))
    ptr2 := ptr + 1 '@pixel_bfr + ((graphicx + 1) + (cursory * WIDTH))
    repeat idx from 0 to 7 'y
        if idx < 4
            tmp := top
        else
            tmp := bottom
            
        if offset > 0 '7x8 tile will take up 2 graphic tiles
            byte[ptr] &= !($FF << (8 - offset)) 'mask to clear offset bits
            byte[ptr] |= (tmp) << (7 - offset) 'write left part of char
            byte[ptr2] &= !($FF >> (offset + 1)) 'mask
            byte[ptr2] |= (tmp) >> (offset + 1)'right part of char
            ptr2 += COLS                                   
        else 'font tile is encapsulated in one graphic tile
            byte[ptr] &= $FF << 7 'mask to clear offset bits
            byte[ptr] |= (tmp) >> (offset + 1)
        
        ptr += COLS 'increment ptr to go to next y coord of graphic tile

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
  cursorx := X
  cursory := Y
  'cursorx := (X <# MAX_C) #> 0 
  'cursory := (Y <# MAX_R) #> 0 
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

PUB ClearScreen
    longfill(@pixel_bfr, 0, LSIZE)
    
PUB Pixel(c, x, y) | p
'------------------------------------------------------------------------------------------------
'' Plots a byte of pixels on the screen.
''
'' c - byte containing pixel data.
'' x - The X pixel coordinate.
'' y - The Y pixel coordinate.
'------------------------------------------------------------------------------------------------
  repeat while draw_command <> 0
  draw_command := c | (x << 8) | (y << 17) | CMD_PIXEL

PUB PixelByte(data, col, row) | p, mask, data2, x
'------------------------------------------------------------------------------------------------
'' Plots a byte of pixels on the screen.
''
'' c - byte containing pixel data.
'' x - The X pixel coordinate.
'' y - The Y pixel coordinate.
'------------------------------------------------------------------------------------------------
  
  data &= $7F 'get rid of msb
  x := (col * 7) '- 7
  p := (WIDTH * row) + x 'get byte location of our column of data
  
  'x := |<(p & 7) 'finds x coord in byte
  x := (p & 7) 'find x position in byte
  
  p := @pixel_bfr + (p >> 3) ' find our byte inside the pixel buffer
  data2 := data << (x)
  mask := $FF000080 <- x
  byte[p] &= mask
  'write data to 1st byte
  byte[p] |= data2
  'return data2
  if x > 1
    data2 := data >> (8 - x) 'data for right most byte
    mask := $FF << (x - 1)
    byte[p + 1] &= mask
    byte[p + 1] |= data2

PUB HiRes
  repeat while draw_command <> 0
  draw_command := CMD_LINE
    
PUB Line(c, x1, y1, x2, y2)' | dx, dy, df, a, b, d1, d2
'------------------------------------------------------------------------------------------------
'' Draw a line on the screen.
''
'' c      - Color number, 0 or 1.
'' x1, y1 - XY coordinates of start of line.
'' x2, y2 - XY coordinates of end of line.
'------------------------------------------------------------------------------------------------
  'repeat while draw_command <> 0
  'draw_command := c | (x1 << 8) | (y1 << 17) | CMD_START
  'repeat while draw_command <> 0
  'draw_command := c | (x2 << 8) | (y2 << 17) | CMD_LINE

  
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
  draw_command := 0
  debug_val_ptr := @debug_val
   
  cog1 := cognew(@asm_start, @pixel_bfr) + 1
  if cog1 == 0
    return FALSE

  draw_cmnd_ptr := @draw_command
  draw_map_ptr := @C64CharMap
  draw_graphmap_ptr := @FontToGraphicMap
  draw_reverse_ptr := @reverse
  draw_ymulwidth_ptr := @YMulWidth
  
  cog2 := cognew(@draw_start, @pixel_bfr) + 1
  if cog2 == 0
    cogstop(cog1 - 1)
    return FALSE  

  return TRUE  
  
PUB DebugOutput
    return debug_val

PUB Stop
'------------------------------------------------------------------------------------------------
'' Shuts down the C64 driver running on a cog.
'------------------------------------------------------------------------------------------------
  if cog1 > 0
    cogstop(cog1 - 1)

  if cog2 > 0
    cogstop(cog2 - 1)

PRI UpdateCursor | cpos, cx, offset, x
'------------------------------------------------------------------------------------------------
'' Update the cursor position.
'------------------------------------------------------------------------------------------------
  
  if cursor_state
    x := cursorx * 2
    cx := byte[@FontToGraphicMap][x]
    offset := byte[@FontToGraphicMap][x + 1]
    
    cpos := @pixel_bfr + (cursory * WIDTH) + constant(7 * COLS) 'need to get rid of cols
    cpos := cpos + (cx & $FFFC)
    if offset > 0
        cursor_mask := $FE << ((cx & 3) << 3) << (6 - offset)
    else
        cursor_mask := $FE << ((cx & 3) << 3) '>> (offset)
    'ptr := @pixel_bfr + (graphicx + (cursory * WIDTH))
    cursor_pos := cpos

DAT
'------------------------------------------------------------------------------------------------
                        org     0

asm_start               mov     frqa, freq_reg
                        movi    ctra, #CTRA_VALUE
                        mov     vcfg, vcfg_reg
                        mov     dira, output_enables
{
Timing taken from :http://tinyvga.com/vga-timing/640x480@60Hz

                    640 X 480 VIDEO TIMING 
                            HSYNC
         ____________________________________________ _____16______ _____96_____ _____48____
         |                 DISPLAY                   | FRONT PORCH | SYNC PULSE | BACK PORCH|
         |                                           |
         |                                           |
         |                                           |
         |                                           |
         |                                           |
      V  |                                           |
      S  |                                           |
      Y  |                                           |
      N  |                                           |
      C  |                                           |
         |                                           |      
         |                                           |      
         |___________________________________________|                                                
         |
         |
         |10 FRONT PORCH
         |
         |-
         |
         |2 SYNC PULSE
         |                                      BLANKING AREA
         |-
         |
         |33 BACK PORCH
         |
         |_
         
GENERAL TIMING
    -SCREEN REFRESH RATE:   60HZ
    -VERTICAL REFRESH:      31.46875KHZ
    -PIXEL FREQ:            25.175MHZ
    
HORIZONTAL TIMING
| SCANLINE PART | PIXELS | TIME uS 
| VISIBLE AREA  | 640    | 25.422045680238
| FRONT PORCH   | 16     | 0.63555114200596
| SYNC PULSE    | 96     | 3.8133068520357
| BACK PORCH    | 48     | 1.9066534260179
| WHOLE LINE    | 800    | 31.777557100298

VERTICAL TIMING
| SCANLINE PART | PIXELS | TIME uS 
| VISIBLE AREA  | 480    | 15.253227408143
| FRONT PORCH   | 10     | 0.31777557100298
| SYNC PULSE    | 2      | 0.063555114200596
| BACK PORCH    | 33     | 1.0486593843098
| WHOLE FRAME   | 525    | 16.683217477656


below are the routines for the VGA driver. They consist of 4 main loops.
These loops drive the vertical sync pulse (vsync_loop), the vertical sync
back porch (vsbp_loop), the active video lines (video_loop1), and finally
the vertical sync front porch (vsfp_loop). These loops provide the video signals
for the VGA and are repeated indefinitely.
}

'--- Vertical Sync ------------------------------------------------------------------------------
vsync_loop              mov     line_cntr, #2                       'sync pulse is 2 lines for 640x480 spec

vs_loop                 mov     vscl, #PC_FP
                        waitvid vs_colors, #0
                        mov     vscl, #SP
                        waitvid vs_colors, #1
                        mov     vscl, #BP
                        waitvid vs_colors, #0
                        djnz    line_cntr, #vs_loop

'--- Vertical Sync Back Porch -------------------------------------------------------------------
                        mov     line_cntr, #33                      'back porch is 33 lines

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
                        
                        mov     line_cntr, #HEIGHT                  'active video lines = resolution height
                        rdlong  vid_colors, colors_ptr
                        or      vid_colors, blank_colors

                        mov     cursor_mask0, frame_cntr            'mask off cursor, if cursor is in visible area?
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
video_loop1             mov     block_cntr, #BLKS                   'will repeat each video line twice (480/240 height)
video_loop2             mov     vscl, video_scale                   'video_scale is $000_01_010
                        mov     pixel_cntr, #LPROW
                        mov     pixel_ptr1, pixel_ptr0
                        
video_loop3             rdlong  pixel_values, pixel_ptr1            'main loop to display pixel buffer for a single line
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
                        mov     line_cntr, #10                      'front porch is 10 lines
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
                        fit

'------------------------------------------------------------------------------------------------
' Routines to draw on the bitmap
'------------------------------------------------------------------------------------------------
                        org     0

'---- Wait for a command, then decode -----------------------------------------------------------
draw_start              rdlong  draw_cmnd, draw_cmnd_ptr  wz
              if_z      jmp     #draw_start

                        mov     draw_cntr, #0
                        wrlong  draw_cntr, draw_cmnd_ptr

                        mov     draw_val, draw_cmnd
                        and     draw_val, #255
                        shr     draw_cmnd, #8
                        mov     draw_xpos, draw_cmnd
                        and     draw_xpos, #511
                        shr     draw_cmnd, #9
                        mov     draw_ypos, draw_cmnd
                        and     draw_ypos, #511
                        shr     draw_cmnd, #9

                        cmp     draw_cmnd, #8  wz
              if_z      jmp     #draw_hires

                        cmp     draw_cmnd, #1  wz
              if_z      jmp     #draw_pixel

                        cmp     draw_cmnd, #4  wz
              if_z      jmp     #draw_lores

'---- Draw a character --------------------------------------------------------------------------
'    c := (c - 32) << 3
draw_char               rdbyte  draw_reverse, draw_reverse_ptr
                        sub     draw_val, #32
                        shl     draw_val, #3
                        mov     draw_ptr1, draw_map_ptr
                        add     draw_ptr1, draw_val
                        
'    'need to determine which 8x8 graphic tile(s) we need to update
'    x := cursorx * 2
                        mov     draw_x, draw_xpos                       'copy xpos to x
                        shl     draw_x, #1                              'shift left one time to mult by 2

'    graphicx := byte[@FontToGraphicMap][x] 'graphic tile column
                        mov     char_t1, draw_graphmap_ptr
                        add     char_t1, draw_x  
                        rdbyte  char_graphicx, char_t1  
                 
'    offset := byte[@FontToGraphicMap][x + 1] 'offset for our font tile
                        add     char_t1, #1
                        rdbyte  char_offset, char_t1
                        
'    ptr := @pixel_bfr + (graphicx + (cursory * WIDTH))
                        mov     draw_ptr0, #0                           '0 out pointer
draw_char1              test    draw_ypos, #255  wz                     'mult cursory * width

                         
                        
              if_nz     sub     draw_ypos, #1               
              if_nz     add     draw_ptr0, #WIDTH
              if_nz     jmp     #draw_char1

                        
                        'new routine using lut to replace multiply
                        'rdlong would be more efficient here, but 
                        'there was a problem reading bytes since they weren't
                        'long aligned...
                        'mov     char_t1, draw_ymulwidth_ptr
                        'shl     draw_ypos, #1
                        'add     char_t1, draw_ypos  
                        'rdbyte  draw_ptr0, char_t1 
                        'add     char_t1, #1
                        'shl     draw_ptr0, #8
                        'rdbyte  char_t2, char_t1 
                        'or      draw_ptr0, char_t2
                        
                        
                        
                        add     draw_ptr0, char_graphicx                'add graphicx
                        add     draw_ptr0, par                          'add @pixel_bfr
'    ptr2 := ptr + 1 '@pixel_bfr + ((graphicx + 1) + (cursory * WIDTH))
                        mov     draw_ptr2, draw_ptr0
                        add     draw_ptr2, #1
                        
'    repeat idx from 0 to 7 'y
                        mov     draw_cntr, #8
                        mov     char_offset2, char_offset
                        add     char_offset2, #1                        
'        tmp := byte[@C64CharMap][idx + c] 'pointer to our char in font rom
draw_char3              rdbyte  draw_xpos, draw_ptr1
                        add     draw_ptr1, #1        
                        tjnz    char_offset, #draw_char4    
                        'if offset is zero fall through to below code
'        else 'font tile is encapsulated in one graphic tile
'            byte[ptr] &= $FF << 7 'mask to clear offset bits
'            byte[ptr] |= (tmp ^ reverse) >> (offset + 1)

                        mov     char_t1, #255
                        shl     char_t1, #7

                        rdbyte  char_ptr0, draw_ptr0
                        and     char_ptr0, char_t1
                        'wrbyte  char_ptr0, draw_ptr0  
                                
                        xor     draw_xpos, draw_reverse
                        shr     draw_xpos, char_offset2
                        'rdbyte  char_ptr0, draw_ptr0
                        or      char_ptr0, draw_xpos
                        wrbyte  char_ptr0, draw_ptr0                       
                        jmp     #draw_char5
                        
'       if offset > 0 '7x8 font tile will take up 2 graphic tiles                  

'            byte[ptr] &= !($FF << (8 - offset)) 'mask to clear offset bits
'            byte[ptr] |= (tmp ^ reverse) << (7 - offset) 'write left part of char
draw_char4              mov     char_t1, #8
                        sub     char_t1, char_offset
                        mov     char_t2, #255
                        shl     char_t2, char_t1
                        rdbyte  char_ptr0, draw_ptr0
                        andn    char_ptr0, char_t2
                        'wrbyte  char_ptr0, draw_ptr0
                        
                        mov     char_t2, draw_xpos 'make copy of draw_xpos so we can use it later
                        mov     char_t1, #7
                        sub     char_t1, char_offset
                        xor     draw_xpos, draw_reverse
                        shl     draw_xpos, char_t1
                        'rdbyte  char_ptr0, draw_ptr0
                        or      char_ptr0, draw_xpos
                        wrbyte  char_ptr0, draw_ptr0 
                         
'            byte[ptr2] &= !($FF >> (offset + 1)) 'mask
'            byte[ptr2] |= (tmp ^ reverse) >> (offset + 1)'right part of char
                        mov     char_t1, #255
                        shr     char_t1, char_offset2
                        rdbyte  char_ptr0, draw_ptr2
                        andn    char_ptr0, char_t1
                        'wrbyte  char_ptr0, draw_ptr2
                                 
                        xor     char_t2, draw_reverse
                        shr     char_t2, char_offset2
                        'rdbyte  char_ptr0, draw_ptr2
                        or      char_ptr0, char_t2
                        wrbyte  char_ptr0, draw_ptr2   
'            ptr2 += COLS 
                        add     draw_ptr2, #COLS


'        ptr += COLS 'increment ptr to go to next y coord of graphic tile
draw_char5              add     draw_ptr0, #COLS     
                        
                        djnz    draw_cntr, #draw_char3
                        jmp     #draw_start                                 

'    c := (c - 32) << 3
'draw_char               rdbyte  draw_reverse, draw_reverse_ptr
'                        sub     draw_val, #32
'                        shl     draw_val, #3
'                        mov     draw_ptr1, draw_map_ptr
'                        add     draw_ptr1, draw_val
'
'    ptr := @pixel_bfr + (cursorx + (cursory * WIDTH))
'                        mov     draw_ptr0, #0
'                        
'draw_char1              test    draw_ypos, #255  wz
'
'              if_nz     sub     draw_ypos, #1
'              if_nz     add     draw_ptr0, #WIDTH
'              if_nz     jmp     #draw_char1
'                        
'                        add     draw_ptr0, draw_xpos
'                        add     draw_ptr0, par
'                        
'    repeat idx from 0 to 7
'                        mov     draw_cntr, #8
'
'      tmp := byte[@C64CharMap][idx + c]
'draw_char2              rdbyte  draw_xpos, draw_ptr1
'                        add     draw_ptr1, #1
'
'      byte[ptr] := tmp ^ reverse
'      ptr += COLS
'                        xor     draw_xpos, draw_reverse
'                        wrbyte  draw_xpos, draw_ptr0
'                        add     draw_ptr0, #COLS     
'                        
'                        djnz    draw_cntr, #draw_char2
'                        jmp     #draw_start


'---- Draw a byte of pixels ------------------------------------------------------------------------------
'  data &= $7F 'get rid of msb
'  x := (col * 7) '- 7
draw_pixel_sub          and     draw_val, #127  'get rid of msb since we don't need color info
                        mov     draw_val2, draw_val
                        mov     char_t1, #0
                                             
draw_pix0               test    draw_xpos, #255  wz
              if_nz     sub     draw_xpos, #1
              if_nz     add     char_t1, #7
              if_nz     jmp     #draw_pix0   
              
                                   
'  p := (WIDTH * y) + x
                        mov     draw_ptr0, char_t1

draw_pix1               test    draw_ypos, #255  wz
              if_nz     sub     draw_ypos, #1
              if_nz     add     draw_ptr0, #WIDTH
              if_nz     jmp     #draw_pix1
                        'new routine using lut to replace multiply
                        'rdlong would be more efficient here, but 
                        'there was a problem reading bytes since they weren't
                        'long aligned...
                        
                        'mov     char_t1, draw_ymulwidth_ptr
                        'shl     draw_ypos, #1
                        'add     char_t1, draw_ypos  
                        'rdbyte  draw_ptr0, char_t1 
                        'add     char_t1, #1
                        'shl     draw_ptr0, #8
                        'rdbyte  char_t2, char_t1 
                        'or      draw_ptr0, char_t2
                        
'  x := (p & 7)'find x position in byte
                        mov     draw_ypos, draw_ptr0
                        and     draw_ypos, #7
                        'mov     draw_xpos, #1
                        'shl     draw_xpos, draw_ypos
                        mov     char_t1, draw_ypos
                        
'  p := @pixel_bfr + (p >> 3)
                        shr     draw_ptr0, #3
                        add     draw_ptr0, par
                        mov     draw_ptr1, draw_ptr0
                        add     draw_ptr1, #1
'  data2 := data << (x)
                        shl     draw_val, char_t1
                        mov     char_t2, draw_val
                       
'  mask := $FF000080 <- x
'  byte[p] &= mask
'  'write data to 1st byte
'  byte[p] |= data2
                        rdbyte  draw_tmp, draw_ptr0
                        'start debug
                        'mov     debug_ptr, draw_tmp
                        'wrlong  debug_ptr, debug_val_ptr
                        'jmp     #draw_start  
                        'end debug
                        mov     draw_tmp2, char_t1
                        mov     pixel_mask2, pixel_mask
                        rol     pixel_mask2, draw_tmp2
                        and     draw_tmp, pixel_mask2
                        'start debug
                        'mov     debug_ptr, draw_tmp
                        'wrlong  debug_ptr, debug_val_ptr
                        'jmp     #draw_start  
                        'end debug
                        or      draw_tmp, char_t2
                        wrbyte  draw_tmp, draw_ptr0
                        
     
'  if x > 1
'    data2 := data >> (8 - x) 'data for right most byte
'    mask := $FF << (x - 1)
'    byte[p + 1] &= mask
'    byte[p + 1] |= data2
                        mov     char_t2, char_t1
                        shr     char_t2, #1 wz
                if_z    jmp     #draw_pixel_sub_ret
                
                        mov     char_t2, #8
                        sub     char_t2, char_t1
                        shr     draw_val2, char_t2
                        
                        rdbyte  draw_tmp, draw_ptr1
                        sub     char_t1, #1
                        mov     draw_tmp2, #255
                        shl     draw_tmp2, char_t1
                        and     draw_tmp, draw_tmp2
                        or      draw_tmp, draw_val2
                        wrbyte  draw_tmp, draw_ptr1                       
'  if c byte[p] |= x
'  else byte[p] &= (!x)
'                        and     draw_val, #1  wz
'                        rdbyte  draw_tmp, draw_ptr0
'              if_nz     or      draw_tmp, draw_xpos
'              if_z      andn    draw_tmp, draw_xpos
'                        wrbyte  draw_tmp, draw_ptr0
draw_pixel_sub_ret      ret

draw_pixel              call    #draw_pixel_sub
                        jmp     #draw_start

'---- draw a byte of lores mode ------------------------------------------------
draw_lores       
    'bottom block = left nibble
    'bottom := data >> 4
    'bottom |= (data & $F0) 'duplicate nibble on both s
    'bottom &= $0FE
                        mov     draw_tmp, draw_val
                        shr     draw_tmp, #4
                        mov     lores_bottom, draw_tmp
                        mov     draw_tmp, draw_val
                        and     draw_tmp, #240
                        or      lores_bottom, draw_tmp
                        and     lores_bottom, #254
    'top block = right nibble
    'top := data << 4
    'top |= (data & $0F) 'duplicate nibble on both sides
    'top &= $0FE
                        mov     draw_tmp, draw_val
                        shl     draw_tmp, #4
                        mov     lores_top, draw_tmp
                        mov     draw_tmp, draw_val
                        and     draw_tmp, #15
                        or      lores_top, draw_tmp  
                        and     lores_top, #254   
    'need to determine which 8x8 graphic tile(s) we need to update
    'x := x << 1 'x * 2
                        mov     draw_x, draw_xpos                       'copy xpos to x
                        shl     draw_x, #1                              'shift left one time to mult by 2

    'graphicx := byte[@FontToGraphicMap][x] 'graphic tile column
                        mov     char_t1, draw_graphmap_ptr
                        add     char_t1, draw_x  
                        rdbyte  char_graphicx, char_t1  
                 
    'offset := byte[@FontToGraphicMap][x + 1] 'offset for our font tile
                        add     char_t1, #1
                        rdbyte  char_offset, char_t1
                        
    'ptr := @pixel_bfr + (graphicx + (Y * WIDTH))
                        mov     draw_ptr0, #0                           '0 out pointer
draw_lores1             test    draw_ypos, #255  wz                     'mult cursory * width

                         
                        
              if_nz     sub     draw_ypos, #1               
              if_nz     add     draw_ptr0, #WIDTH
              if_nz     jmp     #draw_lores1

                        
                        'new routine using lut to replace multiply
                        'rdlong would be more efficient here, but 
                        'there was a problem reading bytes since they weren't
                        'long aligned...
                        'mov     char_t1, draw_ymulwidth_ptr
                        'shl     draw_ypos, #1
                        'add     char_t1, draw_ypos  
                        'rdbyte  draw_ptr0, char_t1 
                        'add     char_t1, #1
                        'shl     draw_ptr0, #8
                        'rdbyte  char_t2, char_t1 
                        'or      draw_ptr0, char_t2
                        
                        'start debug
                        'mov     debug_ptr, draw_ypos
                        'wrlong  debug_ptr, debug_val_ptr
                        'jmp     #draw_start  
                        'end debug
                        
                        add     draw_ptr0, char_graphicx                'add graphicx
                        add     draw_ptr0, par                          'add @pixel_bfr
    'ptr2 := ptr + 1 '@pixel_bfr + ((graphicx + 1) + (cursory * WIDTH))
                        mov     draw_ptr2, draw_ptr0
                        add     draw_ptr2, #1
                        
'    repeat idx from 0 to 7 'y
                        mov     draw_cntr, #8
                        mov     char_offset2, char_offset
                        add     char_offset2, #1                        
    '    if idx < 4
    '        tmp := top
    '    else
    '        tmp := bottom
draw_lores3             
                        cmp     draw_cntr, #5  wc
              if_nc     mov     draw_xpos, lores_top
              if_c      mov     draw_xpos, lores_bottom
              
                        tjnz    char_offset, #draw_lores4    
                        'if offset is zero fall through to below code
'        else 'font tile is encapsulated in one graphic tile
'            byte[ptr] &= $FF << 7 'mask to clear offset bits
'            byte[ptr] |= (tmp) >> (offset + 1)

                        mov     char_t1, #255
                        shl     char_t1, #7

                        rdbyte  char_ptr0, draw_ptr0
                        and     char_ptr0, char_t1
                        
                        shr     draw_xpos, char_offset2
                        
                        or      char_ptr0, draw_xpos
                        wrbyte  char_ptr0, draw_ptr0                       
                        jmp     #draw_lores5
                        
'       if offset > 0 '7x8 font tile will take up 2 graphic tiles                  

'            byte[ptr] &= !($FF << (8 - offset)) 'mask to clear offset bits
'            byte[ptr] |= (tmp) << (7 - offset) 'write left part of char
draw_lores4             mov     char_t1, #8
                        sub     char_t1, char_offset
                        mov     char_t2, #255
                        shl     char_t2, char_t1
                        rdbyte  char_ptr0, draw_ptr0
                        andn    char_ptr0, char_t2
                        
                        mov     char_t2, draw_xpos 'make copy of draw_xpos so we can use it later
                        mov     char_t1, #7
                        sub     char_t1, char_offset
                        
                        shl     draw_xpos, char_t1
                        
                        or      char_ptr0, draw_xpos
                        wrbyte  char_ptr0, draw_ptr0 
                         
'            byte[ptr2] &= !($FF >> (offset + 1)) 'mask
'            byte[ptr2] |= (tmp) >> (offset + 1)'right part of char
                        mov     char_t1, #255
                        shr     char_t1, char_offset2
                        rdbyte  char_ptr0, draw_ptr2
                        andn    char_ptr0, char_t1
                                
                        xor     char_t2, draw_reverse
                        shr     char_t2, char_offset2
                        
                        or      char_ptr0, char_t2
                        wrbyte  char_ptr0, draw_ptr2   
'            ptr2 += COLS 
                        add     draw_ptr2, #COLS


'        ptr += COLS 'increment ptr to go to next y coord of graphic tile
draw_lores5             add     draw_ptr0, #COLS     
                        
                        djnz    draw_cntr, #draw_lores3
                        jmp     #draw_start          


'---- Draw HiRes screen--------------------------------------------------------------------------
draw_hires 
                        mov     ram_address, ram_address_test
                        call    #read_byte 
                        
                        'start debug
                        'mov     debug_ptr, ram_read
                        'wrlong  debug_ptr, debug_val_ptr
                        'jmp     #draw_start  
                        'end debug
                        
                        
                        mov     draw_row, #0
'            repeat mem_section from 1 to 3 '3 sections
                        mov     draw_cntr, #3  
hires_section  
'                mem_box := 0     
                        mov     draw_mem_box, #0
'                repeat 8 '8 box rows per section                             
                        mov     draw_cntr2, #8  
hires_boxrow                     
'                    mem_row := 0
                        mov     draw_mem_row, #0   
'                    repeat 8 '8 rows within box row
                        mov     draw_cntr3, #8   
hires_row
'                        mem_loc := mem_page_start + mem_start + mem_box + mem_row
'                        col := 0 '1'moving column a little to the right to center within frame
                        mov     draw_col, #0
'                        repeat 40 '40 columns/bytes per row
                        mov     draw_cntr4, #40
hires_col
'                            data := read_byte(mem_loc)
'                            'the msb is ignored since it's the color grouping bit
'                            'the other bits are displayed opposite to where they appear
'                            'ie the lsb bit appears on the left and each subsequent bit moves to the right.
'                            'read Apple II Computer Graphics page 70ish for more details.
'                            R2.Pixel (data, col, row)     
                        'mov     draw_val, #255 'test data for now
                        
                        'call routine to get data byte from ram. routine will write data to draw_val
                        
                        mov     draw_xpos, draw_col
                        mov     draw_ypos, draw_row
                        call    #draw_pixel_sub                                                                           
'                            col++
                        add     draw_col, #1    
'                            mem_loc++
                        djnz    draw_cntr4, #hires_col
'                        row++
                        add     draw_row, #1
'                        mem_row += $400
                        djnz    draw_cntr3, #hires_row
'                    mem_box += $80
                        djnz    draw_cntr2, #hires_boxrow
'                mem_start += $28                       
                        djnz    draw_cntr, #hires_section
                        
                        jmp     draw_hires
'---- Draw a line -------------------------------------------------------------------------------
'draw_line
'  dy := y2 - y1
 '                       mov     draw_dy, draw_ypos
 '                       sub     draw_dy, draw_lasty
'
'  dx := x2 - x1
'                        mov     draw_dx, draw_xpos
'                        sub     draw_dx, draw_lastx  wc
'
'  if dx >= 0
'              if_nc     mov     draw_x1, draw_lastx
'              if_nc     mov     draw_x2, draw_xpos
'              if_nc     mov     draw_y1, draw_lasty
'              if_nc     mov     draw_y2, draw_ypos
'
'  else dx < 0
'              if_c      mov     draw_x1, draw_xpos
'              if_c      mov     draw_x2, draw_lastx
'              if_c      mov     draw_y1, draw_ypos
'              if_c      mov     draw_y2, draw_lasty
'              if_c      neg     draw_dx, draw_dx
'              if_c      neg     draw_dy, draw_dy
'
'  lastx := xpos
'  lasty := ypos
'                        mov     draw_lastx, draw_xpos
'                        mov     draw_lasty, draw_ypos
'
'  d1 := 1
'  if dy < 0
'    d1 := -1
'    dy := -dy
'                        mov     draw_d1, #1
'                        neg     draw_dy, draw_dy  wc, nr
'              if_c      neg     draw_d1, draw_d1
'              if_c      neg     draw_dy, draw_dy

'  a := b := 0

'  if dx > dy df := 1
'  else       df := -1
'                        cmp     draw_dy, draw_dx  wc
'              if_c      mov     draw_df, #1
'              if_nc     neg     draw_df, #1

'  repeat
'draw_line1
'    Pixel(c, x1, y1)
'                        mov     draw_xpos, draw_x1
'                        mov     draw_ypos, draw_y1
'                        call    #draw_pixel_sub

'    if df < 0
'      y1 += d1
'      df += dx
'                        neg     draw_df, draw_df  wc, nr
'              if_c      add     draw_y1, draw_d1
'              if_c      add     draw_df, draw_dx

'    else df >= 0
'      x1 += 1
'      df -= dy
'              if_nc     add     draw_x1, #1
'              if_nc     sub     draw_df, draw_dy

'  until (x1 >= x2) and (y1 == y2)
'                        cmp     draw_x2, draw_x1  wz
'        if_nz_and_nc    jmp     #draw_line1
'                        cmp     draw_y1, draw_y2  wz
'        if_nz           jmp     #draw_line1

'draw_line2
'  Pixel(c, x1 + a, y1 + b)
'                        mov     draw_xpos, draw_x1
'                        mov     draw_ypos, draw_y1
'                        call    #draw_pixel_sub
'                        jmp     #draw_start

'reads a byte from RAM------------------------------------------------------------------
'ram_address should have the address you want to read from
'will place byte read into var ram_read
read_byte

'   'to read:   
'    lsb := address 
                        mov     ram_lsb, ram_address
'    msb := address >> 8
                        shr     ram_address, #8
                        mov     ram_msb, ram_address
                        
                        
'    'set we pin high
'    outa[WE]~~
                        or      outa, ram_we_mask 
'    'set data pins as input
'    dira[D0..D7]~
                        andn    dira,#255
'    'set address pins
'    outa[A7..A0] := lsb
                        andn    outa, ram_lsb_mask   'clear first
                        or      outa, ram_lsb 
'    outa[A14..A8] := msb
                        andn    outa, ram_msb_mask   'clear first
                        or      outa, ram_msb 
'    outa[A15] := msb >> 7
                        shr     ram_msb, #7
                        andn    outa, ram_a15_mask   'clear first
                        or      outa, ram_msb 
'    'wait specified time
                        
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        
'    'read data pins
'    data_in := ina[D7..D0]
                        mov     draw_tmp, ina
                        'start debug
                        mov     debug_ptr, ina
                        wrlong  debug_ptr, debug_val_ptr
                        jmp     #draw_start  
                        'end debug
                        and     draw_tmp, #255        
                        mov     ram_read, draw_tmp     
'    outa[A0..A7] := %00000000 'low
                        andn    outa, ram_lsb_mask
'    outa[A8..A14] := %0000000 'low
                        andn    outa, ram_msb_mask
'    outa[A15]~ 'low                          
                        andn    outa, ram_a15_mask
'    return data_in                       
                        'mov     ram_read, #127
read_byte_ret           ret  'return to caller


draw_cmnd_ptr           long    0
draw_map_ptr            long    0
draw_graphmap_ptr       long    0
draw_ymulwidth_ptr      long    0
draw_reverse_ptr        long    0
draw_lastx              long    0
draw_lasty              long    0
debug_ptr               long    0
debug_val_ptr           long    0
pixel_mask              long    $FF_00_00_80
pixel_mask2             long    0
ram_we_mask             long    $40_00_00_00
ram_lsb_mask            long    $00_00_FF_00
ram_msb_mask            long    $0F_E0_00_00
ram_a15_mask            long    $80_00_00_00
ram_address_test        long    $00_00

ram_read                res     1
ram_address             res     1
ram_lsb                 res     1
ram_msb                 res     1
draw_mem_box            res     1
draw_mem_row            res     1
draw_col                res     1
draw_row                res     1
draw_cmnd               res     1
draw_val                res     1
draw_val2               res     1
draw_tmp                res     1
draw_tmp2               res     1
draw_xpos               res     1
draw_ypos               res     1
draw_x                  res     1
draw_ptr0               res     1
draw_ptr1               res     1
draw_ptr2               res     1
draw_cntr               res     1
draw_cntr2              res     1
draw_cntr3              res     1
draw_cntr4              res     1
draw_reverse            res     1
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
char_graphicx           res     1
char_offset             res     1
char_offset2            res     1
char_t1                 res     1
char_t2                 res     1
char_ptr0               res     1
lores_bottom            res     1
lores_top               res     1
                        fit

DAT

'------------------------------------------------------------------------------------------------
'LUT to map multiplication table for char (y * width)
'------------------------------------------------------------------------------------------------
'max y is 30 (height/8) = (240/8) = 30.
'width is 288
YMulWidth
                        byte    $00, $00      '0 (0)
                        byte    $01, $20      '1 (288)
                        byte    $02, $40      '2 (576)
                        byte    $03, $60      '3 (864)
                        byte    $04, $80      '4 (1152)
                        byte    $05, $A0      '5 (1440)
                        byte    $06, $C0      '6 (1728)
                        byte    $07, $E0      '7 (2016)
                        byte    $09, $00      '8 (2304)
                        byte    $0A, $20      '9 (2592)
                        byte    $0B, $40      '10(2880)
                        byte    $0C, $60      '11(3168)
                        byte    $0D, $80      '12(3456)
                        byte    $0E, $A0      '13(3744)
                        byte    $0F, $C0      '14(4032)
                        byte    $10, $E0      '15(4320)
                        byte    $12, $00      '16(4608)
                        BYTE    $13, $20      '17(4896)
                        BYTE    $14, $40      '18(5184)
                        BYTE    $15, $60      '19(5472)
                        BYTE    $16, $80      '20(5760)
                        BYTE    $17, $A0      '21(6048)
                        BYTE    $18, $C0      '22(6336)
                        BYTE    $19, $E0      '23(6624)
                        BYTE    $1B, $00      '24(6912)
                        BYTE    $1C, $20      '25(7200)
                        BYTE    $1D, $40      '26(7488)
                        BYTE    $1E, $60      '27(7776)
                        BYTE    $1F, $80      '28(8064)
                        BYTE    $20, $A0      '29(8352)
                                            
'------------------------------------------------------------------------------------------------
' LUT To map between 7x8 font tiles and 8x8 graphic tiles ((xpos x 7) / 8)
'------------------------------------------------------------------------------------------------
'                      GRAPH COL, OFFSET
FontToGraphicMap
                       byte     $00, $00   'col 0
                       byte     $00, $01   'col 1
                       byte     $01, $02   'col 2
                       byte     $02, $03   'col 3
                       byte     $03, $04   'col 4
                       byte     $04, $05   'col 5
                       byte     $05, $06   'col 6
                       byte     $06, $07   'col 7
                       byte     $07, $00   'col 8
                       byte     $07, $01   'col 9
                       byte     $08, $02   'col 10
                       byte     $09, $03   'col 11
                       byte     $0A, $04   'col 12
                       byte     $0B, $05   'col 13
                       byte     $0C, $06   'col 14
                       byte     $0D, $07   'col 15
                       byte     $0E, $00   'col 16
                       byte     $0E, $01   'col 17
                       byte     $0F, $02   'col 18
                       byte     $10, $03   'col 19
                       byte     $11, $04   'col 20
                       byte     $12, $05   'col 21
                       byte     $13, $06   'col 22
                       byte     $14, $07   'col 23
                       byte     $15, $00   'col 24
                       byte     $15, $01   'col 25
                       byte     $16, $02   'col 26
                       byte     $17, $03   'col 27
                       byte     $18, $04   'col 28
                       byte     $19, $05   'col 29
                       byte     $1A, $06   'col 30
                       byte     $1B, $07   'col 31
                       byte     $1C, $00   'col 32
                       byte     $1C, $01   'col 33
                       byte     $1D, $02   'col 34
                       byte     $1E, $03   'col 35
                       byte     $1F, $04   'col 36
                       byte     $20, $05   'col 37
                       byte     $21, $06   'col 38
                       byte     $22, $07   'col 39
                       byte     $23, $00   'col 40                        
                       byte     $23, $01   'col 41                         
                                                
                                                                                                                                                    
'------------------------------------------------------------------------------------------------
' C64 Character Map
'------------------------------------------------------------------------------------------------
C64CharMap
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 32 Space 
			byte	$00, $10, $10, $10, $10, $10, $00, $10 ' 33 ! 
			byte	$00, $28, $28, $28, $00, $00, $00, $00 ' 34 " 
			byte	$00, $28, $28, $7C, $28, $7C, $28, $28 ' 35 # 
			byte	$00, $10, $78, $14, $38, $50, $3C, $10 ' 36 $ 
			byte	$00, $0C, $4C, $20, $10, $08, $64, $60 ' 37 % 
			byte	$00, $08, $14, $14, $08, $54, $24, $58 ' 38 & 
			byte	$00, $10, $10, $10, $00, $00, $00, $00 ' 39 ' 
			byte	$00, $20, $10, $08, $08, $08, $10, $20 ' 40 ( 
			byte	$00, $08, $10, $20, $20, $20, $10, $08 ' 41 ) 
			byte	$00, $10, $54, $38, $10, $38, $54, $10 ' 42 * 
			byte	$00, $00, $10, $10, $7C, $10, $10, $00 ' 43 + 
			byte	$00, $00, $00, $00, $00, $10, $10, $08 ' 44 , 
			byte	$00, $00, $00, $00, $7C, $00, $00, $00 ' 45 - 
			byte	$00, $00, $00, $00, $00, $00, $10, $00 ' 46 . 
			byte	$00, $00, $40, $20, $10, $08, $04, $00 ' 47 / 
			byte	$00, $38, $44, $64, $54, $4C, $44, $38 ' 48 0 
			byte	$00, $10, $18, $10, $10, $10, $10, $38 ' 49 1 
			byte	$00, $38, $44, $40, $30, $08, $04, $7C ' 50 2 
			byte	$00, $7C, $40, $20, $30, $40, $44, $38 ' 51 3 
			byte	$00, $20, $30, $28, $24, $7C, $20, $20 ' 52 4 
			byte	$00, $7C, $04, $3C, $40, $40, $44, $38 ' 53 5 
			byte	$00, $70, $08, $04, $3C, $44, $44, $38 ' 54 6 
			byte	$00, $7C, $40, $20, $10, $08, $08, $08 ' 55 7 
			byte	$00, $38, $44, $44, $38, $44, $44, $38 ' 56 8 
			byte	$00, $38, $44, $44, $78, $40, $20, $1C ' 57 9 
			byte	$00, $00, $00, $10, $00, $10, $00, $00 ' 58 : 
			byte	$00, $00, $00, $10, $00, $10, $10, $08 ' 59 ; 
			byte	$00, $40, $20, $10, $08, $10, $20, $40 ' 60 < 
			byte	$00, $00, $00, $7C, $00, $7C, $00, $00 ' 61 = 
			byte	$00, $04, $08, $10, $20, $10, $08, $04 ' 62 > 
			byte	$00, $38, $44, $20, $10, $10, $00, $10 ' 63 ? 
			byte	$00, $38, $44, $54, $74, $34, $04, $78 ' 64 @ 
			byte	$00, $10, $28, $44, $44, $7C, $44, $44 ' 65 A 
			byte	$00, $3C, $44, $44, $3C, $44, $44, $3C ' 66 B 
			byte	$00, $38, $44, $04, $04, $04, $44, $38 ' 67 C 
			byte	$00, $3C, $44, $44, $44, $44, $44, $3C ' 68 D 
			byte	$00, $7C, $04, $04, $3C, $04, $04, $7C ' 69 E 
			byte	$00, $7C, $04, $04, $3C, $04, $04, $04 ' 70 F 
			byte	$00, $78, $04, $04, $04, $64, $44, $78 ' 71 G 
			byte	$00, $44, $44, $44, $7C, $44, $44, $44 ' 72 H 
			byte	$00, $38, $10, $10, $10, $10, $10, $38 ' 73 I 
			byte	$00, $40, $40, $40, $40, $40, $44, $38 ' 74 J 
			byte	$00, $44, $24, $14, $0C, $14, $24, $44 ' 75 K 
			byte	$00, $04, $04, $04, $04, $04, $04, $7C ' 76 L 
			byte	$00, $44, $6C, $54, $54, $44, $44, $44 ' 77 M 
			byte	$00, $44, $44, $4C, $54, $64, $44, $44 ' 78 N 
			byte	$00, $38, $44, $44, $44, $44, $44, $38 ' 79 O 
			byte	$00, $3C, $44, $44, $3C, $04, $04, $04 ' 80 P 
			byte	$00, $38, $44, $44, $44, $54, $24, $58 ' 81 Q 
			byte	$00, $3C, $44, $44, $3C, $14, $24, $44 ' 82 R 
			byte	$00, $38, $44, $04, $38, $40, $44, $38 ' 83 S 
			byte	$00, $7C, $10, $10, $10, $10, $10, $10 ' 84 T 
			byte	$00, $44, $44, $44, $44, $44, $44, $38 ' 85 U 
			byte	$00, $44, $44, $44, $44, $44, $28, $10 ' 86 V 
			byte	$00, $44, $44, $44, $54, $54, $6C, $44 ' 87 W 
			byte	$00, $44, $44, $28, $10, $28, $44, $44 ' 88 X 
			byte	$00, $44, $44, $28, $10, $10, $10, $10 ' 89 Y 
			byte	$00, $7C, $40, $20, $10, $08, $04, $7C ' 90 Z 
			byte	$00, $7C, $0C, $0C, $0C, $0C, $0C, $7C ' 91 [ 
			byte	$00, $00, $04, $08, $10, $20, $40, $00 ' 92 \ 
			byte	$00, $7C, $60, $60, $60, $60, $60, $7C ' 93 ] 
			byte	$00, $10, $28, $44, $00, $00, $00, $00 ' 94 ^ 
			byte	$00, $00, $00, $00, $00, $00, $00, $FE ' 95 _ 
			byte	$00, $08, $10, $20, $00, $00, $00, $00 ' 96 ` 
			byte	$00, $00, $3C, $60, $7C, $66, $7C, $00 ' 97 a 
			byte	$00, $06, $06, $3E, $66, $66, $3E, $00 ' 98 b 
			byte	$00, $00, $3C, $06, $06, $06, $3C, $00 ' 99 c 
			byte	$00, $60, $60, $7C, $66, $66, $7C, $00 ' 100 d 
			byte	$00, $00, $3C, $66, $7E, $06, $3C, $00 ' 101 e 
			byte	$00, $70, $18, $7C, $18, $18, $18, $00 ' 102 f 
			byte	$00, $00, $7C, $66, $66, $7C, $60, $3E ' 103 g 
			byte	$00, $06, $06, $3E, $66, $66, $66, $00 ' 104 h 
			byte	$00, $18, $00, $1C, $18, $18, $3C, $00 ' 105 i 
			byte	$00, $60, $00, $60, $60, $60, $60, $3C ' 106 j 
			byte	$00, $06, $06, $36, $1E, $36, $66, $00 ' 107 k 
			byte	$00, $1C, $18, $18, $18, $18, $3C, $00 ' 108 l 
			byte	$00, $00, $66, $FE, $FE, $D6, $C6, $00 ' 109 m 
			byte	$00, $00, $3E, $66, $66, $66, $66, $00 ' 110 n 
			byte	$00, $00, $3C, $66, $66, $66, $3C, $00 ' 111 o 
			byte	$00, $00, $3E, $66, $66, $3E, $06, $06 ' 112 p 
			byte	$00, $00, $7C, $66, $66, $7C, $60, $60 ' 113 q 
			byte	$00, $00, $3E, $66, $06, $06, $06, $00 ' 114 r 
			byte	$00, $00, $7C, $06, $3C, $60, $3E, $00 ' 115 s 
			byte	$00, $18, $7E, $18, $18, $18, $70, $00 ' 116 t 
			byte	$00, $00, $66, $66, $66, $66, $7C, $00 ' 117 u 
			byte	$00, $00, $66, $66, $66, $3C, $18, $00 ' 118 v 
			byte	$00, $00, $C6, $D6, $FE, $7C, $6C, $00 ' 119 w 
			byte	$00, $00, $66, $3C, $18, $3C, $66, $00 ' 120 x 
			byte	$00, $00, $66, $66, $66, $7C, $30, $1E ' 121 y 
			byte	$00, $00, $7E, $30, $18, $0C, $7E, $00 ' 122 z 
			byte	$00, $70, $18, $18, $0C, $18, $18, $70 ' 123 { 
			byte	$10, $10, $10, $10, $10, $10, $10, $10 ' 124 | 
			byte	$00, $1C, $30, $30, $60, $30, $30, $1C ' 125 } 
			byte	$00, $58, $34, $00, $00, $00, $00, $00 ' 126 ~ 
			byte	$00, $08, $0C, $FE, $FE, $0C, $08, $00 ' 127 Left Arrow 
			byte	$30, $48, $0C, $3E, $0C, $46, $3F, $00 ' 128 British Pound 
			byte	$00, $18, $3C, $7E, $18, $18, $18, $18 ' 129 Up Arrow 
			byte	$00, $08, $0C, $FE, $FE, $0C, $08, $00 ' 130 Left Arrow 
			byte	$55, $AA, $55, $AA, $55, $AA, $55, $AA ' 131 Checker Board 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 132 
			byte	$00, $00, $4E, $62, $46, $42, $E2, $00 ' 133 F1 
			byte	$00, $00, $EE, $82, $C6, $82, $E2, $00 ' 134 F3 
			byte	$00, $00, $EE, $22, $66, $82, $62, $00 ' 135 F5 
			byte	$00, $00, $EE, $82, $86, $42, $42, $00 ' 136 F7 
			byte	$00, $00, $6E, $82, $66, $22, $E2, $00 ' 137 F2 
			byte	$00, $00, $4E, $62, $F6, $42, $42, $00 ' 138 F4 
			byte	$00, $00, $CE, $22, $E6, $A2, $E2, $00 ' 139 F6 
			byte	$00, $00, $EE, $A2, $E6, $A2, $E2, $00 ' 140 F8 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 141 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 142 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 143 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 144 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 145 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 146 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 147 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 148 
			byte	$00, $00, $00, $E0, $F0, $38, $18, $18 ' 149 
			byte	$C3, $E7, $7E, $3C, $3C, $7E, $E7, $C3 ' 150 
			byte	$00, $3C, $7E, $66, $66, $7E, $3C, $00 ' 151 
			byte	$18, $18, $66, $66, $18, $18, $3C, $00 ' 152 Club 
			byte	$60, $60, $60, $60, $60, $60, $60, $60 ' 153 
			byte	$10, $38, $7C, $FE, $7C, $38, $10, $00 ' 154 Diamond 
			byte	$18, $18, $18, $FF, $FF, $18, $18, $18 ' 155 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 156 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 157 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 158 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 159 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 160 
			byte	$0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F ' 161 
			byte	$00, $00, $00, $00, $FF, $FF, $FF, $FF ' 162 
			byte	$FF, $00, $00, $00, $00, $00, $00, $00 ' 163 
			byte	$00, $00, $00, $00, $00, $00, $00, $FF ' 164 
			byte	$01, $01, $01, $01, $01, $01, $01, $01 ' 165 
			byte	$33, $33, $CC, $CC, $33, $33, $CC, $CC ' 166 
			byte	$80, $80, $80, $80, $80, $80, $80, $80 ' 167 
			byte	$00, $00, $00, $00, $33, $33, $CC, $CC ' 168 
			byte	$FF, $7F, $3F, $1F, $0F, $07, $03, $01 ' 169 
			byte	$C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0 ' 170 
			byte	$18, $18, $18, $F8, $F8, $18, $18, $18 ' 171 
			byte	$00, $00, $00, $00, $F0, $F0, $F0, $F0 ' 172 
			byte	$18, $18, $18, $F8, $F8, $00, $00, $00 ' 173 
			byte	$00, $00, $00, $1F, $1F, $18, $18, $18 ' 174 
			byte	$00, $00, $00, $00, $00, $00, $FF, $FF ' 175 
			byte	$00, $00, $00, $F8, $F8, $18, $18, $18 ' 176 
			byte	$18, $18, $18, $FF, $FF, $00, $00, $00 ' 177 
			byte	$00, $00, $00, $FF, $FF, $18, $18, $18 ' 178 
			byte	$18, $18, $18, $1F, $1F, $18, $18, $18 ' 179 
			byte	$03, $03, $03, $03, $03, $03, $03, $03 ' 180 
			byte	$07, $07, $07, $07, $07, $07, $07, $07 ' 181 
			byte	$E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0 ' 182 
			byte	$FF, $FF, $00, $00, $00, $00, $00, $00 ' 183 
			byte	$FF, $FF, $FF, $00, $00, $00, $00, $00 ' 184 
			byte	$00, $00, $00, $00, $00, $FF, $FF, $FF ' 185 
			byte	$C0, $C0, $C0, $C0, $C0, $C0, $FF, $FF ' 186 
			byte	$00, $00, $00, $00, $0F, $0F, $0F, $0F ' 187 
			byte	$F0, $F0, $F0, $F0, $00, $00, $00, $00 ' 188 
			byte	$18, $18, $18, $1F, $1F, $00, $00, $00 ' 189 
			byte	$0F, $0F, $0F, $0F, $00, $00, $00, $00 ' 190 
			byte	$0F, $0F, $0F, $0F, $F0, $F0, $F0, $F0 ' 191 
			byte	$00, $00, $00, $FF, $FF, $00, $00, $00 ' 192 
			byte	$10, $38, $7C, $FE, $FE, $38, $7C, $00 ' 193 Spade 
			byte	$18, $18, $18, $18, $18, $18, $18, $18 ' 194 
			byte	$00, $00, $00, $FF, $FF, $00, $00, $00 ' 195 
			byte	$00, $00, $FF, $FF, $00, $00, $00, $00 ' 196 
			byte	$00, $FF, $FF, $00, $00, $00, $00, $00 ' 197 
			byte	$00, $00, $00, $00, $FF, $FF, $00, $00 ' 198 
			byte	$0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C ' 199 
			byte	$30, $30, $30, $30, $30, $30, $30, $30 ' 200 
			byte	$00, $00, $00, $07, $0F, $1C, $18, $18 ' 201 
			byte	$18, $18, $38, $F0, $E0, $00, $00, $00 ' 202 
			byte	$18, $18, $1C, $0F, $07, $00, $00, $00 ' 203 
			byte	$03, $03, $03, $03, $03, $03, $FF, $FF ' 204 
			byte	$03, $07, $0E, $1C, $38, $70, $E0, $C0 ' 205 
			byte	$C0, $E0, $70, $38, $1C, $0E, $07, $03 ' 206 
			byte	$FF, $FF, $03, $03, $03, $03, $03, $03 ' 207 
			byte	$FF, $FF, $C0, $C0, $C0, $C0, $C0, $C0 ' 208 
			byte	$00, $3C, $7E, $7E, $7E, $7E, $3C, $00 ' 209 
			byte	$00, $00, $00, $00, $00, $FF, $FF, $00 ' 210 
			byte	$6C, $FE, $FE, $FE, $7C, $38, $10, $00 ' 211 Heart 
			byte	$06, $06, $06, $06, $06, $06, $06, $06 ' 212 
			byte	$00, $00, $00, $E0, $F0, $38, $18, $18 ' 213 
			byte	$C3, $E7, $7E, $3C, $3C, $7E, $E7, $C3 ' 214 
			byte	$00, $3C, $7E, $66, $66, $7E, $3C, $00 ' 215 
			byte	$18, $18, $66, $66, $18, $18, $3C, $00 ' 216 Club 
			byte	$60, $60, $60, $60, $60, $60, $60, $60 ' 217 
			byte	$10, $38, $7C, $FE, $7C, $38, $10, $00 ' 218 Diamond 
			byte	$00, $7C, $7C, $7C, $7C, $7C, $7C, $7C ' 219 
			byte	$03, $03, $0C, $0C, $03, $03, $0C, $0C ' 220 
			byte	$18, $18, $18, $18, $18, $18, $18, $18 ' 221 
			byte	$00, $00, $C0, $7C, $6E, $6C, $6C, $00 ' 222 PI 
			byte	$FF, $FE, $FC, $F8, $F0, $E0, $C0, $80 ' 223 
			byte	$FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE ' 224 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 225 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 226 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 227 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 228 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 229 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 230 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 231 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 232 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 233 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 234 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 235 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 236 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 237 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 238 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 239 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 240 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 241 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 242 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 243 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 244 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 245 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 246 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 247 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 248 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 249 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 250 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 251 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 252 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 253 
			byte	$00, $00, $00, $00, $00, $00, $00, $00 ' 254 
			byte	$3C, $42, $A5, $81, $A5, $99, $42, $3C ' 255 Smiley 




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