# RecyGo

Team: CADabra 2.0  
Competition: Southeast Asia Engineering Design Competition 2026  
Domain: Urban Waste & Recycling Management

## Project Overview

RecyGo is an AI-powered smart recycling system designed to improve urban waste and recycling management. The system classifies waste, sorts it automatically, monitors bin fill level, and rewards users through a mobile app.

The project combines hardware, artificial intelligence, mobile app development, and digital simulation to demonstrate a smart recycling solution that can support cleaner and more efficient urban waste management.

## System Modules

The RecyGo system includes five main modules:

1. **YOLO AI Classification**  
   Detects and classifies waste items using a trained YOLO model.

2. **Arduino Control System**  
   Controls the physical sorting mechanism, LCD display, buzzer, stepper motor, servo motor, and ultrasonic sensor.

3. **Physical Sorting Prototype**  
   Sorts waste into the correct bin using a conveyor-based carrying box and servo-driven pusher mechanism.

4. **RecyGo App**  
   Allows users to scan the bin QR code, track recycling activity, receive reward points, complete missions, and redeem reward cards.

5. **Digital Simulation**  
   Simulates an urban-scale waste management system and compares baseline collection with the RecyGo AI-enabled system.

## Folder Structure

```text
Source_Code/
├── App/
├── Arduino/
├── Simulation/
├── YOLO/
└── README.md
```

## System Workflow

1. User inserts waste into the prototype.
2. USB camera captures the waste item.
3. YOLO model classifies the waste type.
4. Python confirms the result after stable detection.
5. Python prepares the sorting command.
6. Arduino receives the confirmed command.
7. Stepper motor moves the carrying box to the correct bin position.
8. Servo-driven pusher releases the waste into the selected bin.
9. LCD and buzzer provide real-time feedback.
10. Ultrasonic sensor monitors bin fill level.
11. App updates reward points and mission progress.
12. Digital simulation evaluates the urban-scale impact of the system.

## Included Source Code

### RecyGo_App

Flutter mobile app source code for:

- User login
- Bin QR code scanning
- Bin connection
- Reward points
- Mission progress
- Reward card redemption
- Firebase Firestore integration

### Arduino_Control

Arduino source code for:

- Serial command receiving
- LCD status display
- Buzzer feedback
- Stepper motor control
- Servo motor pusher control
- Ultrasonic sensor bin monitoring

### Digital_Simulation

Python simulation code for:

- 500 households
- 20 commercial units
- 30-day simulation period
- Baseline vs RecyGo AI-enabled scenario
- KPI analysis

### YOLO_AI_Classification

Python YOLO code for:

- USB camera input
- Waste classification
- Stable output confirmation
- General waste fallback
- Arduino command preparation

## Important Security Note

Firebase private key files are not included for security reasons.

Do not upload or share:

```text
firebase_key.json
serviceAccountKey.json
.env
password files
API secret files
```

## General Requirements

Different modules require different software:

- Python 3 for YOLO and digital simulation
- Arduino IDE for Arduino control code
- Flutter SDK for the RecyGo app

Please refer to each module folder for specific setup and running instructions.

## Project Tagline

Sort smarter. Recycle better. Build greener cities.
