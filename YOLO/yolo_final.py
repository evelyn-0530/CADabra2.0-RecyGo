from ultralytics import YOLO
import cv2
import time
import json
import numpy as np

# ============================================================
# RecyGo YOLO Final Prototype Code
# ============================================================
# Function:
# 1. Load trained YOLO model
# 2. Open USB camera
# 3. Detect waste item
# 4. Confirm output only after stable detection
# 5. Pause detection while mechanism is sorting
# 6. Prepare Arduino command output
# ============================================================

# Load trained YOLO model
model = YOLO("best.pt")

BIN_ID = "BIN_001"

# Settings
CONF_THRESHOLD = 0.80
STABLE_REQUIRED_SECONDS = 2.0
MECHANISM_BUSY_SECONDS = 30.0

# USB camera index
CAMERA_INDEX = 1

WINDOW_NAME = "RecyGo YOLO Final Prototype"


def open_camera():
    cap = cv2.VideoCapture(CAMERA_INDEX)

    if not cap.isOpened():
        print(f"Camera {CAMERA_INDEX} cannot open. Try changing CAMERA_INDEX to 0 or 2.")
        return None

    return cap


def close_camera(cap):
    if cap is not None:
        cap.release()


def map_class_to_output(class_name, confidence):
    class_name = class_name.upper()

    # If YOLO detects something but confidence is low, send to GENERAL
    if confidence < CONF_THRESHOLD:
        return {
            "bin_id": BIN_ID,
            "waste_type": "unknown",
            "confidence": round(confidence, 2),
            "bin_target": "general",
            "arduino_command": "GENERAL",
            "points": 0,
            "status": "low_confidence",
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }

    if class_name == "PLASTIC":
        waste_type = "plastic"
        bin_target = "plastic"
        arduino_command = "PLASTIC"
        points = 2

    elif class_name == "PAPER":
        waste_type = "paper"
        bin_target = "paper"
        arduino_command = "PAPER"
        points = 2

    elif class_name == "METAL":
        waste_type = "metal"
        bin_target = "metal"
        arduino_command = "METAL"
        points = 2

    else:
        waste_type = "unknown"
        bin_target = "general"
        arduino_command = "GENERAL"
        points = 0

    return {
        "bin_id": BIN_ID,
        "waste_type": waste_type,
        "confidence": round(confidence, 2),
        "bin_target": bin_target,
        "arduino_command": arduino_command,
        "points": points,
        "status": "accepted",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }


# Open camera
cap = open_camera()
if cap is None:
    exit()


# Stable detection variables
candidate_command = None
candidate_start_time = None
candidate_output = None

confirmed_output = None

# Mechanism busy variables
is_mechanism_busy = False
busy_start_time = 0


