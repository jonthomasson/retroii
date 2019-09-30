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
    {KEYBOARD RETRO][}
    Strobe = 25
    K0 = 17
    K6 = 23
    {MODES}
    MODE_MONITOR = 1
    MODE_RETROII = 2
    MODE_ASSEMBLER = 3
    MODE_SD_CARD = 4
  
OBJ 
    kb:   "keyboard"  
    ser: "FullDuplexSerial.spin"
    I2C : "I2C PASM driver v1.8od" 'od or open drain method requires pull ups on sda/scl lines. But may use this if I need a speed boost.
    'I2C : "I2C PASM driver v1.8pp" 
    button: "Button"
DAT



VAR
    word key               
    long phi2_stack[20]  
    long cog_phi2 
    long soft_switches_old                                         
    long kb_output_data
    long current_mode

PUB main | soft_switches
    init
    ser.Str(string("initializing keyboard..."))
    
    repeat     
        soft_switches := ina[SS_LOW..SS_HIGH]           'send soft switch to register 30 of video processor
        'only send soft_switches when their value changes
        if soft_switches_old <> soft_switches
            ser.Str (string("soft switches updated: "))
            ser.Hex (soft_switches, 2)
            I2C.writeByte($42,30,soft_switches) 
            soft_switches_old := soft_switches
            
        'key := kb.getkey 
        'ser.Dec (key) 
        
        key := kb.key
        
        if key == 208 'f1 toggle kb to data bus
            kb_output_data := !kb_output_data
            ser.Str (string("toggling kb_output_data : "))
            ser.Dec (kb_output_data)
        if key == 209 'f2 toggle clock speed
        
        if key == 210 'f3 mode monitor
            'send i2c to video processor to tell it to switch modes
            I2C.writeByte($42,29,MODE_MONITOR)  
            current_mode := MODE_MONITOR
        if key == 211 'f4 mode RETROII
            I2C.writeByte($42,29,MODE_RETROII)  
            current_mode := MODE_RETROII           
        if key < 128 and key > 0
            I2C.writeByte($42,31,key)
            if kb_output_data == true   'determine where to send key to data bus
                kb_write(key)
        
        
PRI kb_write(data_out) | i
    outa[K6..K0] := data_out 'had to reverse order for it to show on data bus correctly
    
    outa[Strobe]~~ 'strobe high should set K7 high
    
    'clear strobe
    outa[Strobe]~
    
PRI init 
    'dira[Prop_Phi2]~~  'output
    'outa[Prop_Phi2]~   'low
    'dira[Btn_Phi2]~  'input
    dira[K0..K6]~~ 'set keyboard data pins to output
    dira[Strobe]~~ 'set strobe pin to output
    outa[K0..K6] := %0000000 'low
    outa[Strobe]~ 'strobe low
    dira[SS_LOW..SS_HIGH]~
    kb_output_data := false
    I2C.start(SCL_pin,SDA_pin,Bitrate)
    ser.Start(rx, tx, 0, 115200)
    kb.startx(26, 27, NUM, RepeatRate)  
    soft_switches_old := ina[SS_LOW..SS_HIGH] 'populate our soft switch var so we can tell if it changes later
    current_mode := MODE_MONITOR
    'cog_phi2 := cognew(process_phi2, @phi2_stack)   
    'cog_i2c := cognew(process_i2c, @i2c_stack)  
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
