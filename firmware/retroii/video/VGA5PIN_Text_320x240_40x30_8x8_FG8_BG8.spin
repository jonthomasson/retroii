''******************************************************
''* VGA5PIN_Text_320x240_40x30_8x8_FG8-BG8.spin 2/2017 *
''* Author: Werner L. Schneider                        *
''* 256 Chars, 8x8 Pixel.                              *
''******************************************************
''
''
'' Based on VGA_HiRes Text Driver from Chip Gracey
''
''
CON

' 320 x 240 : 40 x 30 characters signaled as 640 x 480 

    hp = 640        ' horizontal pixels
    vp = 480        ' vertical pixels
    hf = 24         ' horizontal front porch pixels
    hs = 40         ' horizontal sync pixels
    hb = 128        ' horizontal back porch pixels
    vf = 20         ' vertical front porch lines
    vs = 3          ' vertical sync lines
    vb = 17         ' vertical back porch lines
    hn = 1          ' horizontal normal sync state (0|1)
    vn = 1          ' vertical normal sync state (0|1)
    pr = 30         ' pixel rate in MHz at 80MHz system clock (5MHz granularity)

' columns and rows

    cols = hp / 16  ' 40 cols
    rows = vp / 16  ' 30 rows
    xpix = 320
    ypix = 240
    fsize = 8


VAR long cog[2]


PUB start(BasePin, ScreenPtr, CursorPtr, SyncPtr) : okay | i, j

'' Start VGA driver - starts two COGs
'' returns false if two COGs not available
''
''      BasePin = VGA starting pin (0, 8, 16, 24, etc.)
''
''      ScreenPtr = Pointer to 40x30 words containing Latin-1 codes and colors for
''              each of the 40x30 screen characters. The lower byte of the word
''              contains the Latin-1 code to display. The upper byte contains
''              the foreground colour in bits 10..8 and the background colour in
''              bits 14..12.
''
''              screen word example: %00110111_01000001 = "A", white on blue
''
''
''      CursorPtr = Pointer to 6 bytes which control the cursors:
''
''              bytes 0,1,2: X, Y, and MODE of cursor 0
''              bytes 3,4,5: X, Y, and MODE of cursor 1
''
''              X and Y are in terms of screen characters
''              (left-to-right, top-to-bottom)
''
''              MODE uses three bottom bits:
''
''                      %x00 = cursor off
''                      %x01 = cursor on
''                      %x10 = cursor on, blink slow
''                      %x11 = cursor on, blink fast
''                      %0xx = cursor is solid block
''                      %1xx = cursor is underscore
''
''              cursor example: 0, 0, %010 = blinking block in upper-left
''
''
''      SyncPtr = Pointer to long which gets written with -1 upon each screen
''              refresh. May be used to time writes/scrolls, so that chopiness
''              can be avoided. You must clear it each time if you want to see
''              it re-trigger.

    ' if driver is already running, stop it
    stop

    ' implant pin settings
    reg_vcfg := $2000001F + (BasePin & %111000) << 6
    i := $1F << (BasePin & %011000)
    j := BasePin & %100000 == 0
    reg_dira := i & j
    reg_dirb := i & !j

    ' implant CNT value to sync COGs to
    sync_cnt := cnt + $10000

    ' implant pointers
    longmove(@screen_base, @ScreenPtr, 2)
    font_base := @font

    ' implant unique settings and launch first COG
    vf_lines.byte := vf
    vb_lines.byte := vb
    font_part := 2
    cog[1] := cognew(@d0, SyncPtr) + 1

    ' allow time for first COG to launch
    waitcnt($2000 + cnt)

    ' differentiate settings and launch second COG
    vf_lines.byte := vf+4
    vb_lines.byte := vb-4
    font_part := 0
    cog[0] := cognew(@d0, SyncPtr) + 1

    ' if both COGs launched, return true
    if cog[0] and cog[1]
        return true
    ' else, stop any launched COG and return false
    stop


PUB stop | i

'' Stop VGA driver - frees two COGs

    repeat i from 0 to 1
        if cog[i]
            cogstop(cog[i]~ - 1)

PUB getFontPtr

    return @font

CON

    #1, scanbuff[80], colorbuff[80], scancode[2*80-1+3], maincode   'enumerate COG RAM usage

    main_size = $1F0 - maincode                             'size of main program

    hv_inactive = (hn << 1 + vn) * $0101                    'H,V inactive states


DAT

