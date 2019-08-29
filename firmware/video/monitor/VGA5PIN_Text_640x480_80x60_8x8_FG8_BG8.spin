''******************************************************
''* VGA5PIN_Text_640x480_80x60_8x8_FG8-BG8.spin 2/2017 *
''* Author: Werner L. Schneider                        *
''* 256 Chars, 8x8 Pixel,                              *
''******************************************************
''
''
'' Based on VGA_HiRes Text Driver from Chip Gracey
''
''
CON

' 640 x 480 : 80 x 60 characters

    hp = 640        ' horizontal pixels
    vp = 480        ' vertical pixels
    hf = 24         ' horizontal front porch pixels
    hs = 40         ' horizontal sync pixels
    hb = 128        ' horizontal back porch pixels
    vf = 9          ' vertical front porch lines
    vs = 3          ' vertical sync lines
    vb = 28         ' vertical back porch lines
    hn = 1          ' horizontal normal sync state (0|1)
    vn = 1          ' vertical normal sync state (0|1)
    pr = 30         ' pixel rate in MHz at 80MHz system clock (5MHz granularity)

' columns and rows

    cols = hp / 8   ' 80 cols
    rows = vp / 8   ' 60 rows  
    xpix = 640
    ypix = 480
    fsize = 8


VAR long cog[2]


PUB start(BasePin, ScreenPtr, CursorPtr, SyncPtr) : okay | i, j

'' Start VGA driver - starts two COGs
'' returns false if two COGs not available
''
''      BasePin = VGA starting pin (0, 8, 16, 24, etc.)
''
''      ScreenPtr = Pointer to 80x60 words containing Latin-1 codes and colors for
''              each of the 80x60 screen characters. The lower byte of the word
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
''              cursor example: 127, 63, %010 = blinking block in lower-right
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
    font_part := 1
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
' COG RAM usage: $000      = d0 - used to inc destination fields for indirection
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
                        mov     fours, #rows * 2 / 2            ' set number of 4-line builds for whole screen

                        ' Build four scan lines into scanbuff

fourline                mov     font_ptr, font_part             ' get address of appropriate font section
                        shl     font_ptr, #8+2
                        add     font_ptr, font_base

                        movd    :pixa, #scanbuff-1              ' reset scanbuff address (pre-decremented)
                        movd    :cola, #colorbuff-1             ' reset colorbuff address (pre-decremented)
                        movd    :colb, #colorbuff-1

                        mov     y, #2                           ' must build scanbuff in two sections because
                        mov     vscl, vscl_line2x               ' ..pixel counter is limited to twelve bits

:halfrow                waitvid underscore, #0                  ' output lows to let other COG drive VGA pins
                        mov     x, #cols/2                      ' ..for 2 scan lines, ready for half a row

:column                 rdword  z, screen_ptr                   ' get character and colors from screen memory
                        mov     bg, z
                        and     z, #$ff                         ' mask character code
                        shl     z, #2                           ' * 4
                        add     z, font_ptr                     ' add font section address to point to 8*4 pixels

                        add     :pixa, d0                       ' increment scanbuff destination addresses
                        add     screen_ptr, #2                  ' increment screen memory address

:pixa                   rdlong  scanbuff, z                     ' read pixel long (8*4) into scanbuff

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

                        djnz    y, #:halfrow                    ' loop to do 2nd half-row, time for 2nd WAITVID

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
        if_nz           mov     x, underscore
        if_nz           cmp     font_part, #1   wz              ' if underscore, must be last font section

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

                        add     font_part, #2                   ' if font_part + 2 => 4, subtract 4 (new row)
                        cmpsub  font_part, #2           wc      ' c=0 for same row, c=1 for new row
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
vscl_line               long    hp + hf + hs + hb               ' total number of pixels per scan line
vscl_line2x             long    (hp + hf + hs + hb) * 2         ' total number of pixels per 2 scan lines
vscl_chr                long    1 << 12 + 8                     ' 1 clock per pixel and 8 pixels per set
colormask               long    $FCFC                           ' mask to isolate R,G,B bits from H,V
longmask                long    $FFFFFFFF                       ' all bits set
slowbit                 long    1 << 25                         ' cnt mask for slow cursor blink
fastbit                 long    1 << 24                         ' cnt mask for fast cursor blink

underscore              long    $FFFF0000                       ' underscore cursor pattern

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

row                     res     1
fours                   res     1


'                        fit     $1f0

DAT

