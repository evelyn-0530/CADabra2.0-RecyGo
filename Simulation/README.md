# Digital Simulation

## Description

This folder contains the Python digital simulation code for the RecyGo project.

The simulation models an urban district with 500 households and 20 commercial units over a 30-day period. It compares a baseline waste collection system with the RecyGo AI-enabled system.

## Files Included

```text
Digital_Simulation/
├── README.md
├── simulation_final.py
├── requirements.txt
└── simulation_results.png
```

## Simulation Purpose

The purpose of the simulation is to evaluate how RecyGo could perform at an urban scale beyond the physical prototype.

The simulation measures whether AI classification and smart bin monitoring can improve waste management performance compared to a traditional fixed-schedule collection system.

## Simulation Scope

The simulation represents:

```text
500 households
20 commercial units
30 days
```

## Scenarios Compared

### 1. Baseline System

The baseline system represents a traditional waste management method.

It includes:

- No AI classification
- Manual sorting behavior
- Fixed-schedule waste collection
- Higher recycling contamination
- Higher chance of bin overflow

### 2. RecyGo AI-Enabled System

The RecyGo system represents the proposed smart recycling system.

It includes:

- AI waste classification
- Smart bin fill-level monitoring
- Threshold-based collection
- Lower recycling contamination
- Reduced overflow incidents

## KPIs Measured

The simulation evaluates the following key performance indicators:

- Overflow incidents
- Collection trips
- Recycling accuracy
- CO₂ emissions
- Statistical comparison using t-test

## Requirements

Install the required Python libraries using:

```bash
pip install -r requirements.txt
```

The `requirements.txt` file contains:

```text
numpy
matplotlib
scipy
```

## How to Run

Make sure the following files are in the same folder:

```text
simulation_final.py
requirements.txt
```

Then run:

```bash
python simulation_final.py
```

If `python` is not recognized, use the full Python path:

```bash
"C:\Users\evely\AppData\Local\Programs\Python\Python313\python.exe" simulation_final.py
```

## Output

The simulation generates KPI results and a result chart.

Expected output file:

```text
simulation_results.png
```

The result chart includes:

- Cumulative overflow incidents
- Cumulative collection trips
- Recycling accuracy
- Total CO₂ emissions

## Reproducibility

The simulation uses fixed random seed values so that the results can be reproduced.

```python
random.seed(42)
np.random.seed(42)
```

## Main Results

The simulation results show that the RecyGo AI-enabled system can:

- Reduce overflow incidents
- Improve recycling accuracy
- Reduce CO₂ emissions
- Maintain efficient collection operation

## Notes

The simulation is a simplified model for evaluating the potential impact of RecyGo. The values and assumptions are used for prototype-level analysis and comparison between baseline and AI-enabled scenarios.

## Purpose in RecyGo System

The digital simulation supports the prototype by showing the possible urban-scale impact of the RecyGo system. It helps evaluate sustainability performance, collection efficiency, and recycling improvement.
