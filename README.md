# Ahenema manuscript figure codes

This package contains the MATLAB code for the manuscript figures.

## 1. `Ahenema_vGRF_Valid_Analysis.m`

Generates the normalized vertical ground-reaction-force ensemble image and the corresponding paired peak statistics.

Required input: `SPATIOTEMPORAL DATA(1).xlsx`, including the sheet `vgrf_interpolated` with columns `Subject`, `Sex`, `Condition`, `BW`, and `p1` to `p101`.

Run:

```matlab
report = Ahenema_vGRF_Valid_Analysis( ...
    'SPATIOTEMPORAL DATA(1).xlsx', ...
    'vGRF_AUDITED_RESULTS');
```

Main image outputs:

- `Figure_vGRF_Ensemble.png` (300 dpi)
- `Figure_vGRF_Ensemble.pdf` (vector)

## 2. `Ahenema_Kinematics_Figure_Complete14.m`

Generates the four-panel knee/ankle ensemble figure using the same 14 complete bilateral participants for every panel.

Required input: `Participant_Condition_Waveforms_101pts.csv` with columns `Participant`, `Condition`, `CoordinateKey`, `GaitPercent`, and `MeanAngle_deg`.

Run:

```matlab
report = Ahenema_Kinematics_Figure_Complete14( ...
    'Participant_Condition_Waveforms_101pts.csv', ...
    'KINEMATIC_FIGURE_RESULTS');
```

The script expects these complete-case participants: P3, P4, P5, P8, P12, P15, P16, P18, P20, P21, P23, P25, P35, and P37. It stops with an error if any participant, condition, coordinate, or one of the 101 gait-cycle points is missing. This safeguard prevents the older mixed-cohort figure from being reproduced and incorrectly labelled as n=14.

Main image outputs:

- `Figure_Kinematics_Complete14.png` (300 dpi)
- `Figure_Kinematics_Complete14.pdf` (vector)

Important: the waveform CSV in the earlier results package is incomplete (it contains only 12 participants, including P11, who is not part of the bilateral complete-case cohort). Export the full waveforms for the 14 participants listed above before running the corrected kinematic script.