'*****************************************************
'* Assembly language VGA high-resolution text driver *
'*****************************************************

' This program runs concurrently in two different COGs.
'
' Each COG's program has different values implanted for front-porch lines and
' back-porch lines which surround the vertical sync pulse lines. This allows
' timed interleaving of their active display signals during the visible portion
' of the field scan. Also, they are differentiated so that one COG displays
' even four-line groups while the other COG displays odd four-line groups.
'
' These COGs are launched in the PUB 'start' and are programmed to synchronize
' their PLL-driven video circuits so that they can alternately prepare sets of
' four scan lines and then display them. The COG-to-COG switchover is seemless
' due to two things: exact synchronization of the two video circuits and the
' fact that all COGs' driven output states get OR'd together, allowing one COG
' to output lows during its preparatory state while the other COG effectively
' drives the pins to create the visible and sync portions of its scan lines.
' During non-visible scan lines, both COGs output together in unison.
'
' COG RAM usage:        $000    = d0 - used to inc destination fields for indirection
'                $001-$050 = scanbuff - longs which hold 4 scan lines
'                $051-$0a0 = colorbuff - longs which hold colors for 80 characters
'                $0a1-$142 = scancode - stacked WAITVID/SHR for fast display
'                $143-$1EF = maincode - main program loop which drives display

                        org     0                               ' set origin to $000 for start of program

d0                      long    1 << 9                          ' d0 always resides here at $000, executes as NOP


' Initialization code and data - after execution, space gets reused as scanbuff

                        ' Move main program into maincode area

:move                   mov     $1EF, main_begin + main_size - 1
                        sub     :move,d0s0                      ' (do reverse move to avoid overwrite)
                        djnz    main_ctr,#:move

                        ' Build scanbuff display routine into scancode

:waitvid                mov     scancode+0, i0                  ' org   scancode
:shr                    mov     scancode+1, i1                  ' waitvid colorbuff+0, scanbuff+0
                        add     :waitvid, d1                    ' shr   scanbuff+0,#8
                        add     :shr, d1                        ' waitvid colorbuff+1, scanbuff+1
                        add     i0, d0s0                        ' shr   scanbuff+1,#8
                        add     i1, d0                          ' ...
                        djnz    scan_ctr, #:waitvid             ' waitvid colorbuff+cols-1, scanbuff+cols-1

                        mov     scancode+cols*2-1, i2           ' mov   vscl,#hf
                        mov     scancode+cols*2+0, i3           ' waitvid hvsync,#0
                        mov     scancode+cols*2+1, i4           ' jmp   #scanret

                        ' Init I/O registers and sync COGs' video circuits

                        mov     dira, reg_dira                  ' set pin directions
                        mov     dirb, reg_dirb
                        movi    frqa, #(pr / 5) << 2            ' set pixel rate
                        mov     vcfg, reg_vcfg                  ' set video configuration
                        mov     vscl, #1                        ' set video to reload on every pixel
                        waitcnt sync_cnt, colormask             ' wait for start value in cnt, add ~1ms
                        movi    ctra, #%00001_110               ' COGs in sync! enable PLLs now - NCOs locked!
                        waitcnt sync_cnt, #0                    ' wait ~1ms for PLLs to stabilize - PLLs locked!
                        mov     vscl, #100                      ' insure initial WAITVIDs lock cleanly

                        ' Jump to main loop

                        jmp     #vsync                          ' jump to vsync - WAITVIDs will now be locked!

                        ' Data

d0s0                    long    1 << 9 + 1
d1                      long    1 << 10
main_ctr                long    main_size
scan_ctr                long    cols

i0                      waitvid colorbuff+0, scanbuff+0
i1                      shr     scanbuff+0, #8
i2                      mov     vscl, #hf
i3                      waitvid hvsync, #0
i4                      jmp     #scanret

reg_dira                long    0                               ' set at runtime
reg_dirb                long    0                               ' set at runtime
reg_vcfg                long    0                               ' set at runtime
sync_cnt                long    0                               ' set at runtime

                        ' Directives

                        fit     scancode                        ' make sure initialization code and data fit
main_begin              org     maincode                        ' main code follows (gets moved into maincode)


' Main loop, display field - each COG alternately builds and displays four scan lines

vsync                   mov     x, #vs                          ' do vertical sync lines
                        call    #blank_vsync