font  long

'     Font 8x8

'     1. 4 Scanlines of Char 00h - FFh

long  $00000000,$81A5817E,$FFDBFF7E,$7F7F7F36,$7F3E1C08,$7F1C3E1C,$7F3E1C08,$3C180000
long  $C3E7FFFF,$42663C00,$BD99C3FF,$BEF0E0F0,$6666663C,$0CFCCCFC,$C6FEC6FE,$E73CDB18
long  $7F1F0701,$7F7C7040,$187E3C18,$66666666,$DEDBDBFE,$663C867C,$00000000,$187E3C18
long  $187E3C18,$18181818,$7F301800,$7F060C00,$03030000,$FF662400,$7E3C1800,$7EFFFF00
long  $00000000,$183C3C18,$00246666,$367F3636,$3C067C18,$18336300,$6E1C361C,$000C1818
long  $0C0C1830,$3030180C,$FF3C6600,$7E181800,$00000000,$7E000000,$00000000,$0C183060
long  $6B63361C,$18181C18,$3860633E,$3C60633E,$33363C38,$3F03037F,$3F03061C,$1830637F
long  $3E63633E,$7E63633E,$00181800,$00181800,$0C183060,$007E0000,$30180C06,$1830633E
long  $7B7B633E,$7F63361C,$3E66663F,$0303663C,$6666361F,$1E16467F,$1E16467F,$0303663C
long  $7F636363,$1818183C,$30303078,$1E366667,$0606060F,$7F7F7763,$7B6F6763,$6363633E
long  $3E66663F,$6363633E,$3E66663F,$180C663C,$185A7E7E,$63636363,$63636363,$6B636363
long  $1C366363,$3C666666,$1831637F,$0C0C0C3C,$180C0603,$3030303C,$63361C08,$00000000
long  $0030180C,$301E0000,$663E0607,$633E0000,$333E3038,$633E0000,$1F06663C,$336E0000
long  $6E360607,$181C0018,$60600060,$36660607,$1818181C,$7F370000,$663B0000,$633E0000
long  $663B0000,$336E0000,$6E3B0000,$037E0000,$0C3F0C0C,$33330000,$63630000,$6B630000
long  $36630000,$63630000,$327E0000,$0E181870,$18181818,$7018180E,$00003B6E,$361C0800
long  $0303633E,$33330033,$633E1830,$301E413E,$301E0063,$301E180C,$301E0C0C,$037E0000
long  $633E413E,$633E0063,$633E180C,$181C0066,$181C413E,$1C00180C,$63361C63,$633E361C
long  $037F0C18,$187E0000,$7F33367C,$633E413E,$633E0063,$633E180C,$3300211E,$33330C06
long  $63630063,$63361C63,$63630063,$037E1818,$0F26361C,$7E3C6666,$5F33331F,$3C18D870
long  $301E0C18,$1C001830,$633E1830,$33330C18,$3B003B6E,$67003B6E,$7C36363C,$1C36361C
long  $18180018,$7F000000,$7F000000,$7E3667C6,$5E3667C6,$18180018,$3366CC00,$CC663300
long  $11441144,$55AA55AA,$BBEEBBEE,$18181818,$18181818,$181F1818,$6C6C6C6C,$00000000
long  $181F0000,$606F6C6C,$6C6C6C6C,$607F0000,$606F6C6C,$6C6C6C6C,$181F1818,$00000000
long  $18181818,$18181818,$00000000,$18181818,$00000000,$18181818,$18F81818,$6C6C6C6C
long  $0CEC6C6C,$0CFC0000,$00EF6C6C,$00FF0000,$0CEC6C6C,$00FF0000,$00EF6C6C,$00FF1818
long  $6C6C6C6C,$00FF0000,$00000000,$6C6C6C6C,$18F81818,$18F80000,$00000000,$6C6C6C6C
long  $18FF1818,$18181818,$00000000,$FFFFFFFF,$00000000,$0F0F0F0F,$F0F0F0F0,$FFFFFFFF
long  $3B6E0000,$1B33331E,$0303637F,$367F0000,$0C06637F,$1B7E0000,$66660000,$183B6E00
long  $663C187E,$7F63361C,$6363361C,$7C301870,$DB7E0000,$DB7E3060,$7E060C78,$63633E00
long  $7F007F00,$187E1818,$1830180C,$180C1830,$18D8D870,$18181818,$7E001800,$003B6E00
long  $1C36361C,$18000000,$18000000,$303030F0,$6C6C6C36,$0C18301E,$3C3C0000,$00000000

