void setup() {
  pinMode(0, OUTPUT);     // Fan control
  pinMode(4, INPUT);      // Analog input (Potentiometer)
  Serial.begin(9600);     // Start serial monitor for debugging
}

void loop() {
  int sensorValue = analogRead(A2);           // Read potentiometer (0–1023)
  int pwmValue = map(sensorValue, 0, 1023, 0, 255);  // Scale to 0–255
  

  analogWrite(0, pwmValue);  // Direct hardware PWM to fan

  delay(10);  // Small delay to reduce serial spam
}