vb_lines                mov     x, #vb                          ' do vertical back porch lines (# set at runtime)
                        call    #blank_vsync

                        mov     screen_ptr, screen_base         ' reset screen pointer to upper-left character
                        mov     row, #0                         ' reset row counter for cursor insertion
                        mov     fours, #rows * 2  '16  '8 / 2            ' set number of 4-line builds for whole screen

                        ' Build four scan lines into scanbuff

fourline                mov     font_ptr, font_part             ' get address of appropriate font section
                        shl     font_ptr, #8 
                        add     font_ptr, font_base

                        movd    :pixa, #scanbuff-1              ' reset scanbuff address (pre-decremented)
                        movd    :cola, #colorbuff-1             ' reset colorbuff address (pre-decremented)
                        movd    :colb, #colorbuff-1

                        mov     vscl, vscl_line4x               ' ..pixel counter is limited to twelve bits

                        waitvid underscore, #0                  ' output lows to let other COG drive VGA pins
                        mov     x, #cols     '/2                      ' ..for 2 scan lines, ready for half a row

:column                 rdword  z, screen_ptr                   ' get character and colors from screen memory
                        mov     bg, z
                        and     z, #$ff                         ' mask character code
                        add     z, font_ptr                     ' add font section address to point to 8*4 pixels

                        add     :pixa, d0                       ' increment scanbuff destination addresses
                        add     screen_ptr, #2                  ' increment screen memory address

                        rdbyte  a, z                            ' read char font_part x
                        add     z, #256                          
                        rdbyte  c, z                            ' read char font_part x + 1

                        mov     b, a                     
                        shl     b, #8
                        add     b, a

                        mov     d, c                     
                        shl     d, #8
                        add     d, c
                        shl     d, #16
                        add     d, b

:pixa                   mov    scanbuff, d                      ' write pixel long (8*4) into scanbuff

                        and     bg, colmask                     ' mask bg and fg to 0-7
                        ror     bg, #12                         ' background color in bits 3..0
                        mov     fg, bg                          ' foreground color in bits 31..28
                        shr     fg, #28                         ' bits 3..0
                        add     fg, #fg_clut                    ' + offset to foreground CLUT
                        movs    :cola, fg
                        add     :cola, d0
                        add     bg, #bg_clut                    ' + offset to background CLUT
                        movs    :colb, bg
                        add     :colb, d0

:cola                   mov     colorbuff, 0-0
:colb                   or      colorbuff, 0-0

                        djnz    x, #:column                     ' another character in this half-row?

                        sub     screen_ptr, #2*cols             ' back up to start of same row in screen memory

                        ' Insert cursors into scanbuff

                        mov     z, #2                           ' ready for two cursors

:cursor                 rdbyte  x, cursor_base                  ' x in range?
                        add     cursor_base, #1
                        cmp     x, #cols        wc

                        rdbyte  y, cursor_base                  ' y match?
                        add     cursor_base, #1
                        cmp     y, row          wz

                        rdbyte  y, cursor_base                  ' get cursor mode
                        add     cursor_base, #1

        if_nc_or_nz     jmp     #:nocursor                      ' if cursor not in scanbuff, no cursor

                        add     x, #scanbuff                    ' cursor in scanbuff, set scanbuff address
                        movd    :xor, x

                        test    y, #%010        wc              ' get mode bits into flags
                        test    y, #%001        wz
        if_nc_and_z     jmp     #:nocursor                      ' if cursor disabled, no cursor

        if_c_and_z      test    slowbit, cnt    wc              ' if blink mode, get blink state
        if_c_and_nz     test    fastbit, cnt    wc

                        test    y, #%100        wz              ' get box or underscore cursor piece
        if_z            mov     x, longmask
        if_nz           mov     x, underline
        if_nz           cmp     font_part, #6   wz              ' if underscore, must be last font section

:xor    if_nc_and_z     xor     scanbuff, x                     ' conditionally xor cursor into scanbuff

:nocursor               djnz    z, #:cursor                     ' second cursor?

                        sub     cursor_base, #3*2               ' restore cursor base

                        ' Display four scan lines from scanbuff

                        mov     y, #4                           ' ready for four scan lines

scanline                mov     vscl, vscl_chr                  ' set pixel rate for characters
                        jmp     #scancode                       ' jump to scanbuff display routine in scancode
