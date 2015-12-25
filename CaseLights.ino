/*
 * CaseLights
 * 
 * Arduino RGB LED Controller with Serial interface.
 * 
 * Two commands are supported, ending with a new-line:
 * 
 *     RGB r g b
 *     
 *     UV s
 * 
 * The RGB command sets the PWM output for the LEDs.
 * The UV command turns the UV lights on or off (s can be 0 or 1).
 */

//#define DEBUG

static int redPin = 10;
static int greenPin = 9;
static int bluePin = 11;
static int uvPin = 13;

void setup() {
  Serial.begin(115200);
  
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);
  pinMode(uvPin, OUTPUT);
  
  analogWrite(redPin, 0);
  analogWrite(greenPin, 0);
  analogWrite(bluePin, 0);
  digitalWrite(uvPin, LOW);

#ifdef DEBUG
  Serial.println("CaseLights initialized");
#endif
}

void loop() {
  if (Serial.available() > 0) {
    int c = Serial.read();
    if (c == 'R') {
      c = Serial.read();
      if (c == 'G') {
        c = Serial.read();
        if (c == 'B') {
          int r = Serial.parseInt();
          int g = Serial.parseInt();
          int b = Serial.parseInt();
          analogWrite(redPin, r);
          analogWrite(greenPin, g);
          analogWrite(bluePin, b);
#ifdef DEBUG
          Serial.print("RGB set ");
          Serial.print(r);
          Serial.print(' ');
          Serial.print(g);
          Serial.print(' ');
          Serial.print(b);
          Serial.println();
#endif
        } else {
#ifdef DEBUG
          Serial.print("Invalid character after G: ");
          Serial.print(c);
          Serial.println();
#endif
        }
      } else {
#ifdef DEBUG
        Serial.print("Invalid character after R: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if (c == 'U') {
      c = Serial.read();
      if (c == 'V') {
        c = Serial.parseInt();
        if (c == 0) {
          digitalWrite(uvPin, LOW);
#ifdef DEBUG
          Serial.println("UV off");
#endif
        } else if (c == 1) {
          digitalWrite(uvPin, HIGH);
#ifdef DEBUG
          Serial.println("UV on");
#endif
        } else {
#ifdef DEBUG
          Serial.print("Invalid character for UV: ");
          Serial.print(c);
          Serial.println();
#endif
        }
      } else {
#ifdef DEBUG
        Serial.print("Invalid character after U: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if ((c == '\n') || (c == '\r')) {
#ifdef DEBUG
      Serial.println("Skipping new-line or carriage-return...");
#endif
    } else {
#ifdef DEBUG
      Serial.print("Invalid character: ");
      Serial.print(c);
      Serial.println();
#endif
    }
  }
}

