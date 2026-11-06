# AI-Powered Seizure Early-Warning from EEG

**Team:** [Team Atlas]
**Event:** National Neuroscience Technology Hackathon 2026 (Theme C: AI & Brain Data)
**Platform:** MATLAB (R2026b)

A MATLAB pipeline that reads EEG recordings, cleans them, detects seizure activity, and shows a live risk score and alerts on an explainable dashboard. It is built to hold up on noisy, reduced-channel recordings, which is the situation in low-resource clinics.

This is a decision-support tool for clinicians, not a replacement for them.

---

## 1. Team and roles

| Role | Name | Owns |
|---|---|---|
| Project Lead | [Yusuf Zakariya] | Scope, timeline, integration, submission, README |
| Data and Preprocessing | [Name] | Dataset download, annotation parsing, windowing, filtering, artifact removal |
| Feature and Model | [Name] | Feature extraction, Random Forest and SVM training |
| Robustness and Validation | [Name] | Patient-wise evaluation, noise and channel tests, explainability |
| Dashboard and Presentation | [Name] | App Designer dashboard, slides, demo |

---

## 2. Requirements

- MATLAB R2026b
- Signal Processing Toolbox
- Statistics and Machine Learning Toolbox
- App Designer (included with base MATLAB)
- Optional: Deep Learning Toolbox (small CNN comparison), Wavelet Toolbox (wavelet features)

Check your installation with `ver`. Both required toolboxes must appear in the list.

---

## 3. Folder structure

```
/
├── data/             Raw and processed data (NOT pushed to Git)
│   ├── raw/          Downloaded EDF files and annotation summaries
│   └── processed/    One .mat file per patient (see section 4)
├── preprocessing/    Loading, labelling, filtering, windowing
├── features/         Feature extraction functions
├── models/           Training scripts and saved models
├── evaluation/       Metrics, patient-wise splits, robustness tests
├── dashboard/        App Designer app and its helper functions
├── docs/             Methods notes, figures, slides
└── README.md
```

Add `data/` to `.gitignore`. Share the data through the team's shared drive instead.

---

## 4. Data conventions (agreed standard, do not change without telling the team)

These rules let every role work in parallel. If you need to change one, tell the Lead first and update this section.

| Item | Standard |
|---|---|
| Datasets | CHB-MIT Scalp EEG (main), Bonn dataset (early prototyping) |
| Patients | [List the 4-6 chosen CHB-MIT patient IDs here] |
| Channels | [List the agreed channel names here] |
| Sampling rate | [Agreed rate in Hz, for example 256] |
| Window length | [For example 5 s] |
| Window overlap | [For example 50%] |
| Labels | `0` = non-seizure, `1` = seizure |
| Processed file | One `.mat` file per patient: `data/processed/<patientID>.mat` |
| Feature table | One row per window; columns are features plus `label` and `patientID` |
| Model output | A risk score from 0 to 1 for each window |

### Processed `.mat` file contents

| Variable | Description |
|---|---|
| `windows` | Windowed signal array (windows x channels x samples) |
| `labels` | Column vector of 0/1 labels, one per window |
| `patientID` | Patient identifier string |
| `fs` | Sampling rate in Hz |
| `channelNames` | Cell array of channel names |

### Evaluation rule

**Always split by patient, never by window.** Windows from the same recording are highly correlated, so splitting by window inflates the results.

---

## 5. How to run

Fill in the exact script names as they are written.

1. **Prepare data:** run `preprocessing/[script]` to load, label, filter and window the raw data into `data/processed/`.
2. **Extract features:** run `features/[script]` to build the feature table.
3. **Train models:** run `models/[script]` to train the Random Forest and SVM baselines.
4. **Evaluate:** run `evaluation/[script]` to produce sensitivity, false alarms per hour and detection latency.
5. **Robustness tests:** run `evaluation/[script]` with reduced channels and added noise.
6. **Dashboard:** open `dashboard/[app].mlapp` in App Designer and click Run.

---

## 6. Evaluation metrics

- **Sensitivity:** the proportion of seizures detected.
- **False alarms per hour:** how often the system alerts when there is no seizure.
- **Detection latency:** the delay between seizure onset and the alert.
- **Robustness:** performance as channels are reduced and noise is added.

---

## 7. Team workflow

- **Daily check-in:** 15 minutes at [time]. Cover what's done, what's next and what's blocked.
- **Push at least once a day.** Do not wait until the end to integrate.
- **One function, one purpose.** Keep functions short and give each a comment block explaining inputs and outputs.
- **Naming:** use `lowerCamelCase` for variables and functions, and descriptive file names.
- **Branches:** work on a branch named after your role and merge to `main` only when your part runs.
- **Never commit large data files.**

---

## 8. Timeline (14 days)

| Days | Goal |
|---|---|
| 1-2 | Setup, data download, agree the data standard |
| 3-6 | Pipeline v1: one patient end to end, baseline model, dashboard playback |
| 7-9 | Full run on all patients, tuning, connect model to dashboard |
| 10-11 | Robustness tests and explainability, then freeze the model |
| 12-13 | Packaging, documentation, slides, demo rehearsal, backup video |
| 14 | Buffer: fixes only, submit early |

**Checkpoints:** end of day 4, one patient's data flows from loading to a model output. End of day 9, the full pipeline works.

---

## 9. Deliverables

- [ ] Clean dataset and preprocessing code
- [ ] Trained model with metrics
- [ ] Robustness results (table of performance against channel count and noise level)
- [ ] Explainability figures (feature importance and Shapley plots)
- [ ] Working dashboard
- [ ] Documentation (this README and a short methods write-up)
- [ ] Pitch deck, live demo and backup demo video

---

## 10. Data sources and references

- CHB-MIT Scalp EEG Database (PhysioNet)
- Bonn University EEG dataset
- MathWorks documentation and examples on EEG classification and seizure detection