scanret                 mov    vscl, #hs                        ' do horizontal sync pixels
                        waitvid hvsync, #1                      ' #1 makes hsync active
                        mov     vscl, #hb                       ' do horizontal back porch pixels
                        waitvid hvsync, #0                      ' #0 makes hsync inactive
                        shr     scanbuff+cols-1, #8             ' shift last column's pixels right by 8
                        djnz    y, #scanline                    ' another scan line?

                        ' Next group of four scan lines

                        add     font_part, #4                   ' if font_part + 4 => 8, subtract 8 (new row)
                        cmpsub  font_part, #8           wc      ' c=0 for same row, c=1 for new row
        if_c            add     screen_ptr, #2*cols             ' if new row, advance screen pointer
        if_c            add     row, #1                         ' if new row, increment row counter
                        djnz    fours, #fourline                ' another 4-line build/display?

                        ' Visible section done, do vertical sync front porch lines

                        wrlong  longmask,par                    ' write -1 to refresh indicator

vf_lines                mov     x,#vf                           ' do vertical front porch lines (# set at runtime)
                        call    #blank

                        jmp     #vsync                          ' new field, loop to vsync

                        ' Subroutine - do blank lines

blank_vsync             xor     hvsync,#$101                    ' flip vertical sync bits

blank                   mov     vscl, hx                        ' do blank pixels
                        waitvid hvsync, #0
                        mov     vscl, #hf                       ' do horizontal front porch pixels
                        waitvid hvsync, #0
                        mov     vscl, #hs                       ' do horizontal sync pixels
                        waitvid hvsync, #1
                        mov     vscl, #hb                       ' do horizontal back porch pixels
                        waitvid hvsync, #0
                        djnz    x,#blank                        ' another line?
blank_ret
blank_vsync_ret
                        ret

                        ' Data

screen_base             long    0                               ' set at runtime (3 contiguous longs)
cursor_base             long    0                               ' set at runtime
font_base               long    0                               ' set at runtime

font_part               long    0                               ' set at runtime

hx                      long    hp                              ' visible pixels per scan line
vscl_line4x             long    (hp + hf + hs + hb) * 4         ' total number of pixels per 2 scan lines

vscl_chr                long    2 << 12 + 16                    ' 2 clock per pixel and 16 pixels per set

colormask               long    $FCFC                           ' mask to isolate R,G,B bits from H,V
longmask                long    $FFFFFFFF                       ' all bits set
slowbit                 long    1 << 25                         ' cnt mask for slow cursor blink
fastbit                 long    1 << 24                         ' cnt mask for fast cursor blink

underscore              long    $FFFF0000                       ' underscore cursor pattern

underline               long    $FFFF0000                       ' underline pattern

hv                      long    hv_inactive                     ' -H,-V states
hvsync                  long    hv_inactive ^ $200              ' +/-H,-V states


colmask                 long    $7700                           ' mask bg and fg to 0-7

bg_clut                 long    %00000011_00000011              ' black           0
                        long    %00000011_00010011              ' red             1
                        long    %00000011_00001011              ' green           2
                        long    %00000011_00000111              ' blue            3
                        long    %00000011_00011011              ' yellow          4
                        long    %00000011_00010111              ' magenta         5
                        long    %00000011_00001111              ' cyan            6
                        long    %00000011_00011111              ' white           7


fg_clut                 long    %00000011_00000011              ' black           
                        long    %00010011_00000011              ' red
                        long    %00001011_00000011              ' green
                        long    %00000111_00000011              ' blue
                        long    %00011011_00000011              ' yellow
                        long    %00010111_00000011              ' magenta
                        long    %00001111_00000011              ' cyan
                        long    %00011111_00000011              ' white

                        ' Uninitialized data

screen_ptr              res     1
font_ptr                res     1

x                       res     1
y                       res     1
z                       res     1
fg                      res     1
bg                      res     1

a                       res     1
b                       res     1
c                       res     1
d                       res     1

row                     res     1
fours                   res     1


                        fit     $1f0

DAT

font  long

'     Font 8x8

'     1. 4 Scanlines of Char 00h - FFh

