# AI-Powered Seizure Early-Warning System

**Team:** Team Atlas
**Event:** National Neuroscience Technology Hackathon 2026 (Theme C: AI & Brain Data)
**Platform:** MATLAB (R2026b)

A MATLAB pipeline that reads EEG recordings, cleans them, detects seizure activity, and shows a live risk score and alerts on an explainable dashboard. It is built to hold up on noisy, reduced-channel recordings, which is the situation in low-resource clinics. Our focus population is children and young adults.

This is a decision-support tool for clinicians, not a replacement for them. We claim seizure **detection** as an early-warning and screening aid. We do not claim true seizure prediction.

---

## 1. Team and roles

| Role | Name | Owns |
|---|---|---|
| Project Lead | [Name] | Scope, timeline, integration, `config.m`, submission, README |
| Data and Preprocessing | [Name] | Downloads, annotation parsing, windowing, filtering, artifact removal |
| Feature and Model | [Name] | Feature extraction, Random Forest and SVM training |
| Robustness and Validation | [Name] | Patient-wise evaluation, noise and channel tests, explainability |
| Dashboard and Presentation | [Name] | App Designer dashboard, slides, demo |

---

## 2. Requirements

- MATLAB R2026b
- Signal Processing Toolbox
- Statistics and Machine Learning Toolbox
- App Designer (included with base MATLAB)
- Optional: Deep Learning Toolbox (CNN is cut unless we are ahead at day 9)

Check your installation with `ver`. Both required toolboxes must appear.

---

## 3. Folder structure

```
/
├── config.m          All project settings (only the Lead edits this)
├── Dashboard/        App Designer app and its helper functions
├── Data/             Raw and processed data (NOT pushed to Git)
│   ├── raw/          Downloaded EDF files and summary files
│   └── processed/    One .mat file per patient (see section 4)
├── Docs/             Methods notes, figures, slides
├── Evaluation/       Metrics, patient-wise splits, robustness tests
├── Features/         Feature extraction functions
├── Models/           Training scripts and saved models
├── Preprocessing/    Downloading, loading, labelling, filtering, windowing
└── README.md
```

`Data/` is listed in `.gitignore`. The data is stored in our shared Google Drive folder instead (see section 5).

---

## 4. Locked decisions and data standard

These decisions were approved by the team. Do not change one without telling the Lead. All numeric settings live in `config.m`, and every script reads them from there. Nobody types these values into their own code.

### 4.1 Core decisions

| # | Decision |
|---|---|
| 1 | We claim seizure detection as an early-warning and screening aid, not prediction |
| 2 | CHB-MIT is the only dataset for results. Bonn is only a quick check that code runs |
| 3 | Train on chb05, chb14, chb01 and chb15. Test on chb03 and chb18, never used in training |
| 4 | 256 Hz and 18 standard bipolar channels shared by all six patients |
| 5 | Band-pass filter 0.5 to 40 Hz |
| 6 | 5-second windows with 50% overlap |
| 7 | A window is labelled seizure if at least 50% of it overlaps an annotated seizure |
| 8 | Features per channel: five band powers, line length, spectral entropy. Models: Random Forest (main) and SVM (baseline). CNN cut unless ahead at day 9 |
| 9 | An alert fires when the risk score is above the threshold for 3 windows in a row |
| 10 | The threshold is tuned on training patients only, then locked on day 11 before touching test patients |
| 11 | Headline metrics: sensitivity, false alarms per hour, detection latency |
| 12 | Robustness test: re-run test patients with fewer channels and added noise |
| 13 | All settings live in `config.m`, and only the Lead changes it |
| 14 | The dashboard replays recorded EEG from the test patients and shows the risk score, alert and top features |

### 4.2 Settings

| Item | Standard |
|---|---|
| Datasets | CHB-MIT Scalp EEG (main), Bonn (prototyping only) |
| Training patients | chb05, chb14, chb01, chb15 |
| Test patients | chb03, chb18 (never trained on) |
| Never use | chb21 (same subject as chb01) |
| Sampling rate | 256 Hz |
| Channels | 18 bipolar: FP1-F7, F7-T7, T7-P7, P7-O1, FP1-F3, F3-C3, C3-P3, P3-O1, FP2-F4, F4-C4, C4-P4, P4-O2, FP2-F8, F8-T8, T8-P8, P8-O2, FZ-CZ, CZ-PZ. Drop dummy "-" channels and extras |
| Filtering | Band-pass 0.5 to 40 Hz |
| Window | 5 s (1280 samples), 50% overlap (2.5 s step) |
| Label | 1 if at least 50% of the window overlaps an annotated seizure, otherwise 0 |
| Random seed | `rng(42)` at the top of every script |

> **Data role, first task:** run `edfinfo` on one file from each of the six patients and confirm all 18 channel names exist (some recordings may label a duplicated channel with a suffix). If a patient is missing channels, tell the Lead so the list in `config.m` can be trimmed to the shared set.

### 4.3 Processed file: `Data/processed/<patientID>.mat`

| Variable | Description |
|---|---|
| `windows` | windows x channels x samples, single precision |
| `labels` | column vector of 0/1, one per window |
| `windowStartSec` | start time of each window in seconds |
| `fileName` | source EDF file for each window |
| `patientID` | for example `'chb05'` |
| `fs` | 256 |
| `channelNames` | cell array, in the order above |

