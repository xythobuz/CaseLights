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

enum LoopState {
  LOOP_IDLE,
  LOOP_R,
  LOOP_G,
  LOOP_B,
  LOOP_NUM1,
  LOOP_NUM2,
  LOOP_U,
  LOOP_V
};

static int redPin = 10;
static int greenPin = 9;
static int bluePin = 11;
static int uvPin = 13;
static LoopState state = LOOP_IDLE;
static int r = 0, g = 0, b = 0;

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(5000);
  
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
    if (state == LOOP_IDLE) {
      int c = Serial.read();
      if ((c == 'R') || (c == 'r')) {
        state = LOOP_R;
      } else if ((c == 'U') || (c == 'u')) {
        state = LOOP_U;
      } else if ((c == '\r') || (c == '\n')) {
#ifdef DEBUG
        Serial.println("Skipping newline...");
#endif
      } else {
#ifdef DEBUG
        Serial.print("Invalid character: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if (state == LOOP_R) {
      int c = Serial.read();
      if ((c == 'G') || (c == 'g')) {
        state = LOOP_G;
      } else {
        state = LOOP_IDLE;
#ifdef DEBUG
        Serial.print("Invalid character after R: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if (state == LOOP_G) {
      int c = Serial.read();
      if ((c == 'B') || (c == 'b')) {
        state = LOOP_B;
      } else {
        state = LOOP_IDLE;
#ifdef DEBUG
        Serial.print("Invalid character after G: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if (state == LOOP_B) {
      r = Serial.parseInt();
      state = LOOP_NUM1;
    } else if (state == LOOP_NUM1) {
      g = Serial.parseInt();
      state = LOOP_NUM2;
    } else if (state == LOOP_NUM2) {
      b = Serial.parseInt();
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
      state = LOOP_IDLE;
    } else if (state == LOOP_U) {
      int c = Serial.read();
      if ((c == 'V') || (c == 'v')) {
        state = LOOP_V;
      } else {
        state = LOOP_IDLE;
#ifdef DEBUG
        Serial.print("Invalid character after U: ");
        Serial.print(c);
        Serial.println();
#endif
      }
    } else if (state == LOOP_V) {
      int n = Serial.parseInt();
      if (n == 0) {
        digitalWrite(uvPin, LOW);
#ifdef DEBUG
        Serial.println("UV off");
#endif
      } else {
        digitalWrite(uvPin, HIGH);
#ifdef DEBUG
        Serial.println("UV on");
#endif
      }
      state = LOOP_IDLE;
    } else {
      state = LOOP_IDLE;
#ifdef DEBUG
      Serial.print("Invalid state: ");
      Serial.print(state);
      Serial.println();
#endif
    }
  }
}