byte  $00,$7E,$7E,$36,$08,$1C,$08,$00,$FF,$00,$FF,$F0,$3C,$FC,$FE,$18
byte  $01,$40,$18,$66,$FE,$7C,$00,$18,$18,$18,$00,$00,$00,$00,$00,$00
byte  $00,$18,$66,$36,$18,$00,$1C,$18,$30,$0C,$00,$00,$00,$00,$00,$60
byte  $1C,$18,$3E,$3E,$38,$7F,$1C,$7F,$3E,$3E,$00,$00,$60,$00,$06,$3E
byte  $3E,$1C,$3F,$3C,$1F,$7F,$7F,$3C,$63,$3C,$78,$67,$0F,$63,$63,$3E
byte  $3F,$3E,$3F,$3C,$7E,$63,$63,$63,$63,$66,$7F,$3C,$03,$3C,$08,$00
byte  $0C,$00,$07,$00,$38,$00,$3C,$00,$07,$18,$60,$07,$1C,$00,$00,$00
byte  $00,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$70,$18,$0E,$6E,$00
byte  $3E,$33,$30,$3E,$63,$0C,$0C,$00,$3E,$63,$0C,$66,$3E,$0C,$63,$1C
byte  $18,$00,$7C,$3E,$63,$0C,$1E,$06,$63,$63,$63,$18,$1C,$66,$1F,$70
byte  $18,$30,$30,$18,$6E,$6E,$3C,$1C,$18,$00,$00,$C6,$C6,$18,$00,$00
byte  $44,$AA,$EE,$18,$18,$18,$6C,$00,$00,$6C,$6C,$00,$6C,$6C,$18,$00
byte  $18,$18,$00,$18,$00,$18,$18,$6C,$6C,$00,$6C,$00,$6C,$00,$6C,$18
byte  $6C,$00,$00,$6C,$18,$00,$00,$6C,$18,$18,$00,$FF,$00,$0F,$F0,$FF
byte  $00,$1E,$7F,$00,$7F,$00,$00,$00,$7E,$1C,$1C,$70,$00,$60,$78,$00
byte  $00,$18,$0C,$30,$70,$18,$00,$00,$1C,$00,$00,$F0,$36,$1E,$00,$00

'     2. 4 Scanlines of Char 00h - FFh

byte  $00,$81,$FF,$7F,$1C,$3E,$1C,$00,$FF,$3C,$C3,$E0,$66,$CC,$C6,$DB
byte  $07,$70,$3C,$66,$DB,$86,$00,$3C,$3C,$18,$18,$0C,$00,$24,$18,$FF
byte  $00,$3C,$66,$36,$7C,$63,$36,$18,$18,$18,$66,$18,$00,$00,$00,$30
byte  $36,$1C,$63,$63,$3C,$03,$06,$63,$63,$63,$18,$18,$30,$00,$0C,$63
byte  $63,$36,$66,$66,$36,$46,$46,$66,$63,$18,$30,$66,$06,$77,$67,$63
byte  $66,$63,$66,$66,$7E,$63,$63,$63,$63,$66,$63,$0C,$06,$30,$1C,$00
byte  $18,$00,$06,$00,$30,$00,$66,$00,$06,$00,$00,$06,$18,$00,$00,$00
byte  $00,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$18,$18,$18,$3B,$08
byte  $63,$00,$18,$41,$00,$18,$0C,$00,$41,$00,$18,$00,$41,$18,$1C,$36
byte  $0C,$00,$36,$41,$00,$18,$21,$0C,$00,$1C,$00,$18,$36,$66,$33,$D8
byte  $0C,$18,$18,$0C,$3B,$3B,$36,$36,$00,$00,$00,$67,$67,$00,$CC,$33
byte  $11,$55,$BB,$18,$18,$18,$6C,$00,$00,$6C,$6C,$00,$6C,$6C,$18,$00
byte  $18,$18,$00,$18,$00,$18,$18,$6C,$6C,$00,$6C,$00,$6C,$00,$6C,$18
byte  $6C,$00,$00,$6C,$18,$00,$00,$6C,$18,$18,$00,$FF,$00,$0F,$F0,$FF
byte  $00,$33,$63,$00,$63,$00,$00,$6E,$18,$36,$36,$18,$00,$30,$0C,$3E
byte  $7F,$18,$18,$18,$D8,$18,$18,$6E,$36,$00,$00,$30,$6C,$30,$00,$00

'     3. 4 Scanlines of Char 00h - FFh

