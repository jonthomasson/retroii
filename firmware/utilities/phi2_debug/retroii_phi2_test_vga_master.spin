''*******************************
''* retroii_kb_test  8/2019   *
''* Author: Jon Thomoasson    *
''*******************************
''
''
CON
    _clkmode  = xtal1 + pll16x
    _xinfreq  = 5_000_000
    rx = 31
    tx = 30
    NUM        = %100
    RepeatRate = 40
    SDA_pin = 14
    SCL_pin = 13
    Bitrate = 400_000
    Btn_Phi2 = 11
    Prop_Phi2 = 12
  
OBJ 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 
    button: "Button"
DAT



VAR
    word key               
    long phi2_stack[20]                                            


PUB main 
    init
    ser.Str(string("keyboard test..."))
    ser.Str(string("connect keyboard to ps2 port and type a message."))
    repeat
        key := kb.key 
        if key <128 and key > 0
            ser.Tx (key) 
            I2C.writeByte($42,31,key)
        

PRI init 
    dira[Prop_Phi2]~~  'output
    outa[Prop_Phi2] := 0   'low
    dira[Btn_Phi2]~  'input
    I2C.start(SCL_pin,SDA_pin,Bitrate)
    ser.Start(rx, tx, 0, 115200)
    kb.startx(26, 27, NUM, RepeatRate)  
    cog_button := cognew(process_phi2, @phi2_stack)   
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start


pri process_phi2 | i
  repeat
    'Returns true only if button pressed, held for at least 80ms and released.
    if button.ChkBtnPulse(Btn_Phi2, 1, 80)
        !outa[Prop_Phi2] 'toggle phi2


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