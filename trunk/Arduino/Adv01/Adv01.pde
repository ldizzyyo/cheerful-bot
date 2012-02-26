#define SOUND
#define ULTRASOUND

#include <IRremote.h>

#ifdef SOUND

#include <WaveHC.h>
#include <WaveUtil.h>

#endif

#define SERIAL_COM_SPEED 115200

boolean serialDebug = true;

// --- IR Receiver Pin ------------------------------------------------------------------------

const int RECV_PIN = 2;

// --- Motor Pins assignment ------------------------------------------------------------------

// int pmwAPin, int pmwBPin, int dirAPin, int dirBPin
// Ardumoto motors (A0, A1, 8, 9);
const int pwm_a = 5;  //PWM control for motor outputs 1 and 2 is on digital pin 3
const int pwm_b = 6;  //PWM control for motor outputs 3 and 4 is on digital pin 11
const int dir_a = A0;  //direction control for motor outputs 1 and 2 is on digital pin 12
const int dir_b = A1;  //dir ection control for motor outputs 3 and 4 is on digital pin 13

// --- Light detector Pins assignment ---------------------------------------------------------

const int LIGHT_DETECTOR_PIN = A2;

// --- LEDs Pins assignment -------------------------------------------------------------------

const int LED_R_PIN = A3;
const int LED_G_PIN = A4;

// --- Ultrasound Pins assignment -------------------------------------------------------------

const int ECHO_PIN = 9; // DYP-ME007 echo pin 
const int TRIG_PIN = 3; // DYP-ME007 trigger pin

// --- WaveHC data ----------------------------------------------------------------------------

#ifdef SOUND

SdReader card;    // This object holds the information for the card
FatVolume vol;    // This holds the information for the partition on the card
FatReader root;   // This holds the information for the volumes root directory
FatReader file;   // This object represent the WAV file for a pi digit or period
WaveHC wave;      // This is the only wave (audio) object, since we will only play one at a time

#endif

// --- LEDs support ----------------------------------------------------------------------------

const byte LED_NONE   = 0;
const byte LED_GREEN  = 1;
const byte LED_RED    = 2;
const byte LED_ORANGE = 3;

void setLED(byte leds) {
  digitalWrite(LED_R_PIN, leds & LED_RED); // LOW/HIGH assumed;
  digitalWrite(LED_G_PIN, leds & LED_GREEN);
}

// --- WaveHC support -------------------------------------------------------------------------

#ifdef SOUND

/*
 * Define macro to put error messages in flash memory
 */
#define error(msg) error_P(PSTR(msg))

/*
 * print error message and halt
 */
void error_P(const char *str) {
  PgmPrint("Error: ");
  SerialPrint_P(str);
  sdErrorCheck();
  while(1);
}
/*
 * print error message and halt if SD I/O error, great for debugging!
 */
void sdErrorCheck(void) {
  if (!card.errorCode()) return;
  PgmPrint("\r\nSD I/O error: ");
  Serial.print(card.errorCode(), HEX);
  PgmPrint(", ");
  Serial.println(card.errorData(), HEX);
  while(1);
}

void initWaveHC() {
  //  if (!card.init(true)) { //play with 4 MHz spi if 8MHz isn't working for you
  if (!card.init(1)) {         //play with 8 MHz spi (default faster!)  
    error("Card init. failed!");  // Something went wrong, lets print out why
  }
  
  // enable optimize read - some cards may timeout. Disable if you're having problems
//  card.partialBlockRead(true);
  card.partialBlockRead(false);
  
  // Now we will look for a FAT partition!
  uint8_t part;
  for (part = 0; part < 5; part++) {   // we have up to 5 slots to look in
    if (vol.init(card, part)) 
      break;                           // we found one, lets bail
  }
  if (part == 5) {                     // if we ended up not finding one  :(
    error("No valid FAT partition!");  // Something went wrong, lets print out why
  }
  
  // Lets tell the user about what we found
  PgmPrint("Using partition "); Serial.print(part, DEC);
  PgmPrint(", type is FAT"); Serial.println(vol.fatType(), DEC);     // FAT16 or FAT32?
  
  // Try to open the root directory
  if (!root.openRoot(vol)) {
    error("Can't open root dir!");      // Something went wrong,
  }
  
  // Whew! We got past the tough parts.
  putstring_nl("Files found (* = fragmented):");

  // Print out all of the files in all the directories.
  root.ls(LS_R | LS_FLAG_FRAGMENTED);  
}

#endif

boolean soundOff = false;
boolean debugSound = false;
byte curWave = 0;

const byte WAVE_CRYSTAL = 1;
const byte WAVE_BENHILL = 2;

void stopPlaying() {
#ifdef SOUND
  if (wave.isplaying) {// already playing something, so stop it!
    if (serialDebug) {
      PgmPrintln("Stop playing...");
    }
    wave.stop(); // stop it
  }
#endif
  curWave = 0;
}