byte  $00,$A5,$DB,$7F,$3E,$1C,$3E,$18,$E7,$66,$99,$F0,$66,$FC,$FE,$3C
byte  $1F,$7C,$7E,$66,$DB,$3C,$00,$7E,$7E,$18,$30,$06,$03,$66,$3C,$FF
byte  $00,$3C,$24,$7F,$06,$33,$1C,$0C,$0C,$30,$3C,$18,$00,$00,$00,$18
byte  $63,$18,$60,$60,$36,$03,$03,$30,$63,$63,$18,$18,$18,$7E,$18,$30
byte  $7B,$63,$66,$03,$66,$16,$16,$03,$63,$18,$30,$36,$06,$7F,$6F,$63
byte  $66,$63,$66,$0C,$5A,$63,$63,$63,$36,$66,$31,$0C,$0C,$30,$36,$00
byte  $30,$1E,$3E,$3E,$3E,$3E,$06,$6E,$36,$1C,$60,$66,$18,$37,$3B,$3E
byte  $3B,$6E,$3B,$7E,$3F,$33,$63,$63,$63,$63,$7E,$18,$18,$18,$00,$1C
byte  $03,$33,$3E,$1E,$1E,$1E,$1E,$7E,$3E,$3E,$3E,$1C,$1C,$00,$36,$3E
byte  $7F,$7E,$33,$3E,$3E,$3E,$00,$33,$63,$36,$63,$7E,$26,$3C,$33,$18
byte  $1E,$00,$3E,$33,$00,$00,$36,$36,$18,$00,$00,$36,$36,$18,$66,$66
byte  $44,$AA,$EE,$18,$18,$1F,$6C,$00,$1F,$6F,$6C,$7F,$6F,$6C,$1F,$00
byte  $18,$18,$00,$18,$00,$18,$F8,$6C,$EC,$FC,$EF,$FF,$EC,$FF,$EF,$FF
byte  $6C,$FF,$00,$6C,$F8,$F8,$00,$6C,$FF,$18,$00,$FF,$00,$0F,$F0,$FF
byte  $6E,$33,$03,$7F,$06,$7E,$66,$3B,$3C,$63,$63,$30,$7E,$7E,$06,$63
byte  $00,$7E,$30,$0C,$D8,$18,$00,$3B,$36,$00,$00,$30,$6C,$18,$3C,$00

'     4. 4 Scanlines of Char 00h - FFh

byte  $00,$81,$FF,$7F,$7F,$7F,$7F,$3C,$C3,$42,$BD,$BE,$66,$0C,$C6,$E7
byte  $7F,$7F,$18,$66,$DE,$66,$00,$18,$18,$18,$7F,$7F,$03,$FF,$7E,$7E
byte  $00,$18,$00,$36,$3C,$18,$6E,$00,$0C,$30,$FF,$7E,$00,$7E,$00,$0C
byte  $6B,$18,$38,$3C,$33,$3F,$3F,$18,$3E,$7E,$00,$00,$0C,$00,$30,$18
byte  $7B,$7F,$3E,$03,$66,$1E,$1E,$03,$7F,$18,$30,$1E,$06,$7F,$7B,$63
byte  $3E,$63,$3E,$18,$18,$63,$63,$6B,$1C,$3C,$18,$0C,$18,$30,$63,$00
byte  $00,$30,$66,$63,$33,$63,$1F,$33,$6E,$18,$60,$36,$18,$7F,$66,$63
byte  $66,$33,$6E,$03,$0C,$33,$63,$6B,$36,$63,$32,$0E,$18,$70,$00,$36
byte  $03,$33,$63,$30,$30,$30,$30,$03,$63,$63,$63,$18,$18,$1C,$63,$63
byte  $03,$18,$7F,$63,$63,$63,$33,$33,$63,$63,$63,$03,$0F,$7E,$5F,$3C
byte  $30,$1C,$63,$33,$3B,$67,$7C,$1C,$18,$7F,$7F,$7E,$5E,$18,$33,$CC
byte  $11,$55,$BB,$18,$18,$18,$6C,$00,$18,$60,$6C,$60,$60,$6C,$18,$00
byte  $18,$18,$00,$18,$00,$18,$18,$6C,$0C,$0C,$00,$00,$0C,$00,$00,$00
byte  $6C,$00,$00,$6C,$18,$18,$00,$6C,$18,$18,$00,$FF,$00,$0F,$F0,$FF
byte  $3B,$1B,$03,$36,$0C,$1B,$66,$18,$66,$7F,$63,$7C,$DB,$DB,$7E,$63
byte  $7F,$18,$18,$18,$18,$18,$7E,$00,$1C,$18,$18,$30,$6C,$0C,$3C,$00

'     5. 4 Scanlines of Char 00h - FFh

