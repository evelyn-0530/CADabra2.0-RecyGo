# Arduino Control System

## Description

This folder contains the Arduino code used to control the RecyGo physical prototype.

The Arduino receives sorting commands from the Python YOLO system and controls the output devices and sorting mechanism. It also reads the ultrasonic sensor to monitor bin fill level.

## Files Included

```text
Arduino_Control/
├── README.md
└── arduino_control.ino
```

## Hardware Used

- Arduino UNO
- Stepper motor
- ULN2003 stepper motor driver
- Servo motor
- Ultrasonic sensor
- 16x2 LCD display with I2C module
- Active buzzer
- External 5V power supply if needed

## System Function

The Arduino system performs the following tasks:

1. Receives waste category command from Python through Serial communication.
2. Displays the detected category on LCD.
3. Activates buzzer feedback.
4. Moves the stepper motor to the selected bin position.
5. Activates the servo-driven pusher mechanism.
6. Releases waste into the correct bin.
7. Returns the carrying box to the home position.
8. Reads ultrasonic sensor data to estimate bin fullness.
9. Displays bin full warning when needed.

## Input

The Arduino receives:

```text
PAPER
PLASTIC
METAL
GENERAL
```

from the Python YOLO classification code.

It also receives distance readings from the ultrasonic sensor.

## Output

The Arduino controls:

- LCD display
- Buzzer
- Stepper motor
- Servo motor
- Bin full alert display

## Example Sorting Flow

Example for plastic waste:

```text
PLASTIC command received
→ LCD displays "PLASTIC"
→ Stepper moves carrying box to plastic bin position
→ Servo pusher activates
→ Waste is released into plastic bin
→ Pusher retracts
→ Stepper returns to home position
```

## How to Use

1. Open `arduino_control.ino` in Arduino IDE.
2. Connect Arduino UNO to the laptop.
3. Select the correct board:

```text
Tools → Board → Arduino UNO
```

4. Select the correct COM port:

```text
Tools → Port
```

5. Upload the code to Arduino.
6. Run the Python YOLO code to send sorting commands.

## Serial Communication

The Arduino receives text commands through Serial communication at the baud rate defined in the code.

The command sent from Python should end with a newline character:

```text
PAPER\n
PLASTIC\n
METAL\n
GENERAL\n
```

## Notes

- The stepper motor position values may need calibration depending on the physical prototype size.
- The servo movement timing may need adjustment depending on the pusher travel distance.
- All electronic components should share a common ground.
- For stable operation, servo and stepper motor may require an external 5V power supply.
- The system is designed for low-voltage prototype operation.

## Purpose in RecyGo System

The Arduino control system links the AI classification result to the physical sorting mechanism. It allows the prototype to automatically sort waste based on the confirmed YOLO output.
