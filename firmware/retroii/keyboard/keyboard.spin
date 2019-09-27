''*******************************
''* keyboard  9/2019                                                                    *
''* Author: Jon Thomoasson                                                              *
''* Description: firmware that runs on the keyboard processor for the RETRO ][ computer * 
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
    SS_LOW = 4
    SS_HIGH = 7
  
OBJ 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 
    button: "Button"
DAT



VAR
    word key               
    long phi2_stack[20]  
    long cog_phi2 
    byte soft_switches_old                                         


PUB main | soft_switches
    init
    ser.Str(string("initializing keyboard..."))
    
    repeat     
        key := kb.key 
        ser.Tx (key) 
        I2C.writeByte($42,31,key)                       'send key to register 31 of video processor
        ser.Str(string("key sent"))
        soft_switches := ina(SS_LOW..SS_HIGH)           'send soft switch to register 30 of video processor
        'only send soft_switches when their value changes
        'may need to put this in its own cog so we're not waiting for a key press...
        if soft_swtches_old <> soft_switches
            I2C.writeByte($42,30,soft_switches) 

'this will run in its own cog to handle incoming/outgoing requests to video processor on i2c bus            
PRI process_i2c
      

PRI init 
    'dira[Prop_Phi2]~~  'output
    'outa[Prop_Phi2]~   'low
    'dira[Btn_Phi2]~  'input
    I2C.start(SCL_pin,SDA_pin,Bitrate)
    ser.Start(rx, tx, 0, 115200)
    kb.startx(26, 27, NUM, RepeatRate)  
    soft_switches_old := ina(SS_LOW..SS_HIGH) 'populate our soft switch var so we can tell if it changes later
    'cog_phi2 := cognew(process_phi2, @phi2_stack)   
    waitcnt(clkfreq * 1 + cnt)                     'wait 1 second for cogs to start


pri process_phi2
  dira[Prop_Phi2]~~  'output
  outa[Prop_Phi2]~   'low
  repeat
    '!outa[Prop_Phi2]
    'Returns true only if button pressed, held for at least 80ms and released.
    if button.ChkBtnPulse(Btn_Phi2, 1, 80)
        'ser.Str (string("button pushed"))
        !outa[Prop_Phi2] 'toggle phi2