byte  $00,$BD,$C3,$3E,$3E,$7F,$7F,$3C,$C3,$42,$BD,$33,$3C,$0C,$C6,$E7
byte  $1F,$7C,$18,$66,$D8,$66,$7E,$7E,$18,$7E,$30,$06,$03,$66,$FF,$3C
byte  $00,$18,$00,$7F,$60,$0C,$3B,$00,$0C,$30,$3C,$18,$00,$00,$00,$06
byte  $63,$18,$0C,$60,$7F,$60,$63,$0C,$63,$60,$00,$00,$18,$00,$18,$18
byte  $7B,$63,$66,$03,$66,$16,$16,$73,$63,$18,$33,$36,$46,$6B,$73,$63
byte  $06,$63,$36,$30,$18,$63,$63,$6B,$36,$18,$4C,$0C,$30,$30,$00,$00
byte  $00,$3E,$66,$03,$33,$7F,$06,$33,$66,$18,$60,$1E,$18,$6B,$66,$63
byte  $66,$33,$06,$3E,$0C,$33,$63,$6B,$1C,$63,$18,$18,$18,$18,$00,$63
byte  $63,$33,$7F,$3E,$3E,$3E,$3E,$03,$7F,$7F,$7F,$18,$18,$18,$7F,$7F
byte  $1F,$7E,$33,$63,$63,$63,$33,$33,$63,$63,$63,$03,$06,$18,$63,$18
byte  $3E,$18,$63,$33,$66,$6F,$00,$00,$0C,$03,$60,$CC,$6C,$3C,$66,$66
byte  $44,$AA,$EE,$18,$1F,$1F,$6F,$7F,$1F,$6F,$6C,$6F,$7F,$7F,$1F,$1F
byte  $F8,$FF,$FF,$F8,$FF,$FF,$F8,$EC,$FC,$EC,$FF,$EF,$EC,$FF,$EF,$FF
byte  $FF,$FF,$FF,$FC,$F8,$F8,$FC,$FF,$FF,$1F,$F8,$FF,$FF,$0F,$F0,$00
byte  $13,$33,$03,$36,$06,$1B,$66,$18,$66,$63,$36,$66,$DB,$DB,$06,$63
byte  $00,$18,$0C,$30,$18,$18,$00,$6E,$00,$18,$00,$37,$6C,$3E,$3C,$00

'     6. 4 Scanlines of Char 00h - FFh

byte  $00,$99,$E7,$1C,$1C,$6B,$3E,$18,$E7,$66,$99,$33,$18,$0E,$E6,$3C
byte  $07,$70,$7E,$00,$D8,$3C,$7E,$3C,$18,$3C,$18,$0C,$7F,$24,$FF,$18
byte  $00,$00,$00,$36,$3E,$66,$33,$00,$18,$18,$66,$18,$18,$00,$18,$03
byte  $36,$18,$66,$63,$30,$63,$63,$0C,$63,$30,$18,$18,$30,$7E,$0C,$00
byte  $03,$63,$66,$66,$36,$46,$06,$66,$63,$18,$33,$66,$66,$63,$63,$63
byte  $06,$73,$66,$66,$18,$63,$36,$7F,$63,$18,$66,$0C,$60,$30,$00,$00
byte  $00,$33,$66,$63,$33,$03,$06,$3E,$66,$18,$66,$36,$18,$6B,$66,$63
byte  $3E,$3E,$06,$60,$6C,$33,$36,$7F,$36,$7E,$4C,$18,$18,$18,$00,$63
byte  $3E,$33,$03,$33,$33,$33,$33,$7E,$03,$03,$03,$18,$18,$18,$63,$63
byte  $03,$1B,$33,$63,$63,$63,$33,$33,$7E,$36,$63,$7E,$66,$7E,$F3,$1B
byte  $33,$18,$63,$33,$66,$7B,$7E,$3E,$C6,$03,$60,$66,$56,$3C,$CC,$33
byte  $11,$55,$BB,$18,$18,$18,$6C,$6C,$18,$6C,$6C,$6C,$00,$00,$00,$18
byte  $00,$00,$18,$18,$00,$18,$18,$6C,$00,$6C,$00,$6C,$6C,$00,$6C,$00
byte  $00,$18,$6C,$00,$00,$18,$6C,$6C,$18,$00,$18,$FF,$FF,$0F,$F0,$00
byte  $3B,$63,$03,$36,$63,$1B,$66,$18,$3C,$36,$36,$66,$7E,$7E,$0C,$63
byte  $7F,$00,$00,$00,$18,$1B,$18,$3B,$00,$00,$00,$36,$00,$00,$3C,$00

'     7. 4 Scanlines of Char 00h - FFh

