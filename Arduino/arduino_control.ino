/*
==========================================================
                RecyGo V5
         4 Bin Smart Waste Sorter
==========================================================

Waste Types
------------
1. Paper
2. Plastic
3. Metal
4. General

Sensors
------------
Paper Bin    -> HC-SR04 #1
General Bin  -> HC-SR04 #2

Author : Syasya
Version : V5.0
==========================================================
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Stepper.h>
#include <Servo.h>

/*========================================================
                    LCD
========================================================*/

LiquidCrystal_I2C lcd(0x27,16,2);

/*========================================================
                 STEPPER MOTOR
========================================================*/

const int STEPS_PER_REVOLUTION = 2048;

Stepper conveyor(STEPS_PER_REVOLUTION,2,4,3,5);

int currentPosition = 0;

// ---------- CALIBRATION ----------
// Change these after mechanical testing

const int PAPER_POSITION   = -3500;
const int PLASTIC_POSITION = -2500;
const int METAL_POSITION   = 3500;
const int GENERAL_POSITION = 2500;

/*========================================================
                     SERVO
========================================================*/

Servo pusher;

const byte SERVO_PIN = 6;

const int SERVO_FORWARD = 50;
const int SERVO_STOP    = 90;
const int SERVO_BACK    = 130;

const int PUSH_TIME = 2300;

/*========================================================
                     BUZZER
========================================================*/

const byte BUZZER_PIN = 7;

/*========================================================
                PAPER BIN SENSOR
========================================================*/

const byte PAPER_TRIG = 8;
const byte PAPER_ECHO = 9;

/*========================================================
               GENERAL BIN SENSOR
========================================================*/

const byte GENERAL_TRIG = 10;
const byte GENERAL_ECHO = 11;

/*========================================================
                 DISTANCE SETTINGS
========================================================*/

const int BIN_FULL_DISTANCE = 5;

/*========================================================
                  SYSTEM STATE
========================================================*/

enum SystemState
{
  READY,
  SORTING
};

SystemState state = READY;

/*========================================================
                  WASTE TYPE
========================================================*/

enum WasteType
{
  NONE,
  PAPER,
  PLASTIC,
  METAL,
  GENERAL
};

WasteType detectedWaste = NONE;

/*========================================================
               SERIAL COMMAND
========================================================*/

String command = "";

/*========================================================
                LCD ANTI FLICKER
========================================================*/

String lastLine1 = "";
String lastLine2 = "";

/*========================================================
                  LCD FUNCTION
========================================================*/

void showLCD(String line1,String line2)
{
  if(lastLine1==line1 && lastLine2==line2)
    return;

  lastLine1=line1;
  lastLine2=line2;

  lcd.clear();

  lcd.setCursor(0,0);
  lcd.print(line1);

  lcd.setCursor(0,1);
  lcd.print(line2);
}

/*========================================================
            ULTRASONIC FUNCTIONS
========================================================*/

float getDistance(byte trigPin, byte echoPin)
{
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);

  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000);

  if(duration == 0)
    return 999;

  return duration * 0.0343 / 2.0;
}

/*========================================================
                  BUZZER
========================================================*/

void detectBeep()
{
  for(int i=0;i<2;i++)
  {
    digitalWrite(BUZZER_PIN,HIGH);
    delay(200);

    digitalWrite(BUZZER_PIN,LOW);

    if(i<1)
      delay(200);
  }
}

/*========================================================
                STEPPER FUNCTIONS
========================================================*/

void moveToPosition(int targetPosition)
{
  int steps = targetPosition - currentPosition;

  conveyor.step(steps);

  currentPosition = targetPosition;
}

void returnHome()
{
  conveyor.step(-currentPosition);

  currentPosition = 0;
}

/*========================================================
                SERVO FUNCTION
========================================================*/

void pushWaste()
{
  // Push

  pusher.write(SERVO_FORWARD);
  delay(PUSH_TIME);

  // Stop

  pusher.write(SERVO_STOP);
  delay(300);

  // Return

  pusher.write(SERVO_BACK);
  delay(PUSH_TIME);

  // Stop

  pusher.write(SERVO_STOP);
}

