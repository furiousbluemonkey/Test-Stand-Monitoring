const int pins[3] = {A0, A1, A2};
const float R_REF[3] = {510.4, 508.7, 509.7};   // use measured values for higher precision

//PT1000 resistance to temperature conversion (Callendar-Van Dusen equation) ---------------
const double R0 = 1000.0;          
const double A = 3.9083e-3;
const double B = -5.775e-7;
const double C = -4.183e-12;       // only used below 0 °C

double RToKelvin(double R) { //Newton-Raphson numerical solution (calculated in °C)
  double T = (R / R0 - 1.0) / A;          // linear approx (first guess)
  for (int i = 0; i < 10; i++) {
    double c = (T < 0) ? C : 0.0;             // C term only below 0 °C
    double f  = R0 * (1.0 + A*T + B*T*T + c*(T - 100.0)*T*T*T) - R;
    double df = R0 * (A + 2.0*B*T + c*(4.0*T*T*T - 300.0*T*T));
    double dt = f / df;
    T -= dt;
    if (fabs(dt) < 1e-3) break;                   // converged to 0.001 °C
  }
  return T+273.15;
}
//-----------------------------------------------------------------------------------------

const byte numChars = 32; //arbitrary (max message length)
char receivedChars[numChars];
bool newData = false;

float readAdc(int ch) { //AADC count
  float sum = 0;
  for (int i = 0; i < 32; i++) sum += analogRead(pins[ch]);
  return sum / 32.0;
}

float readR(int ch) { //resistance
  float adc = readAdc(ch);
  return R_REF[ch] * adc / (4095.0 - adc);   // sensor on the low side
}

float readV(int ch) { //voltage
  return readAdc(ch) * 3.3 / 4095.0;
}

void setup() {
  analogReadResolution(12); //12 bit
  Serial.begin(115200); //baud rate ignored through USB but a value is needed
}

void loop() {
  recvWithEndMarker(); 
  if (newData) { 
    newData = false;
    parseInput();
  }
}

void recvWithEndMarker() { //takes in the input
  static byte ndx = 0; 
  while (Serial.available() > 0 && !newData) { 
    char rc = Serial.read();
    if (rc == '\r') continue;              // ignore carriage returns (certain terminals have them)
    if (rc != '\n') {
      receivedChars[ndx++] = rc;
      if (ndx >= numChars) ndx = numChars - 1;
    } else {
      receivedChars[ndx] = '\0';
      ndx = 0;
      newData = true;
    }
  }
}

void parseInput() { //reads input and then outputs
  if (strcmp(receivedChars, "READ") == 0) {
  for (int i = 0; i < 3; i++) {
    Serial.print(RToKelvin(readR(i)), 1);
    Serial.print(i < 2 ? " , " : "\n");
  }
  }
  else if (strcmp(receivedChars, "READ_RESISTANCE") == 0) { //resistance query
    for (int i = 0; i < 3; i++) {
    Serial.print(readR(i), 1);
    Serial.print(i < 2 ? " , " : "\n");
  }
  }
  else if (strcmp(receivedChars, "READ_VOLTAGE") == 0) { //voltage query
    for (int i = 0; i < 3; i++) {
    Serial.print(readV(i), 1);
    Serial.print(i < 2 ? " , " : "\n");
  }
  }
  else if (strcmp(receivedChars, "ID?") == 0) { //to check right teensy connected
    Serial.println("Teensy PT1000 reader");
  }
  else {
    Serial.print("ERR: unknown command: ");
    Serial.println(receivedChars);
  }
}