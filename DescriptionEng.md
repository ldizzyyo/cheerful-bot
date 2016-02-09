# Introduction #

I normally spend pretty much time doing some RC and FPV stuff, mostly flying RC planes and multi-copters. One time my children started a _discussion_, how it would be nice to make a robot instead, that would not fly far aways, but will crawl around feet instead. I selected **Arduino** as a platform, and bought almost all needed modules in goodluckbuy. Development on Arduino is rather easy, debugging is performed via serial terminal, flashing LEDs, beeping, LCD etc.

Robot is made on small tank chassis, and has sound module, capable to play WAV files from SD card. It has ultrasound rangefinder, some LEDs, light sensor, IR receiver, Bluetooth module and motors driver.

It can be controlled by IR from virtually any remote control. But the main mode is autonomous movement with obstacles avoiding. It is really impressive, how the cheerful bot plots its way through surroundings.

Finally, I developed a small **Android** appication to control the robot, which uses accelerometers and touch screen, so it is targeted to be used on phone.

# Details #

## Hardware ##

### Chassis ###

Basically, the robot is built on small plastic tank chassis with two motors, powering via 6V BEC from 7.4V 2s LiPo battery. Motors are driven with PWM via dual H-bridge modules.

### Brain ###

The brain is Arduino Nano board, powered directly from LiPo to Vin pin. Its 5V output feeds all other on-board modules (only H-bridge driver has its own 5V source). Arduino is inserted into small breadboard, to which all other wires are plugged in. It turned out very handy and nothing was accidentally detached so far. Almost all wires were made by me, but it is wise to buy them also (male-female type).

### Sound and speech ###

For playing sounds and saying I use Wave module. It can play WAV file in PCM Mono format with sampling frequency up to 22 kHz. Files are read from SD card via SD module. SD card is formatted in FAT 16. Because Wave module output is too weak (you can barely hear it in headphones), I made a simple amplifier on LM387 op-amp, right by the datasheet. But again, it is possible to buy one instead.

With those modules, the robot can play sounds, music, speak, especially speak numbers, which is very useful for debugging :-)

### Obstacle avoidance ###

Speech alone is not enough to make robot look like a "living being" - it should behave as a sapient. That robot can navigate through world full of obstacles with ultrasound sonar (rangefinder). We (RC guys) use these sonars on multicopters to maintain desired altidude and perform automatic landing. It is a nice device, but it has some fundamental issues, which will be addressed below.

### Manual control ###

In manual mode the robot is controllable in two ways: with IR remote control (from TV and such) and via Bluetooth.

#### IR remote control ####

I found a remote control for RGB lamp, which was lying around, as a perfect option, because it has a lot of unnamed colored buttons and is very compact and slim. Actually, almost any IR remote control can be used, taking into account two conditions:

  * Carrier frequency of the remote control should match the receiver. Normally, TSOP receivers, which you can buy, are tuned on 38 kHz, but there are some exceptions.

  * You will need to determine IR control codes for each button of your remote (use utility sketch in IRremote Arduino library) and map these codes to actions in the robot's sketch. It is pretty easy, but prepare to write some boring hexadecimal numbers :-) Keep in mind, that IRremote library, which is used in the project, may be not able to decode some specific protocols.

IR commands, which robot understands now, are:

  * different speeds and turns,
  * speed increment/decrement,
  * fast 180 degrees turn,
  * speech debugging enable/disable,
  * silent mode,
  * avoidance enable/disable,
  * say distance,
  * more may be added if keys are available;

#### Bluetooth remote control ####

Bletooth serial port on 115200 bits per second enables robot control from PC and from mobile phone (i.e. Android phone, but the application may be obviously made for iPhone or almost any phone with Java ME).

Bluetooth module, which I bought, was locked to another speed, so it is needed to set it up to 115200. Use the module instructions to find out how to do it. You may need to use USB to serial converter or write a small sketch in Arduino and let it to setup the module. Once baudrate is changed, no future actions are needed in respect of the Bluetooth module.