'     2. 4 Scanlines of Char 00h - FFh

long  $00000000,$7E8199BD,$7EFFE7C3,$00081C3E,$00081C3E,$1C086B7F,$1C083E7F,$0000183C
long  $FFFFE7C3,$003C6642,$FFC399BD,$1E333333,$187E183C,$070F0E0C,$0367E6C6,$18DB3CE7
long  $0001071F,$0040707C,$183C7E18,$00660066,$00D8D8D8,$3E613C66,$007E7E7E,$FF183C7E
long  $00181818,$00183C7E,$00001830,$00000C06,$00007F03,$00002466,$0000FFFF,$0000183C
long  $00000000,$00180018,$00000000,$0036367F,$00183E60,$0063660C,$006E333B,$00000000
long  $0030180C,$000C1830,$0000663C,$00001818,$0C181800,$00000000,$00181800,$00010306
long  $001C3663,$007E1818,$007F660C,$003E6360,$0078307F,$003E6360,$003E6363,$000C0C0C
long  $003E6363,$001E3060,$00181800,$0C181800,$00603018,$00007E00,$00060C18,$00180018
long  $001E037B,$00636363,$003F6666,$003C6603,$001F3666,$007F4616,$000F0616,$005C6673
long  $00636363,$003C1818,$001E3333,$00676636,$007F6646,$0063636B,$00636373,$003E6363
long  $000F0606,$703E7363,$00676636,$003C6630,$003C1818,$003E6363,$001C3663,$00367F6B
long  $00636336,$003C1818,$007F664C,$003C0C0C,$00406030,$003C3030,$00000000,$FF000000
long  $00000000,$006E333E,$003B6666,$003E6303,$006E3333,$003E037F,$000F0606,$1F303E33
long  $00676666,$003C1818,$3C666660,$0067361E,$003C1818,$006B6B6B,$00666666,$003E6363
long  $0F063E66,$78303E33,$000F0606,$003F603E,$00386C0C,$006E3333,$001C3663,$00367F6B
long  $0063361C,$3F607E63,$007E4C18,$00701818,$00181818,$000E1818,$00000000,$007F6363
long  $1E303E63,$006E3333,$003E037F,$006E333E,$006E333E,$006E333E,$006E333E,$1C307E03
long  $003E037F,$003E037F,$003E037F,$003C1818,$003C1818,$003C1818,$0063637F,$0063637F
long  $007F031F,$007E1B7E,$00733333,$003E6363,$003E6363,$003E6363,$006E3333,$006E3333
long  $3F607E63,$001C3663,$003E6363,$18187E03,$003F6606,$18187E18,$E363F363,$000E1B18
long  $006E333E,$003C1818,$003E6363,$006E3333,$00666666,$00737B6F,$00007E00,$00003E00
long  $007CC60C,$00000303,$00006060,$F03366CC,$60FB566C,$00183C3C,$0000CC66,$00003366
long  $11441144,$55AA55AA,$BBEEBBEE,$18181818,$1818181F,$1818181F,$6C6C6C6F,$6C6C6C7F
long  $1818181F,$6C6C6C6F,$6C6C6C6C,$6C6C6C6F,$0000007F,$0000007F,$0000001F,$1818181F
long  $000000F8,$000000FF,$181818FF,$181818F8,$000000FF,$181818FF,$181818F8,$6C6C6CEC
long  $000000FC,$6C6C6CEC,$000000FF,$6C6C6CEF,$6C6C6CEC,$000000FF,$6C6C6CEF,$000000FF
long  $000000FF,$181818FF,$6C6C6CFF,$000000FC,$000000F8,$181818F8,$6C6C6CFC,$6C6C6CFF
long  $181818FF,$0000001F,$181818F8,$FFFFFFFF,$FFFFFFFF,$0F0F0F0F,$F0F0F0F0,$00000000
long  $006E3B13,$00336333,$00030303,$00363636,$007F6306,$000E1B1B,$033E6666,$00181818
long  $7E183C66,$001C3663,$00773636,$003C6666,$00007EDB,$03067EDB,$00780C06,$00636363
long  $00007F00,$007E0018,$007E000C,$007E0030,$18181818,$0E1B1B18,$00001800,$00003B6E
long  $00000000,$00000018,$00000000,$383C3637,$0000006C,$0000003E,$00003C3C,$00000000





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