while True:
    current_time = time.time()

    # ==================================================
    # MECHANISM BUSY MODE
    # Detection is paused while sorting mechanism moves
    # ==================================================
    if is_mechanism_busy:
        elapsed_busy_time = current_time - busy_start_time
        remaining_time = max(0, MECHANISM_BUSY_SECONDS - elapsed_busy_time)

        display_frame = np.zeros((480, 640, 3), dtype=np.uint8)

        cv2.putText(
            display_frame,
            "DETECTION PAUSED",
            (40, 80),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 0, 255),
            2
        )

        cv2.putText(
            display_frame,
            "MECHANISM SORTING WASTE",
            (40, 140),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.85,
            (0, 255, 255),
            2
        )

        cv2.putText(
            display_frame,
            f"Confirmed Output: {confirmed_output['arduino_command']}",
            (40, 200),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 255, 255),
            2
        )

        cv2.putText(
            display_frame,
            f"Next detection in: {remaining_time:.1f}s",
            (40, 260),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 0),
            2
        )

        cv2.imshow(WINDOW_NAME, display_frame)

        # After sorting time, reopen camera and resume detection
        if elapsed_busy_time >= MECHANISM_BUSY_SECONDS:
            print("\nMechanism ready. Reopening USB camera...")

            cap = open_camera()

            if cap is None:
                print("Cannot reopen camera.")
                break

            is_mechanism_busy = False

            candidate_command = None
            candidate_start_time = None
            candidate_output = None
            confirmed_output = None

            print("USB camera reopened. Waiting for next waste item.")

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

        continue

    # ==================================================
    # NORMAL DETECTION MODE
    # ==================================================
    ret, frame = cap.read()

    if not ret:
        print("Cannot read camera frame")
        break

    results = model(frame, conf=0.30)
    annotated_frame = results[0].plot()
    boxes = results[0].boxes

    object_detected = len(boxes) > 0

    # --------------------------------------------------
    # Nothing detected: keep waiting
    # Important: no detection is NOT general
    # --------------------------------------------------
    if not object_detected:
        candidate_command = None
        candidate_start_time = None
        candidate_output = None

        cv2.putText(
            annotated_frame,
            "Status: Waiting for waste item...",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 255, 255),
            2
        )

        cv2.putText(
            annotated_frame,
            "Current Detection: None",
            (20, 85),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (0, 255, 255),
            2
        )

        cv2.putText(
            annotated_frame,
            "Confirmed Output: -",
            (20, 125),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (255, 255, 0),
            2
        )

        cv2.imshow(WINDOW_NAME, annotated_frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

        continue

    # --------------------------------------------------
    # Object detected: choose highest confidence object
    # --------------------------------------------------
    best_box = max(boxes, key=lambda box: float(box.conf[0]))

    class_id = int(best_box.cls[0])
    confidence = float(best_box.conf[0])
    class_name = model.names[class_id]

    current_output = map_class_to_output(class_name, confidence)
    current_command = current_output["arduino_command"]

    # --------------------------------------------------
    # Stable detection logic
    # If command changes, reset timer
    # --------------------------------------------------
    if current_command != candidate_command:
        candidate_command = current_command
        candidate_start_time = current_time
        candidate_output = current_output
    else:
        candidate_output = current_output

    stable_time = current_time - candidate_start_time if candidate_start_time else 0

    # --------------------------------------------------
    # Confirm output after same result stays for 2 seconds
    # --------------------------------------------------
    if stable_time >= STABLE_REQUIRED_SECONDS:
        confirmed_output = candidate_output

        print("\nCONFIRMED YOLO OUTPUT:")
        print(json.dumps(confirmed_output, indent=4))

        # Arduino command output:
        # This command should match the Arduino sorting command.
        print(f"ARDUINO COMMAND: {confirmed_output['arduino_command']}")

        # If Arduino serial communication is added later, use:
        # arduino.write((confirmed_output["arduino_command"] + "\n").encode())

        # Close camera while mechanism sorts
        close_camera(cap)
        cap = None

        is_mechanism_busy = True
        busy_start_time = current_time

        print("Detection paused. Mechanism sorting waste...")

    # --------------------------------------------------
    # Display detection information
    # --------------------------------------------------
    cv2.putText(
        annotated_frame,
        f"Current Detection: {current_command}",
        (20, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    cv2.putText(
        annotated_frame,
        f"Confidence: {current_output['confidence']}",
        (20, 80),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (0, 255, 255),
        2
    )

    cv2.putText(
        annotated_frame,
        f"Stable Time: {stable_time:.1f}s / {STABLE_REQUIRED_SECONDS}s",
        (20, 120),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (0, 255, 255),
        2
    )

    cv2.putText(
        annotated_frame,
        "Confirmed Output: Waiting...",
        (20, 160),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (255, 255, 0),
        2
    )

    cv2.putText(
        annotated_frame,
        f"Status: {current_output['status']}",
        (20, 200),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (255, 255, 0),
        2
    )

    cv2.imshow(WINDOW_NAME, annotated_frame)

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break


if cap is not None:
    cap.release()

cv2.destroyAllWindows()
print("RecyGo YOLO final prototype program ended.")