# Team Atlas: Seizure Early-Warning System

A MATLAB pipeline that detects seizures in scalp EEG recordings of children and young adults, raises an alert when the risk stays high, and replays the result on a dashboard. It is built for low-cost, noisy recordings, such as those in clinics with few neurologists.

**What we claim:** seizure *detection* as an early-warning and screening aid for clinicians. We do not claim to predict seizures before they start, and every alert is meant to be checked by a clinician on the raw EEG.

**Event:** National Neuroscience Technology Hackathon 2026, Theme C (AI & Brain Data) · **Platform:** MATLAB R2026b

---

## For reviewers: start here

- **See the results without running anything:** open `Docs/AtlasSubmission.pdf` (or `Docs/AtlasSubmission.mlx` in MATLAB). Every table and figure is saved inside.
- **Demo video:** [link to the video]
- **Data and trained model:** [Google Drive link]. It holds the processed files, the feature tables and the final model (`rf_final.mat`). The raw recordings are the public CHB-MIT database (see section 8). Data are not stored in this repository because of their size.
- **Run it yourself:** set up as in section 4 with the Drive folder as `ATLAS_DATA`, then open the live script or run `AtlasDashboard`.

---

## 1. Results

Final test on two patients the model never saw (chb03, chb18), run once with the model and the alert threshold (0.4) locked beforehand.

| | chb03 | chb18 | Combined |
|---|---|---|---|
| Seizures detected | 7 of 7 | 5 of 6 | **12 of 13** |
| False alarms per hour | 2.19 (37 in 16.9 h) | 4.95 (77 in 15.5 h) | 3.5 (114 in 32.4 h) |
| Median alert delay after onset | 25 s | 15 s | 25 s (range 10 to 37.5 s) |
| AUC | 0.984 | 0.926 | |

- The model ranks windows well on unseen patients (AUC 0.93 to 0.98). The one missed seizure (chb18, file 30) is the shortest in the set, at about 32 s.
- False alarms are above the roughly one per hour we aimed for. The threshold was chosen on two other patients, and false alarm rates differ a lot between patients. We did not change it after seeing these results.
- **Robustness:** sensitivity stayed at 100% (chb03) and about 83% (chb18) with as few as 4 of 18 channels and with added noise down to 0 dB. The cost shows up as more false alarms (chb03: 2.1 per hour clean, 14.0 at 0 dB).

**How the model was chosen** (leave-one-patient-out AUC on the four training patients):

| Random Forest | chb05 | chb14 | chb01 | chb15 | Mean |
|---|---|---|---|---|---|
| Raw features | 0.828 | 0.784 | 0.274 | 0.603 | 0.622 |
| **Features rescaled within each patient** | **0.992** | **0.757** | **0.938** | **0.872** | **0.890** |

Rescaling every feature within each patient fixed a patient that the model had been ranking backwards (chb01, AUC 0.24 to 0.94).

---

## 2. How it works

