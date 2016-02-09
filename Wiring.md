## WaveHC library (Wave and SD card modules) ##

// SPI port for SD card module;
// (As defined in Arduino sketch);
  * #define SS\_PIN 10
  * #define MOSI\_PIN 11
  * #define MISO\_PIN 12
  * #define SCK\_PIN 13

By default, the WaveHC library is configured to use pins 10 (for SD card) and pins 2, 3, 4 and 5 for the DAC.

It was changed as following: for 2->9, 3->7,4->6,5->8

## Wiring overview ##

### Abbrevations ###

  * MOT = Motor board
  * BT = BlueTooth Serial Adaptor
  * IR = TSOP InfraRed Receiver
  * Ultrasound = Ultrasound Range Sensor module
  * DAC = Wave Playing module
  * SD = SD Card module

### Pins wiring ###

  * D0=PD0=RX ---- BT, RX
  * D1=TX ---- BT, TX
  * D2=INT0 ---- IRPin
  * D3=INT1, PWM2---- Ultrasound TRIG
  * D4= ---- DAC\_CS
  * D5=PWM0, ---- MOT\_LEFT
  * D6=PWM0, ---- MOT\_RIGHT
  * D7= ---- DAC\_SCK
  * D8= ---- DAC\_SDI
  * D9=PWM1 ---- Ultrasound ECHO
  * D10=SS, PWM1 ---- SD\_CS
  * D11=MOSI, PWM2---- SD\_IN
  * D12=MISO ---- SD\_OUT
  * D13=SCK ---- SD\_CLK

  * A0=14 ---- MOT\_DIR\_LEFT
  * A1=15 ---- MOT\_DIR\_RIGHT
  * A2=16 ---- Light detector with pull-up 100k;
  * A3=17 ---- LED\_R
  * A4=18 ---- LED\_G
  * A5=19 ----
  * A6=20 ----
  * A7=21 ----

  * GND ---- DAC\_LATCH, DAC\_GND, SD\_GND, MOT\_GND, Ultrasound\_GND, IR\_GND
  * VCC ---- DAC\_VCC, SD\_VCC, Ultrasound\_VCC, IR\_VCC, LIGHT\_pull\_up