/*========================================================
          PAPER BIN FULL CHECK
========================================================*/

void checkPaperBin()
{
  if(state == SORTING)
    return;

  float distance = getDistance(PAPER_TRIG, PAPER_ECHO);

  if(distance <= BIN_FULL_DISTANCE)
  {
    showLCD("Paper Bin","FULL!");

    delay(3000);

    showLCD("Ready","Standby");
  }
}

/*========================================================
        GENERAL BIN FULL CHECK
========================================================*/

void checkGeneralBin()
{
  if(state == SORTING)
    return;

  float distance = getDistance(GENERAL_TRIG, GENERAL_ECHO);

  if(distance <= BIN_FULL_DISTANCE)
  {
    showLCD("General Bin","FULL!");

    delay(3000);

    showLCD("Ready","Standby");
  }
}

/*========================================================
                SORT WASTE FUNCTION
========================================================*/

void sortWaste(WasteType waste)
{
  state = SORTING;

  int targetPosition = 0;
  String wasteName = "";

  switch(waste)
  {
    case PAPER:
      wasteName = "Paper";
      targetPosition = PAPER_POSITION;
      break;

    case PLASTIC:
      wasteName = "Plastic";
      targetPosition = PLASTIC_POSITION;
      break;

    case METAL:
      wasteName = "Metal";
      targetPosition = METAL_POSITION;
      break;

    case GENERAL:
      wasteName = "General";
      targetPosition = GENERAL_POSITION;
      break;

    default:
      return;
  }

  // Show detected waste
  showLCD(wasteName,"Detected");

  // Beep twice
  detectBeep();

  delay(500);

  // Show sorting status
  showLCD("Sorting...",wasteName);

  // Move to selected bin
  moveToPosition(targetPosition);

  delay(300);

  // Push object
  pushWaste();

  delay(300);

  // Return to home position
  returnHome();

  delay(300);

  // Ready again
  state = READY;

  detectedWaste = NONE;

  showLCD("Ready","Standby");
}

/*========================================================
            PROCESS SERIAL COMMAND
========================================================*/

void processCommand()
{
  if(command == "PAPER")
  {
    Serial.println("Received: PAPER");
    sortWaste(PAPER);
  }

  else if(command == "PLASTIC")
  {
    Serial.println("Received: PLASTIC");
    sortWaste(PLASTIC);
  }

  else if(command == "METAL")
  {
    Serial.println("Received: METAL");
    sortWaste(METAL);
  }

  else if(command == "GENERAL")
  {
    Serial.println("Received: GENERAL");
    sortWaste(GENERAL);
  }

  else
  {
    Serial.println("Unknown Command");
  }

  Serial.println("READY");
}

/*========================================================
              SERIAL COMMUNICATION
========================================================*/

void checkSerial()
{
  if(Serial.available())
  {
    command = Serial.readStringUntil('\n');

    command.trim();

    command.toUpperCase();

    if(state == READY)
    {
      processCommand();
    }
  }
}

/*========================================================
                      SETUP
========================================================*/

void setup()
{
  Serial.begin(9600);

  // LCD
  lcd.init();
  lcd.backlight();

  // Stepper
  conveyor.setSpeed(10);

  // Servo
  pusher.attach(SERVO_PIN);
  pusher.write(SERVO_STOP);

  // Buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Paper Sensor
  pinMode(PAPER_TRIG, OUTPUT);
  pinMode(PAPER_ECHO, INPUT);

  // General Sensor
  pinMode(GENERAL_TRIG, OUTPUT);
  pinMode(GENERAL_ECHO, INPUT);

  showLCD("Ready","Standby");

  Serial.println("==============================");
  Serial.println("      RecyGo V5");
  Serial.println("==============================");
  Serial.println("Commands:");
  Serial.println("PAPER");
  Serial.println("PLASTIC");
  Serial.println("METAL");
  Serial.println("GENERAL");
  Serial.println("==============================");
  Serial.println("READY");
}

/*========================================================
                       LOOP
========================================================*/

void loop()
{
  // Monitor Paper Bin
  checkPaperBin();

  // Monitor General Bin
  checkGeneralBin();

  // Listen for YOLO command
  checkSerial();

  delay(50);
}