1. **Raw data:** CHB-MIT Scalp EEG recordings (EDF files, 18 channels, 256 Hz) plus a summary file giving each seizure's start and end.
2. **Processed windows:** band-pass 0.5 to 40 Hz, cut into 5-second windows every 2.5 seconds, each labelled seizure (1) if at least half of it overlaps an annotated seizure, otherwise 0.
3. **Features:** 126 numbers per window: for each of the 18 channels, relative band power in five bands (delta, theta, alpha, beta, gamma), log line length and spectral entropy. Each feature is then rescaled within the patient (median and spread of that patient's own windows, no labels needed).
4. **Model:** a Random Forest (300 trees, minimum leaf size 20) gives a seizure risk score from 0 to 1 per window.
5. **Alert rule:** an alert fires when the risk is at or above **0.4** for **3 windows in a row**. The best possible delay is about 10 s.
6. **Evaluation:** sensitivity (seizures with an alert inside them), false alarms per hour (alerts outside any seizure), and latency (alert time minus onset). Always split by patient, never by window.

---

## 3. Try it on a new recording

No annotations are needed. Give it a patient's whole session (about an hour or more), because the rescaling uses the recording as that patient's baseline.

```matlab
R = scoreRecording('C:\path\to\session.edf', 'Name', 'patient01', ...
                   'OutDir', 'C:\reports', 'SaveForDashboard', true);
```

It prints the hours analysed, the alerts (time in seconds and hh:mm:ss, risk) and alerts per hour, saves `patient01_alerts.csv`, `patient01_windows.csv` and a risk plot, and with `SaveForDashboard` makes the recording available in the dashboard. Pass several EDF files of one patient as a cell array so they share one baseline.

We checked this path by scoring `chb03_01.edf` as if it were new: it raised alerts at about 390 s (the annotated seizure is at 360 to 415 s) and about 815 s (a false alert), matching the annotated run.

**Limits:** it needs the 18 standard bipolar channels (a file missing some stops with a message listing them); the 0.4 threshold was chosen on CHB-MIT, so another site's equipment may need a different value; it is a screening aid, not a diagnosis.

**Dashboard:** `AtlasDashboard` replays a recording window by window with the risk curve, threshold, ALERT status, alert log and patient results. Use chb03 or chb18 for a full replay (training patients keep only some windows).

---

## 4. Setup

**Requirements:** MATLAB R2026b with the Signal Processing Toolbox and the Statistics and Machine Learning Toolbox. Check with `ver`.

**Two folders:** the repo holds code; the data lives outside Git (shared through Google Drive). Point MATLAB at the data folder, ideally in your personal `startup.m` (`edit(fullfile(userpath,'startup.m'))`):

```matlab
setenv('ATLAS_DATA', 'C:\Users\YOU\Documents\ATLAS_DATA');
addpath(genpath('C:\Users\YOU\Documents\AI-Powered-Seizure-Early-Warning-System'));
```

The data folder holds `raw/` (EDF files and summaries), `processed/`, `features/` and `models/` (the final model, `rf_final.mat`).

```
/
├── config.m          All settings (one source of truth)
├── Dashboard/        AtlasDashboard.m
├── Data/             Raw, processed, features, models (NOT in Git)
├── Docs/             Figures and notes
├── Evaluation/       evaluateEvents, threshold tuning, robustness tests
├── Features/         extractFeatures, buildFeatureTable
├── Inference/        scoreRecording, readEdfWindows (new, unlabelled recordings)
├── Models/           trainModel, predictRisk, model comparison and tuning
└── Preprocessing/    downloadData, buildPatientData, checks
```

---

## 5. Reproducing the results

Functions are run from the Command Window. Patients: train chb05, chb14, chb01, chb15; test chb03, chb18; never use chb21 (same subject as chb01).

1. `downloadData()` then `checkChannels()` for the raw files.
2. `buildPatientData(id)` then `buildFeatureTable(id)` for each of the six patients; `checkPatient(id)` to inspect.
3. Model work on training patients only: `compareModels()`, `tuneRandomForest()`, `featureAblation()`, `testNormalization()`.
4. Threshold: rebuild two training patients with every window kept (`buildPatientData('chb05', config(), true)`, `buildFeatureTable('chb05_full')`, same for chb01), score them with models trained on the other patients, and choose the threshold from detection against false alarms per hour (0.4).
5. Lock the settings in `config.m` (`alertThreshold = 0.4`, `normalizeFeatures = true`), train the final model on all four training patients (`trainModel`) and save it to `Data/models/rf_final.mat`.
6. Final test, once: `predictRisk` with the final model on chb03 and chb18 and `evaluateEvents`; then `runRobustness(config().trainPatients, 'chb03', true)` and the same for chb18. `runRobustness` and `looPatientScores` refuse the test patients until you pass `true`.

---

## 6. Data standard and function contracts

| Item | Standard |
|---|---|
| Sampling rate / channels | 256 Hz; 18 bipolar: FP1-F7, F7-T7, T7-P7, P7-O1, FP1-F3, F3-C3, C3-P3, P3-O1, FP2-F4, F4-C4, C4-P4, P4-O2, FP2-F8, F8-T8, T8-P8, P8-O2, FZ-CZ, CZ-PZ |
| Filter | Band-pass 0.5 to 40 Hz |
| Window | 5 s (1280 samples), 50% overlap (2.5 s step) |
| Label | 1 if at least 50% of the window overlaps an annotated seizure |
| Training data | All seizure windows plus about 10 seizure-free windows per seizure window |
| Test data | Every window kept, so false alarms per hour is meaningful |
| Random seed | `rng(42)` at the top of every script |

**Processed file** `Data/processed/<id>.mat` (saved `-v7.3`): `windows` (windows x 18 x 1280, single), `labels`, `windowStartSec`, `fileName`, `patientID`, `fs`, `channelNames`, `skippedFiles`.

**Feature table** `Data/features/<id>.mat`, variable `T`: columns `patientID`, `fileName`, `windowStartSec`, `label`, then 126 features named `<feature>_<channel>` (for example `delta_FP1F7`, `lineLength_CZPZ`).

| Function | Input | Output |
|---|---|---|
| `buildPatientData` | `patientID, cfg, keepAll` | saves the processed file |
| `extractFeatures` | `windows, fs, channelNames` | feature table |
| `trainModel` | `Ttrain, method, normalize` | model struct (rescaling follows `cfg.normalizeFeatures`) |
| `predictRisk` | `model, T` | risk 0 to 1 per window (pass a patient's whole table) |
| `evaluateEvents` | `scores, labels, windowStartSec, fileName, opts` | struct: sensitivity, false alarms per hour, median latency, seizure and alert tables |
| `scoreRecording` | `edfFiles, options` | alerts and window scores for new, unlabelled recordings |

**Alert and evaluation rules:** an alert fires when the score is at or above the threshold for 3 consecutive windows (time = end of the completing window). A seizure is detected if an alert falls inside it; latency is the first such alert minus onset (accurate to about one window); a false alarm is an alert outside every seizure. False alarms per hour is only valid on full, unsubsampled recordings.

---

## 7. Limitations

- Only four training patients and two test patients (13 test seizures), so results describe these patients, not epilepsy in general.
- Detectability varies strongly between patients (chb05 against chb14), and false alarm rates differed between the test patients (2.2 and 5.0 per hour).
- The threshold came from full recordings of two training patients (12 seizures), so the test false alarm rate (3.5 per hour) is above our target of about one per hour.
- Rescaling uses the patient's whole recording as the baseline, so a live system would need a short baseline period or a running estimate. Per-recording rescaling may also flatter the noise results.
- The 8-channel and 4-channel sets are examples, not clinical montages. A model for fewer channels would need retraining.
- Detection only. Not a diagnosis, and not validated for clinical use.

---

---

## 8. Data sources and citations

- Guttag, J. (2010). CHB-MIT Scalp EEG Database (version 1.0.0). PhysioNet. https://doi.org/10.13026/C2K01R
- Shoeb, A. (2009). Application of Machine Learning to Epileptic Seizure Onset Detection and Treatment. PhD Thesis, MIT.
- Andrzejak RG, Lehnertz K, Rieke C, Mormann F, David P, Elger CE (2001). Phys. Rev. E, 64, 061907 (Bonn dataset, used only for early code checks).