Instead of Bluetooth serial, it is possible to sent the commands via USB to serial Arduino connector, right from Arduino IDE. It is a good choice for debugging, especially if your USB cable is long enough, because this thing always tries to run away.

Serial commands, which robot understands now, are:

  * Set speed of each motor,
  * Stop,
  * Reboot,
  * Turn off debug output,
  * Avoidance enable/disable,
  * more can be added without limit;

#### Light sensor ####

The robot has a light sensor (photocell), which not involved too much for the moment. The only usage is: if robot is left turned on, but still, in total dark, it starts playing a gentle sorrowful melody (Crystal sorrow (c) by Vladimir Krasnov). Nice thing to do not forget to turn it off for night!

## Software ##

### Android ###

Android program to manually control the robot was written in one evening (honestly, one more evening was spent in debugging) without any experience in Android before. But, I have 15+ years of expirience in software development, so it helped a lot. As a prototype of it I used nice **blu\_car** application (Blu Car (c) 2011 Eirik Taylor). I changed UI slightly and added new control method. Speed and direction is controlled by tilting the phone, when touching a particular button on the screen. There are also emergency stop button, avoidance enable/disable button and obvously a button to connect a Blueooth device (the robot).

### Arduno ###

Development of the Arduino sketch - here the real fun was! Sometimes there is no more RAM space for variables, sometimes stack hits the heap... Finally I turned off one of the SD card read buffers and moved all static strings to EEPROM. No RAM worries so far...

The most interesting part of the program - obstacle avoidance - is implemented pretty unusual. If robot feels obstacle on close distance, it starts to scan distancies in forward semicircle. Next, it selects the longest available path and goes to its direction. But, if it founds a path long enough (more than predefined limit) during the scan, it immediately moves there. If the whole forward semicircle is blocked, scan continues to rear side.

If the obstacle is very close and may interfere turning, robot tries to pull back a bit, again and again, until the distance ahead is sufficient. But if obstacle is chasing (a curious cat, for example), robot finally will just rotate and move in backward direction.

In debug mode, which can be enabled from IR remote, robot says all distancies and rotage angles during scanning process.

In the robot program the following libraries are used:

  * IRremote (Copyright 2009 Ken Shirriff);
  * WaveHC (Copyright (C) 2008 by William Greiman)

## Sounds ##

In locomotion the robot does sound many and actively. It has sounds for acceleration and braking/turning of different intensity. Uniform movement is accompanied by cheerful melody. And it speaks by human voice about his problems. All sounds are written on SD card and uploaded.

## Easter eggs ##

If you will block robot in all directions, i.e. putting a wall around it, it will cool express itself.

## Known issues / Future plans ##

  * Ultrasound does not reflect from very soft materials (i.e. fabric curtain) and echo does not come to the receiver, and rangefinder does not see the obstacle. If the beam falls to a smooth surface at a sharp angle, it does not reflect to the receiver also, and even if it does, it comes after serie of other reflections, and measured disatnce will be unreally more than actuall distance is.

  * Also, the rangefinder is far above, and small obstacles may be left unnoticed. I am going to use additional short range IR sensor in the bottom to detect overcome these both sonar issues.

  * Maybe I will use a gyro to measure the exact rotational angle during scanning. Sometimes the surface under the tracks are too slippery, or some small thing can deflect the rotation. Gyro, used in turn, can help to perform it more precise.

  * To extend the control range and make more fun for children (and me!), install FPV system and replace Bluetooth by XBee modem (the modem itself maybe connected to phone via Bluetooth).

## Video ##

<a href='http://www.youtube.com/watch?feature=player_embedded&v=hglKhXwMHcs' target='_blank'><img src='http://img.youtube.com/vi/hglKhXwMHcs/0.jpg' width='425' height=344 /></a>

Audio is in Russian.