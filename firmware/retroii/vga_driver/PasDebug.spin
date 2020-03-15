''****************************************
''*  Propeller Assembly Source Debugger  *
''*  (PASD)        needs PASD.exe on PC  *
''****************************************
'' version 0.2 , August 2007
''
'' (c)2007 Andy Schenk, Insonix GmbH
''         www.insonix.ch/propeller
'' It's allowed to use this only for non commercial projects.

CON

  BAUDRATE    =  115200


VAR

  long  cog                     'cog flag/id

  long  serpins                 '11 contiguous longs
  long  bitticks
  long  cpntr                   'pointer to code in main ram


PUB start(rxpin, txpin, codeptr) : okay

'' Start PASD driver - starts a cog
'' returns false if no cog available
''
  longfill(@serpins, 0, 3)
  serpins := txpin<<16 + rxpin
  bitticks := clkfreq / BAUDRATE
  cpntr := codeptr
  okay := cog := cognew(@entry, @serpins) + 1

  repeat until bitticks == 0                            'wait until PC ready
    

PUB stop

'' Stop the driver - frees a cog

  if cog
    cogstop(cog~ - 1)


DAT

'*********************************
'* Assembly language PASD driver *
'*********************************

                        org
entry
                        mov     t1,par                  'get parameter address

                        rdword  t2,t1                   'get rx_pin
                        mov     rxmask,#1
                        shl     rxmask,t2

                        add     t1,#2                   'get tx_pin
                        rdword  t2,t1
                        mov     txmask,#1
pasdi                   shl     txmask,t2

                        add     t1,#2                   'get bit ticks
pasdd                   rdlong  bittime,t1

pasdp                   add     t1,#4                   'get codepointer
pasdr                   rdlong  cogadr,t1
                        sub     t1,#4

                        or      outa,txmask             'tx_pin = output/idle
                        or      dira,txmask

                        call    #charin                 'wait until PC sends start
                        wrlong  K0,t1                   'report ready to spin
                        wrlong  K0,sharep               'prepare execute
                        
cmdloop                 call    #charin                 'wait for cmd from PC
                        cmp     rxd,#5      wz          'mouse/debugger command?
              if_nz     jmp     #cmdloop
                        call    #charin                 'Command
                        mov     t1,rxd
                        and     t1,#$7F
                        call    #charin                 'Val L
                        mov     t2,rxd
                        call    #charin                 'Val H
                        shl     rxd,#8
                        or      t2,rxd

                        cmp     t1,#"d"     wz          'dump cog ram?
              if_z      jmp     #dumpcog
                        cmp     t1,#"m"     wz          'dump hub-ram?
              if_z      jmp     #dumphub

                        cmp     t1,#"i"     wz          'Init?
              if_z      jmp     #initpar
                        cmp     t1,#"r"     wz          'Run/Cont?
              if_z      jmp     #runcont
                        cmp     t1,#"p"     wz          'Stop? = Restart
              if_z      jmp     #resetcog
                        cmp     t1,#"s"     wz          'Step?
              if_z      jmp     #single
                        cmp     t1,#"b"     wz          'Set Break?
              if_z      jmp     #setbrk
                        cmp     t1,#"w"     wz          'Write clong?
              if_z      jmp     #wrcode
                        cmp     t1,#"l"     wz          'Low word clong
              if_z      jmp     #lowword
                        cmp     t1,#"h"     wz          'High word clong
              if_z      jmp     #highword
                        cmp     t1,#"e"     wz          'Execute clong
              if_z      jmp     #execlong

                        jmp     #cmdloop 

'-------------
dumpcog                 mov     t3,#511
                        movs    i_getind,#0

dcloop                  mov     op,i_getind
                        call    #execute
                        mov     op,i_write
                        call    #execute
                        add     i_getind,#1
                        rdlong  t1,shareg
                        call    #sendlong
                        djnz    t3,#dcloop

                        mov     op,i_nop
                        call    #execute
                        jmp     #cmdloop

'-------------
dumphub                 mov     t3,#128
dhloop                  rdlong  t1,t2
                        call    #sendlong
                        add     t2,#4
                        djnz    t3,#dhloop

                        mov     op,i_nop
                        call    #execute
                        jmp     #cmdloop

'-------------
resetcog                cogstop cognr
                        mov     t1,cogpar               'restart cog
                        shl     t1,#14
                        or      t1,cogadr
                        shl     t1,#2
                        or      t1,cognr
                        coginit t1
                        jmp     #cmdloop
                        
'-------------
initpar                 mov     op,i_cogid              'get cogid
                        call    #execute
                        mov     op,i_write
                        call    #execute
                        rdlong  cognr,shareg
                        movs    i_getind,#$1F0          'get cogpar-reg
                        mov     op,i_getind
                        call    #execute
                        mov     op,i_write
                        call    #execute
                        rdlong  cogpar,shareg

                        mov     t1,cogadr
                        call    #sendlong
                        
                        jmp     #cmdloop

'-------------
runcont                 movs    i_jump,t2               'start addr
                        wrlong  K0,shareg               'clr brk addr
                        mov     op,i_jump
                        call    #execute                'jump
