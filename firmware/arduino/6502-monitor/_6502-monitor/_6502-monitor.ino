const char ADDR[] = {53, 51, 49, 47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25, 23};
const char DATA[] = {50, 48, 46, 44, 42, 40, 38, 36};
#define CLOCK 2
#define READ_WRITE 34

void setup() {
  for(int n = 0; n < 16; n += 1){
    pinMode(ADDR[n], INPUT);
  }
  for(int n = 0; n < 8; n += 1){
    pinMode(DATA[n], INPUT);
  }
  pinMode(CLOCK, INPUT);
  pinMode(READ_WRITE, INPUT);
  
  attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, RISING);
  
  Serial.begin(57600);

}

void onClock(){
  char output[15];
  
  unsigned int address = 0;
  for(int n = 0; n < 16; n += 1){
    int bit = digitalRead(ADDR[n]) ? 1 : 0;
    Serial.print(bit);
    address = (address << 1) + bit;
  }
  
  Serial.print("   ");
  
  unsigned int data = 0;
  for(int n = 0; n < 8; n += 1){
    int bit = digitalRead(DATA[n]) ? 1 : 0;
    data = (data << 1) + bit;
    Serial.print(bit);
  }

  sprintf(output, "  %04x %c %02x", address, digitalRead(READ_WRITE) ? 'r' : 'w', data);
  
  Serial.println(output);
}

void loop() {
 
}
