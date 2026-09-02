# YOLO AI Classification

## Description

This folder contains the YOLO-based waste classification code for the RecyGo prototype.

The system uses a trained YOLO model to detect waste items from a USB camera. The detection result is confirmed only after it remains stable for 2 seconds. After confirmation, the system prepares the Arduino sorting command and pauses detection while the sorting mechanism is moving.

## Files Included

```text
YOLO_AI_Classification/
├── README.md
├── best.pt
├── yolo_final.py
├── requirements.txt
└── training_results/
```

## Main Files

### `best.pt`

This is the trained YOLO model weight used for waste classification.

### `yolo_final.py`

This is the final YOLO detection code used during the RecyGo prototype demonstration.

### `requirements.txt`

This file lists the Python libraries required to run the YOLO detection code.

### `training_results/`

This folder contains YOLO training result files or screenshots.

## Detected Classes

The trained YOLO model detects:

- PAPER
- PLASTIC
- METAL

General waste is handled using Python decision logic. If the detection result is low-confidence or uncertain, the system sends the output to the GENERAL bin.

## System Logic

1. USB camera captures the waste item.
2. YOLO model detects the waste type.
3. Python selects the highest-confidence detection.
4. The result must remain stable for 2 seconds.
5. The confirmed result is converted into a sorting command.
6. Detection pauses for 30 seconds while the mechanism sorts the waste.
7. The camera reopens and waits for the next item.

## Requirements

Install the required Python libraries:

```bash
pip install -r requirements.txt
```

The `requirements.txt` file contains:

```text
ultralytics
opencv-python
numpy
```

If Arduino serial or Firebase integration is added, these libraries may also be used:

```text
pyserial
firebase-admin
```

## How to Run

Make sure these files are in the same folder:

```text
best.pt
yolo_final.py
requirements.txt
```

Run the code:

```bash
python yolo_final.py
```

If `python` is not recognized, use the full Python path:

```bash
"C:\Users\evely\AppData\Local\Programs\Python\Python313\python.exe" yolo_final.py
```

## Settings to Check

In `yolo_final.py`, check the camera index:

```python
CAMERA_INDEX = 1
```

If the USB camera cannot open, change it to:

```python
CAMERA_INDEX = 0
```

Also make sure the model file name matches the code:

```python
model = YOLO("best.pt")
```

## Output

The program displays a live camera detection window and prints the confirmed YOLO output, including:

```text
bin_id
waste_type
confidence
bin_target
arduino_command
points
status
timestamp
```

The Arduino command will be one of:

```text
PAPER
PLASTIC
METAL
GENERAL
```

## General Waste Logic

The YOLO model is trained mainly for:

```text
paper
plastic
metal
```

The GENERAL category is not directly trained as a separate class. Instead, the Python code handles uncertain or low-confidence detections as general waste.

This prevents the system from forcing uncertain objects into recyclable categories.

## Detection Stability Logic

The system does not immediately accept every detection. The same output must remain stable for 2 seconds before it is confirmed.

This helps reduce incorrect sorting caused by unstable camera detection.

## Mechanism Pause Logic

After one confirmed output, the program pauses detection for 30 seconds while the sorting mechanism moves.

This prevents repeated commands from being sent while the same item is still inside the prototype.

## Notes

The full training dataset is not included due to file size. The trained model weight and training results are included for prototype demonstration and source-code submission.

Private Firebase key files are not included.