'-------------
waitbrk                 mov     dtime,rate
waitlp                  test    rxmask,ina    wz        'if not rx start
              if_z      jmp     #cmdloop
                        djnz    dtime,#waitlp           'wait rate
                        
                        mov     t1,watchId
                        call    #sendlong               'send ina repeatly
                        mov     t1,ina
                        call    #sendlong
                        
                        rdlong  t1,shareg     
                        tjz     t1,#waitbrk             'wait for break      

                        shl     t1,#16
                        or      t1,brkId                'add Break ID
                        call    #sendlong               
                        jmp     #cmdloop

'-------------
single                  movs    i_getind,t2             'get Instr from addr
getsngl                 mov     op,i_getind
                        call    #execute
                        mov     op,i_write
'dosngle                 call    #execute
                        call    #execute
                        rdlong  op,shareg               'and execute
dosngle                 wrlong  K0,shareg               'clr brk addr
                        call    #execute
                        rdlong  t1,shareg    wz         'get addr+c/z
              if_nz     jmp     #waitbrk                'if no break
                        mov     op,i_break
                        call    #execute                'force break ??
                        jmp     #waitbrk
                        
'-------------
execlong                mov     op,clong                'Exec 1 op in clong
                        jmp     #dosngle
                        
'-------------
lowword                 mov     clong,t2
                        jmp     #cmdloop
'-------------
highword                shl     t2,#16
                        or      clong,t2
                        jmp     #cmdloop

'-------------
setbrk                  wrlong  i_break,shareg          'break instr
                        jmp     #wrtoadr
                        
'-------------
wrcode                  wrlong  clong,shareg            'write code
wrtoadr                 movd    i_setind,t2             'to addr
                        mov     op,i_setind
                        call    #execute
                        jmp     #cmdloop

'-------------
i_getind                        mov     pasdd,0-0       'opcodes for asm cog
i_write                         wrlong  pasdd,pasdr
i_nop                           nop
i_cogid                         cogid   pasdd
i_jump                          jmp     #0-0
i_setind                        rdlong  0-0,pasdr
i_break                         jmpret  pasdd,#0
i_clrd                          mov     pasdd,#0
'-------------
execute                 wrlong  op,sharep               'set instruction
                        mov     dtime,#72
                        add     dtime,cnt               'wait for execution
                        waitcnt dtime,#48
                        wrlong  K0,sharep               'sync
                        waitcnt dtime,#32
execute_ret             ret

'-------------
sendlong                mov     txd,t1                  'send long t1 as 4 bytes
                        call    #charout
                        mov     txd,t1
                        shr     txd,#8
                        call    #charout
                        mov     txd,t1
                        shr     txd,#16
                        call    #charout
                        mov     txd,t1
                        shr     txd,#24
                        call    #charout
sendlong_ret            ret
                         
'-------------
charout                 and     txd,#$FF                'send 1 character

                        mov     txcnt,#10
                        or      txd,#$100               'add stoppbit
                        shl     txd,#1                  'add startbit
                        mov     dtime,cnt
                        add     dtime,bittime

sendbit                 shr     txd,#1      wc          'test LSB
                        mov     ti,outa
              if_nc     andn    ti,txmask               'bit=0  or
              if_c      or      ti,txmask               'bit=1
                        mov     outa,ti
                        waitcnt dtime,bittime           'wait 1 bit
                        djnz    txcnt,#sendbit          '10 times
               
                        waitcnt dtime,bittime           '2 stopbits
charout_ret             ret

'------------
charin                  test    rxmask,ina      wz      'wait until stop
              if_z      jmp     #charin
charstart               test    rxmask,ina      wz      'wait until startbit
              if_nz     jmp     #charstart
                        mov     dtime,bittime
                        shr     dtime,#1
                        add     dtime,bittime           '1.5 bittime
                        add     dtime,cnt
                        mov     rxcnt,#8
                        mov     rxd,#0
charbits                waitcnt dtime,bittime
                        shr     rxd,#1
                        test    rxmask,ina      wz      'shift in bits
              if_nz     or      rxd,#$80
                        djnz    rxcnt,#charbits

                        waitcnt dtime,bittime           'wait until stopbit
charin_ret              ret
                        
'------------
'
' Initialized data
'
sharep                  long    $7FFC
shareg                  long    $7FF8
K512                    long    512
K0                      long    0
d_inc                   long    $200
brkId                   long    $7F06
rate                    long    400_000
watchId                 long    $0006
'
' Uninitialized data
'
t1                      res     1
t2                      res     1
t3                      res     1
bittime                 res     1
dtime                   res     1

rxmask                  res     1
rxd                     res     1
rxbits                  res     1
rxcnt                   res     1

txmask                  res     1
txd                     res     1
txcnt                   res     1
ti                      res     1

clong                   res     1
op                      res     1
cognr                   res     1
cogadr                  res     1
cogpar                  res     1
vp                      res     1
vparr                   res     1


' Add this little debugger kernel at the begin of your Assembly code:
{
'  --------- Debugger Kernel add this at Entry (Addr 0) ---------
   long $34FC1202,$6CE81201,$83C120B,$8BC0E0A,$E87C0E03,$8BC0E0A
   long $EC7C0E05,$A0BC1207,$5C7C0003,$5C7C0003,$7FFC,$7FF8
'  -------------------------------------------------------------- 
}
