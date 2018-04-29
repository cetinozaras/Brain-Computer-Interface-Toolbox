void setup() {
  Serial.begin(9600);
  pinMode(8, OUTPUT);
  digitalWrite(8, LOW);
}

void loop() {
  int oku;
  oku=Serial.read();
  if(oku==66)
  {
  digitalWrite(8, HIGH); 
  delay(500);
  digitalWrite(8,LOW);
  }
  
  if(oku==83) 
  { 
  //digitalWrite(8, HIGH); 
  //delay(500);
  //digitalWrite(8,LOW);
  }
}