byte  $00,$81,$FF,$08,$08,$08,$08,$00,$FF,$3C,$C3,$33,$7E,$0F,$67,$DB
byte  $01,$40,$3C,$66,$D8,$61,$7E,$18,$18,$18,$00,$00,$00,$00,$00,$00
byte  $00,$18,$00,$36,$18,$63,$6E,$00,$30,$0C,$00,$00,$18,$00,$18,$01
byte  $1C,$7E,$7F,$3E,$78,$3E,$3E,$0C,$3E,$1E,$18,$18,$60,$00,$06,$18
byte  $1E,$63,$3F,$3C,$1F,$7F,$0F,$5C,$63,$3C,$1E,$67,$7F,$63,$63,$3E
byte  $0F,$3E,$67,$3C,$3C,$3E,$1C,$36,$63,$3C,$7F,$3C,$40,$3C,$00,$00
byte  $00,$6E,$3B,$3E,$6E,$3E,$0F,$30,$67,$3C,$66,$67,$3C,$6B,$66,$3E
byte  $06,$30,$0F,$3F,$38,$6E,$1C,$36,$63,$60,$7E,$70,$18,$0E,$00,$7F
byte  $30,$6E,$3E,$6E,$6E,$6E,$6E,$30,$3E,$3E,$3E,$3C,$3C,$3C,$63,$63
byte  $7F,$7E,$73,$3E,$3E,$3E,$6E,$6E,$60,$1C,$3E,$18,$3F,$18,$63,$0E
byte  $6E,$3C,$3E,$6E,$66,$73,$00,$00,$7C,$00,$00,$33,$FB,$18,$00,$00
byte  $44,$AA,$EE,$18,$18,$18,$6C,$6C,$18,$6C,$6C,$6C,$00,$00,$00,$18
byte  $00,$00,$18,$18,$00,$18,$18,$6C,$00,$6C,$00,$6C,$6C,$00,$6C,$00
byte  $00,$18,$6C,$00,$00,$18,$6C,$6C,$18,$00,$18,$FF,$FF,$0F,$F0,$00
byte  $6E,$33,$03,$36,$7F,$0E,$3E,$18,$18,$1C,$77,$3C,$00,$06,$78,$63
byte  $00,$7E,$7E,$7E,$18,$1B,$00,$00,$00,$00,$00,$3C,$00,$00,$00,$00

'     8. 4 Scanlines of Char 00h - FFh

byte  $00,$7E,$7E,$00,$00,$1C,$1C,$00,$FF,$00,$FF,$1E,$18,$07,$03,$18
byte  $00,$00,$18,$00,$00,$3E,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$00
byte  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0C,$00,$00,$00
byte  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0C,$00,$00,$00,$00
byte  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
byte  $00,$70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF
byte  $00,$00,$00,$00,$00,$00,$00,$1F,$00,$00,$3C,$00,$00,$00,$00,$00
byte  $0F,$78,$00,$00,$00,$00,$00,$00,$00,$3F,$00,$00,$00,$00,$00,$00
byte  $1E,$00,$00,$00,$00,$00,$00,$1C,$00,$00,$00,$00,$00,$00,$00,$00
byte  $00,$00,$00,$00,$00,$00,$00,$00,$3F,$00,$00,$18,$00,$18,$E3,$00
byte  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$F0,$60,$00,$00,$00
byte  $11,$55,$BB,$18,$18,$18,$6C,$6C,$18,$6C,$6C,$6C,$00,$00,$00,$18
byte  $00,$00,$18,$18,$00,$18,$18,$6C,$00,$6C,$00,$6C,$6C,$00,$6C,$00
byte  $00,$18,$6C,$00,$00,$18,$6C,$6C,$18,$00,$18,$FF,$FF,$0F,$F0,$00
byte  $00,$00,$00,$00,$00,$00,$03,$00,$7E,$00,$00,$00,$00,$03,$00,$00
byte  $00,$00,$00,$00,$18,$0E,$00,$00,$00,$00,$00,$38,$00,$00,$00,$00




{{
+------------------------------------------------------------------------------------------------------------------------------+
|                                   TERMS OF USE: Parallax Object Exchange License                                             |
+------------------------------------------------------------------------------------------------------------------------------+
|Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    |
|files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    |
|modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software|
|is furnished to do so, subject to the following conditions:                                                                   |
|                                                                                                                              |
|The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.|
|                                                                                                                              |
|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          |
|WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         |
|COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   |
|ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         |
+------------------------------------------------------------------------------------------------------------------------------+
}}