void playfile(const char *name) {
#ifdef SOUND
  stopPlaying();
  if (!file.open(root, name)) {
    if (serialDebug) {
      PgmPrint("Couldn't open file "); Serial.println(name); 
    }
    return; 
  }
  if (serialDebug) {
    PgmPrint("Playing - "); Serial.println(name); 
  }
  
  if (soundOff)
    return;
  
  if (!wave.create(file)) {
    if (serialDebug) {
      PgmPrintln("Not a valid WAV");
    }
    return;
  }
  // ok time to play!
  wave.play();
#endif
}

void playAndWait(const char *name) {
  playfile(name);
#ifdef SOUND
  while (wave.isplaying) {// playing occurs in interrupts, so we print dots in realtime
    if (serialDebug) {
      putstring(".");
    }
    delay(50);
  }       
  if (serialDebug) {
    Serial.println();
  }
#endif
}

// --- Saying numbers support  ----------------------------------------------------------------

void sayNumber(int num) {
  if (num == 0) {
    playAndWait("0.wav");
    return;
  }
  if (num < 0) {
    playAndWait("-.wav");
    num = -num;
  }
  byte a = num / 100;
  num -= a*100; // 0..99;
  switch (a) {
    case 1: playAndWait("100.wav"); break;
    case 0: break; // TODO delete after copying 200..900;
    case 2: playAndWait("2.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 3: playAndWait("3.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 4: playAndWait("4.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 5: playAndWait("5.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 6: playAndWait("6.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 7: playAndWait("7.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 8: playAndWait("8.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
    case 9: playAndWait("9.wav"); playAndWait("100.wav"); break; // TODO delete after copying 200..900;
/*
    case 2: playAndWait("200.wav"); break;
    case 3: playAndWait("300.wav"); break;
    case 4: playAndWait("400.wav"); break;
    case 5: playAndWait("500.wav"); break;
    case 6: playAndWait("600.wav"); break;
    case 7: playAndWait("700.wav"); break;
    case 8: playAndWait("800.wav"); break;
    case 9: playAndWait("900.wav"); break; */
  }
  a = num / 10;
  num -= a*10;
  switch (a) {
    case 1: {
      switch (num) {
        case 0: playAndWait("10.wav"); return;
        case 1: playAndWait("11.wav"); return;
        case 2: playAndWait("12.wav"); return;
        case 3: playAndWait("13.wav"); return;
        case 4: playAndWait("14.wav"); return;
        case 5: playAndWait("15.wav"); return;
        case 6: playAndWait("16.wav"); return;
        case 7: playAndWait("17.wav"); return;
        case 8: playAndWait("18.wav"); return;
        case 9: playAndWait("19.wav"); return;
      }  
    } break;
    case 2: playAndWait("20.wav"); break;
    case 3: playAndWait("30.wav"); break;
    case 4: playAndWait("40.wav"); break;
    case 5: playAndWait("50.wav"); break;
    case 6: playAndWait("60.wav"); break;
    case 7: playAndWait("70.wav"); break;
    case 8: playAndWait("80.wav"); break;
    case 9: playAndWait("90.wav"); break;
  }
  switch (num) {
    case 1: playAndWait("1.wav"); break;
    case 2: playAndWait("2.wav"); break;
    case 3: playAndWait("3.wav"); break;
    case 4: playAndWait("4.wav"); break;
    case 5: playAndWait("5.wav"); break;
    case 6: playAndWait("6.wav"); break;
    case 7: playAndWait("7.wav"); break;
    case 8: playAndWait("8.wav"); break;
    case 9: playAndWait("9.wav"); break;
  }  
}

// --- IR Receiver Support  -------------------------------------------------------------------

IRrecv irrecv(RECV_PIN);

decode_results resultsIR;

long int prevKey = 0;
long int prevKeyMs = 0;
long int bufferedKey = 0;

// Dumps out the decode_results structure.
// Call this after IRrecv::decode()
// void * to work around compiler issue
//void dump(void *v) {
//  decode_results *results = (decode_results *)v
void dump(decode_results *results) {
  int count = results->rawlen;
  if (results->decode_type == UNKNOWN) {
    if (serialDebug) {
      PgmPrintln("Could not decode message");
      printBytes(results);
    }
  } 
  else {
    if (serialDebug) {
      if (results->decode_type == NEC) {
        PgmPrintln("Decoded NEC: ");
      } 
      else if (results->decode_type == SONY) {
        PgmPrintln("Decoded SONY: ");
      } 
      else if (results->decode_type == RC5) {
        PgmPrintln("Decoded RC5: ");
      } 
      else if (results->decode_type == RC6) {
        PgmPrintln("Decoded RC6: ");
      }
      Serial.print(results->value, HEX);
      PgmPrint(" (");
      Serial.print(results->bits, DEC);
      PgmPrintln(" bits)");
    }
  }
}

void printBytes(decode_results *results) {
  if (!serialDebug)
    return;
    
  int count = results->rawlen;

  PgmPrint("Raw (");
  Serial.print(count, DEC);
  PgmPrint("): ");

  for (int i = 0; i < count; i++) {
    if ((i % 2) == 1) {
      Serial.print(results->rawbuf[i]*USECPERTICK, DEC);
    } 
    else {
      Serial.print(-(int)results->rawbuf[i]*USECPERTICK, DEC);
    }
    PgmPrint(" ");
  }
  Serial.println();
}

// --- IR control keys ----------------------------------------------------------------------------------

// NEC remote
const long int KEY_INTENSITY_UP   = 0xFFA05F;
const long int KEY_INTENSITY_DOWN = 0xFF20DF;
const long int KEY_0_1_R          = 0xFF906F;
const long int KEY_0_2_G          = 0xFF10EF;
const long int KEY_0_3_B          = 0xFF50AF;
const long int KEY_0_4_W          = 0xFFD02F;
const long int KEY_OFF            = 0xFF609F;
const long int KEY_ON             = 0xFFE01F;
const long int KEY_1_1            = 0xFFB04F;
const long int KEY_1_2            = 0xFF30CF;
const long int KEY_1_3            = 0xFF708F;
const long int KEY_2_1            = 0xFFA857;
const long int KEY_2_2            = 0xFF28D7;
const long int KEY_2_3            = 0xFF6897;
const long int KEY_3_1            = 0xFF9867;
const long int KEY_3_2            = 0xFF18E7;
const long int KEY_3_3            = 0xFF58A7;
const long int KEY_4_1            = 0xFF8877;
const long int KEY_4_2            = 0xFF08F7;
const long int KEY_4_3            = 0xFF48B7;
const long int KEY_FLASH          = 0xFFF00F;
const long int KEY_STROBE         = 0xFFE817;
const long int KEY_FADE           = 0xFFD827;
const long int KEY_SMOOTH         = 0xFFC837;
const long int KEY_AUTOKEY        = 0xFFFFFFFF;

// SONY remote
const long int KEY_PLAY           = 0x4D1;
const long int KEY_STOP           = 0x1D1;
const long int KEY_PAUSE          = 0x9D1;
const long int KEY_SKIP_LEFT      = 0xD1;
const long int KEY_SKIP_RIGHT     = 0x8D1;
const long int KEY_SCAN_LEFT      = 0x5D1;
const long int KEY_SCAN_RIGHT     = 0xDD1;

// --- IR control ----------------------------------------------------------------------------------

// this function will return the number of bytes currently free in RAM
// written by David A. Mellis
// based on code by Rob Faludi http://www.faludi.com
int check_mem() {
  int size = 2048; // Use 2048 with ATmega328
  byte *buf;
  while ((buf = (byte *) malloc(--size)) == NULL);
  free(buf);
  return size;
}

boolean checkIR() {
  if (bufferedKey != 0)
    return true;
    
  if (!irrecv.decode(&resultsIR))
    return false;

//  PgmPrint("Free RAM: "); Serial.println(check_mem(), DEC);  

  // Maybe is may be omitted ?
  if (resultsIR.decode_type == UNKNOWN) {
    resultsIR.value = 0;
  }

  setLED(LED_ORANGE); // Display receiving the IR key;

  dump(&resultsIR);

  if (resultsIR.value != 0) {
    // Handle auto key - replace it with previous key;
    if (resultsIR.value == KEY_AUTOKEY) { // Have valid previous key and got auto repeat command;
      PgmPrint("got AUTO...");
      if (prevKey != 0) {
        if (millis()-prevKeyMs >= 200) { // Auto repeat can be disregarded;
          PgmPrint("long "); Serial.println(millis()-prevKeyMs, DEC);
          prevKey = 0;
          continueIR();
        } else {
          PgmPrintln("SHORT");
          prevKeyMs = millis(); // Refresh validity period for the last key;
        }
      } else { // Auto without its key; 
        PgmPrintln("prev==0");
        continueIR();
      }
    } else {
      PgmPrintln("Got key.");
      prevKey = resultsIR.value; // Store the last key;
      prevKeyMs = millis(); // Start validity period for the last key;
    }
  } else {
    PgmPrintln("No key.");
    prevKey = 0; // Error;
    continueIR();
  }

  bufferedKey = prevKey;

  setLED(LED_NONE); // Turn off LEDs;
  return (bufferedKey != 0);  
}

void continueIR() {
  irrecv.resume(); // Receive the next value  
  bufferedKey = 0;
}

long oldRemoteKey = 0;
long oldRemoteKeyTime = 0;

void preventFastAutoRepeat() { 
  if (bufferedKey == oldRemoteKey) { // If the same key received;
    PgmPrint("same "); Serial.print(bufferedKey, HEX); PgmPrint(", "); Serial.println(millis()-oldRemoteKeyTime, DEC);
    if (millis()-oldRemoteKeyTime < 200) { // Time is less that 200ms - skip such event;
      bufferedKey = 0;
      return; // Do not reset oldRemoteKeyTime;
    }
  } else { // New key received; Store it;
    oldRemoteKey = bufferedKey; 
  }
  oldRemoteKeyTime = millis();
}

// --- Motors support --------------------------------------------------------------------

const int MIN_PWM = 90;
const int MAX_PWM = 255;
const int PWM_FINE_TUNE = -15; // Straight path correction; > 0 = do rotate to right; < 0 = do rotate to left;

const int MAX_SPEED = MAX_PWM-MIN_PWM;
const int JITTER_SPEED = MAX_SPEED/4;

int speedToPWM(int spd) {
  spd = constrain(spd, -MAX_SPEED, MAX_SPEED); 
  if (spd < 0)
    spd -= MIN_PWM;
  else
  if (spd > 0)
    spd += MIN_PWM;
  return spd;  
}

static int speed_A=0, speed_B=0;

byte getAbsSpeed() {
  return (byte) ((abs(speed_A)+abs(speed_B))/2);  
}

int getTurningSign() {
  int turning = (speed_A-speed_B);     
  if (turning == 0)
    return 0;
  else if (turning < 0)
    return -1;
  else
    return 1;
}

const int SPEED_2 = MAX_SPEED/2;
const int SPEED_3 = MAX_SPEED/3;
const int SPEED_STEP = MAX_SPEED/10;

byte soundLock = 0;

void setSpeed(int speedA, int speedB) {
  byte dirA, dirB;
  byte pwmA, pwmB;
  boolean wasStopped = getAbsSpeed() == 0;
  int wasTurning = getTurningSign();
  int speedCorrA, speedCorrB;

  speed_A = speedA; 
  speed_B = speedB; 
  
  // Do rotation correction;
  if (PWM_FINE_TUNE != 0 && speed_A != 0 && speed_B != 0) {
    int corr = (speed_A > 0) ? PWM_FINE_TUNE : -PWM_FINE_TUNE;
    speedCorrA = speed_A + corr;
    speedCorrB = speed_B - corr;
  } else {
    speedCorrA = speed_A;
    speedCorrB = speed_B;
  }

  int pwmSpeedA = speedToPWM(speedCorrA);
  int pwmSpeedB = speedToPWM(speedCorrB);
  
  if (pwmSpeedA >= 0) {
    dirA = LOW;
    pwmA = pwmSpeedA;
  } else {
    dirA = HIGH;
    pwmA = 255+pwmSpeedA;    
  }

  if (pwmSpeedB >= 0) {
    dirB = LOW;
    pwmB = pwmSpeedB;
  } else {
    dirB = HIGH;
    pwmB = 255+pwmSpeedB;    
  }

  if (serialDebug) {
    PgmPrint("SpA="); Serial.print(speed_A, DEC); PgmPrint(", SpdB="); Serial.print(speed_B, DEC);
    PgmPrint(", coA="); Serial.print(speedCorrA, DEC); PgmPrint(", coB="); Serial.print(speedCorrB, DEC);
    PgmPrint(", dirA="); Serial.print(dirA, DEC); PgmPrint(", pwmA="); Serial.print(pwmA, DEC);
    PgmPrint(", dirB="); Serial.print(dirB, DEC); PgmPrint(", pwmB="); Serial.print(pwmB, DEC);
    Serial.println();
  }

  digitalWrite(dir_a, dirA);
  analogWrite(pwm_a, pwmA);            
  digitalWrite(dir_b, dirB);
  analogWrite(pwm_b, pwmB);              
  
  if (soundLock == 0) {
    byte absSpeed = getAbsSpeed();
    if (wasStopped && (getTurningSign() == 0) && absSpeed > 0) {
      if (absSpeed > SPEED_2)
         playfile("SPEED.wav");
      else
         playfile("START.wav");      
    } else
    if ((getTurningSign() != 0) && (wasTurning != getTurningSign())) {
      if (absSpeed > SPEED_2)
         playfile("TURN.wav");
      else 
         playfile("TURN1.wav");
    } else
    if (!wasStopped && absSpeed == 0) {
       playfile("BREAKS.wav");
    }
  }
}

void motorsOff() {
  if (serialDebug) {
    PgmPrintln("Motors off...");
  }

  digitalWrite(dir_a, LOW);
  digitalWrite(dir_b, LOW);
  analogWrite(pwm_a, 0);            
  analogWrite(pwm_b, 0);            

  if (soundLock == 0) {
    byte absSpeed = getAbsSpeed();    
    if (absSpeed > MAX_SPEED-5)
       playfile("BRAKES1.wav");
    else
    if (absSpeed > SPEED_2)
       playfile("BRAKES2.wav");
    else
    if (absSpeed > 0)
       playfile("BREAKS.wav");
  }
  speed_A = 0; speed_B = 0;
}

int savedSpeedA = 0, savedSpeedB = 0;

// Save speed;
void saveSpeed() {
  if (serialDebug) {  
    PgmPrint("Save SpeedA="); Serial.print(speed_A, DEC); PgmPrint(", SpeedB="); Serial.println(speed_B, DEC);
  }
  savedSpeedA = speed_A;
  savedSpeedB = speed_B;
}

void restoreSpeed() {
  if (serialDebug) {
    PgmPrint("Restore SpeedA="); Serial.print(savedSpeedA, DEC); PgmPrint(", SpeedB="); Serial.println(savedSpeedB, DEC);
  }
  setSpeed(savedSpeedA, savedSpeedB);
}

// --- Light detector support -----------------------------------------------------------------

int getLightLevel() {
  int lightLevel = 1023-analogRead(LIGHT_DETECTOR_PIN); // more intensity - lower value -> more intensity - greater value;
  // It does not require any filtering;
//  PgmPrint("Light="); Serial.println(lightLevel, DEC); 
  return lightLevel;
}

// --- Ultrasound support ---------------------------------------------------------------------

const int MS_PER_CM = 44; // 58 / 1.3; 1.3 is a practically selected;

const int MAX_ZERO_RETRY_ATTEMPTS = 8;

int getDistance(int nLoops) {
#ifdef ULTRASOUND

  byte zeroAttempt = MAX_ZERO_RETRY_ATTEMPTS; // Retry if all zeroes;
  long int total = 0;
  for (byte i=0; i<nLoops; i++) {
    setLED(LED_GREEN);
    for (;;) {
      digitalWrite(TRIG_PIN, HIGH); // send 10 microsecond pulse
      delayMicroseconds(10); // wait 10 microseconds before turning off
      digitalWrite(TRIG_PIN, LOW); // stop sending the pulse

      long time = pulseIn(ECHO_PIN, HIGH, 50000L); // Look for a return pulse, it should be high as the pulse goes low-high-low;
      if (time > 0) { // no timeout;
        delay(29-time/1000); // 29000uS/58[us/cm]=500cm.  Maximum distance;
      }
      if (time >= MS_PER_CM || zeroAttempt == 0) {
        if (zeroAttempt < MAX_ZERO_RETRY_ATTEMPTS) {
          if (serialDebug) {
            PgmPrint("Dist="); Serial.println(time, DEC); 
          }
        }
        total += time;
        break;
      }

      // less than 1 cm distance;
      zeroAttempt--;
      if (serialDebug) {
        PgmPrint("Retry ms ");  Serial.println(time, DEC);
      }
      setLED(LED_RED);
    }
  }
  setLED(LED_NONE);
  int average = (int) (total/(MS_PER_CM*nLoops)); // Distance = pulse time / 58 to convert to cm.
//    PgmPrint("Distance="); Serial.println(average, DEC); 
  
  return average;
#else

  return 100;

#endif
}

// --- Setup ----------------------------------------------------------------------------------

void setup() {
// Start the serial;
  Serial.begin(SERIAL_COM_SPEED);    
  PgmPrintln("Hello!");

// Setup LEDs;
  pinMode(LED_R_PIN, OUTPUT);
  pinMode(LED_G_PIN, OUTPUT);

// Display initialization start - RED;
  setLED(LED_ORANGE);

// Setup Ultrasound;
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

// Setup Motor pins;
  pinMode(pwm_a, OUTPUT);  //Set control pins to be outputs
  pinMode(pwm_b, OUTPUT);
  pinMode(dir_a, OUTPUT);
  pinMode(dir_b, OUTPUT);

  analogWrite(pwm_a, 0);  
  analogWrite(pwm_b, 0);
  digitalWrite(dir_a, LOW);
  digitalWrite(dir_b, LOW);

// Debug info;
  PgmPrint("Check Mem: "); Serial.println(check_mem(), DEC);  
  PgmPrint("Free RAM: "); Serial.println(FreeRam());  
  
// Start WaveHC; dump SDCard file names;
#ifdef SOUND

  initWaveHC();

#endif

// Setup Light detector;
  pinMode(LIGHT_DETECTOR_PIN, INPUT);

// Start the IR Receiver;
  irrecv.enableIRIn(); 

// Display initialization end - GREEN;
  setLED(LED_GREEN);

  playAndWait("PERELIV.wav");

// Turn off the LED;
  setLED(LED_NONE);

  PgmPrintln("Init completed.");
}

// --- Serial support -------------------------------------------------------------------------

const char COMMAND_PREFIX = '>';
const char COMMAND_SUFFIX = '\n';
const int BUFFER_SIZE = 10;

const char COMMAND_ROBOT_RESET = 'R';
const char COMMAND_NO_DEBUG = 'N';
const char COMMAND_AVOIDANCE =  'A';
const char COMMAND_STOP = 'S';
const char COMMAND_TRANSPORT = 'T';
const int ZERO_SPEED = 500;

// Reset trick;
void(* resetFunc) (void) = 0; //declare reset function @ address 0

boolean checkSerial() {
  static char buf[BUFFER_SIZE];

  if (Serial.available() < 3) { // Minimum is Prefix, Command and Suffix;
    return false;
  }
  
  boolean ok = false;
  while (Serial.available()) {
    if ((char)Serial.read() == COMMAND_PREFIX) {
      ok = true;
      break;
    }
  }
  if (!ok) {
      return false;
  }
  
  // Command found - need to read it;
  byte i=0;
  buf[0] = 0; // Put 0 to be able recognize empty commands afterwards;
  ok = false;
  byte timeouts = 10;
  while (!ok) {

    while(Serial.available() && !ok) {
      char c = (char)Serial.read();
      if (c == COMMAND_SUFFIX) {
        buf[i] = 0; // Command read completely - stop reading port;
        ok = true;
      } else {
        if (i >= BUFFER_SIZE-1) { // One character reserved by 0;
          return false; // Buffer overrun error - return;
        }
        buf[i++] = c;
      }
    }
    
    // if data exchausted, but command is not fully received; 
    if (Serial.available() <= 0 && !ok) {
      if (timeouts == 0) {
        return false; // No more waiting time availabe;
      }
      delay(5); // Give time to all data arrive;
      timeouts--;
    }

  }
  
  if (buf[0] == 0) { // Not complete or zero-length command received - return;
    return false;
  }
  
  if (serialDebug) {
    PgmPrint("Command: "); Serial.println(buf);
  }
  
  // Parsing command;
  switch (buf[0]) {
     case COMMAND_ROBOT_RESET: {
       resetFunc(); // Soft reboot;
     } break;

     case COMMAND_AVOIDANCE: {
       if (strlen(buf) != 2) {
         return false; // wrong command length;
       }
       setAvoidance(buf[1] != '0');
     } break;

     case COMMAND_NO_DEBUG: {
       serialDebug = false;
     } break;

     case COMMAND_STOP: {
        motorsOff();
     } break;
      
     case COMMAND_TRANSPORT: {
       if (strlen(buf) != 8 || buf[4] != ',') {
         return false; // wrong command length;
       }
       // Read two 3-characters with ',' in between;
       int speedA = (buf[1]-'0')*100 + (buf[2]-'0')*10 + (buf[3]-'0') - ZERO_SPEED;
       int speedB = (buf[5]-'0')*100 + (buf[6]-'0')*10 + (buf[7]-'0') - ZERO_SPEED;
       setSpeed(speedA, speedB);
     } break;

     default: {
       return false; // Invalid command;
     }
  }

  return true;
}

// --- IR controller ----------------------------------------------------------------------------------------

boolean avoidance_enabled = 0;

void setAvoidance(boolean enabled) {
  playAndWait("avoid.wav"); 
  avoidance_enabled = enabled; 
  if (avoidance_enabled)
     playAndWait("yes.wav"); 
  else
     playAndWait("no.wav"); 
}

void processKey() {
  // SONY remote;
  switch(bufferedKey) {
  case KEY_PLAY:        { bufferedKey = avoidance_enabled ? KEY_OFF : KEY_ON; } break;
  case KEY_STOP:        { bufferedKey = KEY_2_2; } break;
  case KEY_PAUSE:       { bufferedKey = KEY_SMOOTH; } break;
  case KEY_SKIP_LEFT:   { bufferedKey = KEY_INTENSITY_DOWN; } break;
  case KEY_SKIP_RIGHT:  { bufferedKey = KEY_INTENSITY_UP; } break;
  case KEY_SCAN_LEFT:   { bufferedKey = KEY_2_1; } break;
  case KEY_SCAN_RIGHT:  { bufferedKey = KEY_2_3; } break;
  }

  // NEC remote;
  switch(bufferedKey) {
  case KEY_0_1_R: { setSpeed(-MAX_SPEED, MAX_SPEED); } break;
  case KEY_0_2_G: { setSpeed(MAX_SPEED, MAX_SPEED); } break;
  case KEY_0_3_B: { setSpeed(MAX_SPEED, -MAX_SPEED); } break;

  case KEY_1_1:   { setSpeed(-SPEED_2, SPEED_2); } break;
  case KEY_1_2:   { setSpeed(SPEED_2, SPEED_2); } break;
  case KEY_1_3:   { setSpeed(SPEED_2, -SPEED_2); } break;

  case KEY_2_1:   { setSpeed(speed_A-SPEED_STEP, speed_B+SPEED_STEP); } break;
  case KEY_2_2:   { motorsOff(); } break;
  case KEY_2_3:   { setSpeed(speed_A+SPEED_STEP, speed_B-SPEED_STEP); } break;

  case KEY_3_1:   { setSpeed(-SPEED_3, -SPEED_2); } break;
  case KEY_3_2:   { setSpeed(-SPEED_2, -SPEED_2); } break;
  case KEY_3_3:   { setSpeed(-SPEED_2, -SPEED_3); } break;

  case KEY_4_1:   { setSpeed(-SPEED_2, -MAX_SPEED); } break;
  case KEY_4_2:   { setSpeed(-MAX_SPEED, -MAX_SPEED); } break;
  case KEY_4_3:   { setSpeed(-MAX_SPEED, -SPEED_2); } break;

  case KEY_INTENSITY_UP:   { setSpeed(speed_A+SPEED_STEP, speed_B+SPEED_STEP); } break;
  case KEY_INTENSITY_DOWN: { setSpeed(speed_A-SPEED_STEP, speed_B-SPEED_STEP); } break;

  case KEY_ON:    { setAvoidance(true); } break;
  case KEY_OFF:   { setAvoidance(false); } break;
  
  case KEY_0_4_W: { 
                    // playAndWait("light.wav"); sayNumber(getLightLevel()); 
                    // delay(500); 
                    playAndWait("dist.wav"); sayNumber(getDistance(3));
                  } break;

  case KEY_FLASH: { stopPlaying(); soundOff = true; } break; 
  case KEY_STROBE:{ playfile("DROP.WAV"); soundOff = false; } break; 
  case KEY_FADE:  { if (!debugSound) {
                      playAndWait("yes.wav"); debugSound = true;
                    } else {
                      playAndWait("no.wav"); debugSound = false;
                    }
                  } break; 
  case KEY_SMOOTH:{  saveSpeed(); motorsOff(); rotate(MAX_SPEED, 180, 500); restoreSpeed(); } break; 
     }  
}

// --- Path findings  -----------------------------------------------------------------------------

const int MIN_DIST = 10;
const int MAX_DIST = 25;
const int MIN_SAFE_DIST = 35; // If robot founds distance less than that, it will rotate and repeat scan; 
const int FAR_DIST = 100; // If robot founds vector that long, it will go forward witout scan completion;

const byte DIST_AVG_LOOPS = 6;

const int MAX_SPEED_ROTATE_90_DEG_MS = 970;  // With maximum speed it rotates to 90 degrees in 650 ms.  

void rotate(int spd, int angle, int pauseMs) {
  int timeMs = (int) (((long)abs(angle))*MAX_SPEED_ROTATE_90_DEG_MS*MAX_SPEED/(90*spd));

  if (serialDebug) {
    PgmPrint("rotate angle="); Serial.print(angle, DEC); PgmPrint(", spd="); Serial.print(spd, DEC);
    PgmPrint(", timeMs="); Serial.println(timeMs, DEC);
  }

  if (angle > 0)
    setSpeed(spd, -spd); // turn right;
  else
    setSpeed(-spd, spd); // turn left;

  delay(timeMs); 
  motorsOff();

  if (pauseMs > 0)
    delay(pauseMs);
}

boolean handleClose() {
  soundLock++; // Turn off motor auto-sounds;

  // try to escape;  
  boolean escaped = false;
  for (byte i=0; i<10; i++) {
    if (serialDebug) {
      PgmPrint("-handleClose "); Serial.println(i, DEC);
    }
    setSpeed(-SPEED_3, -SPEED_3); // move back;
    delay(100);
    motorsOff();
    
    int dist = getDistance(DIST_AVG_LOOPS);
    if (serialDebug) {
      PgmPrint("Distance="); Serial.println(dist, DEC); 
    }
    if (debugSound)
      sayNumber(dist);

    if (dist > MIN_DIST) {
      escaped = true;
      break;
    }

    // check for IR or Serial;
    if (checkSerial() || checkIR()) {
      if (serialDebug) {
        PgmPrintln("got command");
      }
      soundLock--;
      return false;
    }

  }
  
  // if not escaped, rotate;
  if (!escaped) { // cannot move away, rotate to 180 deg.
    playAndWait("noesc.wav");
    rotate(MAX_SPEED, 180, 500);
  } else {
    playAndWait("esc.wav");
  }
  
  soundLock--;
  return true;
}

const int ROTATE_STEP_DEG = 90/10; // 9 deg.

boolean handleFar(int headDest) {
  soundLock++; // Turn off motor auto-sounds;
  
  // scan half a sector;
  rotate(MAX_SPEED, -90, 0); // to left;

  int maxDist = headDest;

  boolean rotated = false;
  
  while (true) {
    char maxDistI = 0;
    boolean farDistFound = false;

    int dist;
    for (char i=-10; i<=10; i++) {
      if (serialDebug) {
        PgmPrint("-scan "); Serial.println(i, DEC);
      }
      dist = getDistance(DIST_AVG_LOOPS);
      if (serialDebug) {
        PgmPrint("Distance="); Serial.println(dist, DEC); 
      }
      if (debugSound) {
        sayNumber(i); delay(500);
        sayNumber(dist);
      }
        
      if (dist > maxDist) {
        maxDist = dist;
        maxDistI = i;
      }            
  
      if (dist > FAR_DIST) {
        if (serialDebug) {
          PgmPrint("-found far "); Serial.println(dist, DEC);
        }
        playAndWait("L-REVERV.WAV");
        farDistFound = true;
        break;
      }
  
      if (i < 10) // Do not rotate for the last step;
        rotate(MAX_SPEED, ROTATE_STEP_DEG, 0); // 90/10=9 deg.
  
      // check for IR or Serial;
      if (checkSerial() || checkIR()) {
        if (serialDebug) {
          PgmPrintln("got command");
        }
        soundLock--;
        return false;
      }
    }
    
    if (maxDist < MIN_SAFE_DIST) {
        if (serialDebug) {
          PgmPrint("-no safe dist "); Serial.println(maxDist, DEC);
        }
        if (!rotated) { // Not rotated so far;
          maxDist = dist; // Set initial distance as farest;          
          rotated = true;
        } else {
          if (!noEscape()) { // Go crazy();
            soundLock--;
            return false;
          }
          rotated = false;
        }
        // Rotate more and continue doing scan;
        rotate(MAX_SPEED, ROTATE_STEP_DEG, 0); // 90/10=9 deg.
        continue; // Repeat scan for the next 180 deg.
    }
      
    if (!farDistFound) {    
      if (serialDebug) {
        PgmPrint("-rotate to "); Serial.println(maxDistI, DEC);
      }
      if (debugSound) {
        playAndWait("max.wav"); 
        sayNumber(maxDistI); delay(500);
        sayNumber(maxDist);
      }
      rotate(MAX_SPEED, -(10-maxDistI)*ROTATE_STEP_DEG, 500);
    }   

    break; // Escape from the loop;    
  }

  soundLock--;
  return true;
}

boolean noEscape() {
  playAndWait("PERELIV.wav"); // TODO

  rotate(MAX_SPEED, -360, 0);
  rotate(MAX_SPEED, 360, 0);

  for (byte i=0; i<4; i++) {
    setSpeed(JITTER_SPEED, JITTER_SPEED);
    delay(100);
    setSpeed(-JITTER_SPEED, -JITTER_SPEED);
    delay(100);
  }

  for (byte i=0; i<8; i++) {
    setSpeed(JITTER_SPEED, -JITTER_SPEED);
    delay(100);
    setSpeed(-JITTER_SPEED, JITTER_SPEED);
    delay(100);
  }
  motorsOff();

  playfile("crystal.wav"); 
  
  int sleepTime = random(250, 500); // 25..50 sec.
  if (serialDebug) {
    PgmPrint("sleepTime="); Serial.println(sleepTime, DEC);
  }
  for (int i=0; i<sleepTime; i++) {
      if (checkSerial() || checkIR()) {
        if (serialDebug) {
          PgmPrintln("got command");
        }
        return false;
      }
      delay(100);
  }

  playAndWait("PERELIV.wav"); // TODO

  return true;
}

// --- Main Loop ----------------------------------------------------------------------------------

void avoidance() {
  int dist = getDistance(DIST_AVG_LOOPS);
  if (dist > 0) { // ULTRASOUND is working;
    if (speed_A > 0 && speed_B > 0) { // It is moving ahead;
      boolean doRestore = false;
      if (dist <= MIN_DIST) { // too close;
        if (serialDebug) {
          PgmPrint("Distance="); Serial.println(dist, DEC); 
        }
        saveSpeed(); motorsOff(); doRestore = true; // Save speed;
        playAndWait("close.wav"); 
        if (debugSound)
          sayNumber(dist);
        if (!handleClose())
          return;
        dist = getDistance(DIST_AVG_LOOPS*2); // get updated after moving;
      }  
      if (dist <= MAX_DIST) { // search a way;
        if (serialDebug) {
          PgmPrint("Distance="); Serial.println(dist, DEC); 
        }
        if (!doRestore) {
          saveSpeed(); motorsOff(); doRestore = true; // Save speed;      
        }
        playAndWait("far.wav");
        if (debugSound)
          sayNumber(dist);
        if (!handleFar(dist))
          return;
      }
      if (doRestore)
        restoreSpeed();
    }    
  }  
}

/*
void sendStatus() {
  // mode=normal(N) | handleClose(C) | handleFar(F);
  // prefix=>
  // flags=avoidanceEnabled,debugModeEnabled;
  // avoidance settings=MIN_DIST, MAX_DIST, MIN_SAFE_DIST, FAR_DIST;
  // current distance=distance, retries;
  // current speed=speedA, speedB;
  // saved speed=_speedA, _speedB;
  // normal mode: <current speed>, <current distance>, <avoidance settings>, <flags>;
  // handleClose mode: stepCount, <saved speed>, <current distance>, <avoidance settings>, <flags>;
  // handleFar: currentAngle, maxDist, maxDistAngle, <current distance>, <avoidance settings>, <flags>;
  // files list=file1,file2,file3,...,fileN;
}

void handleCommand() {
  // set debugMode=0|1;
  // set avoidance=0|1;
  // set MIN_DIST=n;
  // set MAX_DIST=n;
  // set MIN_SAFE_DIST=n;
  // set FAR_DIST=n;
  // set speed=speedA,speedB;
  // enumerate files;
  // play file;
} 
*/

long prevTimeMs = 0; // Time when distance was checked;

void loop() {
  if (checkSerial())
    return;

  if (checkIR()) {
    preventFastAutoRepeat();
    processKey();
    continueIR();
    return;
  }

  if (millis()-prevTimeMs > 50) {
    if (avoidance_enabled)
      avoidance();
    prevTimeMs = millis(); // get time after all;
  }

#ifdef SOUND

  if (!soundOff) {
    // PgmPrint("as="); Serial.print(getAbsSpeed(), DEC);  PgmPrint("p="); Serial.print(wave.isplaying, DEC); PgmPrint(", w="); Serial.println(curWave, DEC);
    if (getAbsSpeed() > 0) {
      if (!wave.isplaying) {
         playfile("BENHILL.wav");
         curWave = WAVE_BENHILL;
      }
    } else {
      if (wave.isplaying && (curWave == WAVE_BENHILL))
          stopPlaying();
          
      if (getLightLevel() < 100) {
        if (!wave.isplaying) {
          playfile("crystal.wav"); 
          curWave = WAVE_CRYSTAL;
        }
      } else {
        if (curWave == WAVE_CRYSTAL)
          stopPlaying();
      }
    }  
  }
#endif

}