Save with `save(..., '-v7.3')` because the files are large.

### 4.4 Feature table

One row per window. Columns: `patientID`, `fileName`, `windowStartSec`, `label`, then the features. Feature columns are named `<feature>_<channel>`, for example `lineLength_FP1F7`. Features per channel: band power in delta (0.5-4 Hz), theta (4-8), alpha (8-13), beta (13-30) and gamma (30-40), plus line length and spectral entropy.

### 4.5 Function contracts

| Function | Input | Output |
|---|---|---|
| `buildPatientData` | `patientID, cfg` | saves the processed `.mat` file |
| `extractFeatures` | `windows, fs` | feature table |
| `trainModel` | training feature table | trained model |
| `predictRisk` | model, feature table | risk score from 0 to 1 per window |
| `evaluateEvents` | scores, labels, `windowStartSec` | sensitivity, false alarms per hour, latency |

### 4.6 Alert and evaluation rules

- **Alert:** the risk score stays at or above the threshold for 3 consecutive windows.
- **Detected seizure:** an alert starts inside the annotated seizure interval.
- **Sensitivity:** detected seizures divided by total seizures.
- **False alarms per hour:** alerts outside any seizure, divided by hours of seizure-free recording.
- **Latency:** alert time minus seizure onset time. With the 3-window rule, the best possible latency is about 10 seconds.

### 4.7 Splitting and class imbalance

- Split by patient, never by window. Neighbouring windows share half their signal.
- Training: keep every seizure window and subsample seizure-free windows (about 10 per seizure window), or use class weights.
- Testing: use the full, untouched recordings with no subsampling, so false alarms per hour is meaningful.

---

## 5. Getting the data

The data is too large for Git, so we share it through a Google Drive folder.

**Data role (once):**
1. Install Google Drive for desktop and create a folder, for example `TeamAtlas-Data`. Share it with the team.
2. In MATLAB, point the project at that folder, then download:
   ```matlab
   setenv('ATLAS_DATA', 'G:\My Drive\TeamAtlas-Data')   % use your own Drive path
   downloadData()
   ```
3. `downloadData` is safe to re-run. Existing files are skipped, so after a dropped connection just run it again.

**Everyone else:** in Google Drive for desktop, right-click the shared folder and choose to make it available offline (or copy it to `Data/` inside your repo), then run `setenv('ATLAS_DATA', ...)` with your local path. Reading directly from a streamed Drive folder can be slow.

`downloadData` fetches, for each patient: the `chbNN-summary.txt` file, every file containing a seizure, and evenly spaced seizure-free files (6 per training patient, 10 per test patient). Expect roughly 4 GB in total.

---

## 6. How to run

Fill in exact script names as they are written.

1. **Get data:** `downloadData()` (see section 5).
2. **Prepare data:** run `Preprocessing/buildPatientData` for each patient to load, label, filter and window into `Data/processed/`.
3. **Extract features:** run `Features/extractFeatures` to build the feature table.
4. **Train models:** run `Models/[script]` to train Random Forest and SVM.
5. **Evaluate:** run `Evaluation/[script]` for sensitivity, false alarms per hour and latency.
6. **Robustness tests:** run `Evaluation/[script]` with fewer channels and added noise.
7. **Dashboard:** open `Dashboard/[app].mlapp` in App Designer and click Run.

---

## 7. Team workflow

- **Daily check-in:** 15 minutes at [time]: what's done, what's next, what's blocked.
- **Push at least once a day.** Pull before you start work each day.
- **One function, one purpose.** Give every function a comment block describing inputs and outputs.
- **Naming:** `lowerCamelCase` for variables and functions, descriptive file names.
- **Branches:** work on a branch named after your role and merge to `main` only when your part runs.
- **Never commit data files.**

---

## 8. Timeline (14 days)

| Days | Goal |
|---|---|
| 1-2 | Setup, data download, channel check |
| 3-6 | Pipeline v1: one patient end to end, baseline model, dashboard playback |
| 7-9 | Full run on all patients, tuning, connect model to dashboard |
| 10-11 | Robustness tests and explainability, then freeze the model and lock the threshold |
| 12-13 | Packaging, documentation, slides, demo rehearsal, backup video |
| 14 | Buffer: fixes only, submit early |

**Checkpoints:** end of day 4, one patient's data flows from loading to a model output. End of day 9, the full pipeline works.

---

## 9. Deliverables

- [ ] Clean dataset and preprocessing code
- [ ] Trained model with metrics
- [ ] Robustness results (performance against channel count and noise level)
- [ ] Explainability figures (feature importance and Shapley plots)
- [ ] Working dashboard
- [ ] Documentation (this README and a short methods write-up)
- [ ] Pitch deck, live demo and backup demo video

---

## 10. Data sources and citations

- Guttag, J. (2010). CHB-MIT Scalp EEG Database (version 1.0.0). PhysioNet. https://doi.org/10.13026/C2K01R
- Shoeb, A. (2009). Application of Machine Learning to Epileptic Seizure Onset Detection and Treatment. PhD Thesis, MIT.
- Andrzejak RG, Lehnertz K, Rieke C, Mormann F, David P, Elger CE (2001). Indications of nonlinear deterministic and finite dimensional structures in time series of brain electrical activity. Phys. Rev. E, 64, 061907 (Bonn dataset).
