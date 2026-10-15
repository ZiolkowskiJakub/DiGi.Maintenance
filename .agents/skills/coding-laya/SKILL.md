---
name: coding-laya
description: "Use when working on the Laya decision model (DiGi.Python, DiGi.Laya and their consumers) - checkpoint identity by DirectorySHA256 of the whole folder (never write a manifest, calibration or training output inside a checkpoint), training outside the workspace, mandatory fine-tune and calibration before trusting thresholds, releasing to LAYA_MODELS_DIRECTORY and deploying with DeployLaya.ps1 (allowlist, manifest skip, calibration side file, -Remove only), and the host venv from InstallPythonEnvironment.ps1 kept outside the synced software directory."
---

# AI Guidelines: Laya Decision Model — Runner, Training & Deployment

Rules for the Laya decision model and the two libraries that run it: which repository owns what, how a
checkpoint is identified, where training lives, how checkpoints and the Python environment reach a host, and
what a consumer must do before it trusts a probability. Laya is not generative: one forward pass answers typed
questions (`choice`, `score`, `noul`) about a state.

## Mandatory Rule

> **A checkpoint folder is identified by the SHA-256 of its whole content, so nothing is ever written inside a
> deployed one — not a manifest, not calibration temperatures, not a training output. Checkpoints are released
> outside the workspace, deployed by `DeployLaya.ps1` from an allowlist, and the Python environment is created
> on each host, outside the synced software directory.**

---

## 1. Components

| Repository / project | Role |
|----------------------|------|
| `DiGi.Python` | CPython process interop shared with DiGi.YOLO: `Query.ExecuteProcess` (inactivity stall, process-tree kill), `Query.PythonPath`, `Query.MarkedJson`, `Query.FileSHA256`, **`Query.DirectorySHA256`**, `Modify.WriteScripts`, `PythonEnvironmentResult`. |
| `DiGi.Laya` | The Laya runner: `Modify.PredictAsync`, `ClassifyAsync`, `TrainAsync`, `CalibrateAsync`, the preflight `Query.LayaEnvironmentResult`, and the scripts in `files/Laya/` (`check.py`, `predict.py`, `train.py`, `calibrate.py`, `requirements.txt`). |
| Consumers (bodyplan, ZiolkowskiJakub/bodyplan#77) | Own the states, label sets, thresholds (`LayaClassificationOptions.Thresholds`), confs and their deploy script, which calls `DeployLaya.ps1`. |

- **A CPython process per batch, not ONNX and not a resident HTTP service.** C# writes a JSONL request, starts
  `predict.py` once per batch (one model load) and reads a JSONL response — the DiGi.YOLO pattern. `laya[onnx]`
  refuses parallel-layout checkpoints, and a resident `laya-serve` is a separate, undecided backend.
- **Both libraries target `netstandard2.0`** and reach `DiGi.Core` by `HintPath`, so they add no NuGet gap to a
  host (`Coding - General.md` §4). A host still carries `DiGi.Python.dll` and `DiGi.Laya.dll` itself.

## 2. Model Identity

- **`ModelSHA256` is `DiGi.Python.Query.DirectorySHA256` of the whole checkpoint folder** — every file,
  recursively: `/`-separated relative paths sorted **ordinally**, a manifest of `path\nlowercase-sha256\n` per
  file, the lowercase SHA-256 of its UTF-8 bytes. `LayaTrainingResult`, `LayaPredictionResult`,
  `LayaClassificationResult` and `LayaEnvironmentResult` all report it, and a consumer stores it with each
  suggestion. A PowerShell reimplementation must sort with `List[string].Sort([StringComparer]::Ordinal)` —
  `Sort-Object` is culture-aware and case-insensitive and orders `B.txt` / `a.txt` the other way.
- **Anything added inside the folder changes the SHA.** The deploy manifest and the calibration temperatures
  therefore sit **beside** it (`models\<name>.manifest.json`, `models\<name>.calibration.json`);
  `CalibrateAsync` refuses a calibration path inside the checkpoint.
- **`Query.LayaModelPath` refuses a model name or Hub id** — only a local folder is a checkpoint.
- **Production never downloads.** `Query.PythonProcessResult` and `utils.py` set `HF_HUB_OFFLINE=1` and
  `TRANSFORMERS_OFFLINE=1`. `Query.LayaPythonPath` refuses a configured interpreter that does not resolve as
  given, where DiGi.Python's `PythonPath` would fall back to another `python` on `PATH`.

## 3. Training Lives Outside The Workspace

A checkpoint (`model.safetensors` alone is 644 MB for `laya-multilingual`, fp16) must never sit in a repository's
`user files/` — `CopyUserFiles` copies it into every build output — nor in any synced `bin`, where
`SyncDirectory.ps1` would recopy it on every deploy, or delete it when placed there by hand.

The training machine keeps one training directory, named by absolute path in the options passed to
`TrainAsync` / `CalibrateAsync`:

- the venv, the base checkpoints (`checkpoints\convaiinnovations-laya\multilingual`), datasets, gold sets;
- training runs, reports and scratch (`runs\<name>\`).

`Modify.TrainAsync` refuses an output directory inside a `Laya\models` or `DiGi.Laya\models` folder. laya's own
`laya-train` CLI leaves `checkpoint_latest\`, a full duplicate of the checkpoint; DiGi.Laya's `train.py`
removes it, and `DeployLaya.ps1` never deploys it.

## 4. Before Trusting A Probability

- **Fine-tune and calibrate on the consumer's data — both are mandatory.** Shipped checkpoints are
  over-confident (temperatures of 1) and weak zero-shot. `CalibrateAsync` fits a temperature per question type
  on a gold split and writes it to the calibration file; prediction reads it through
  `LayaPredictionOptions.CalibrationPath`.
- **laya holds out `min(calib_max, int(n * calib_frac))` items for its own calibration** and reports an ECE only
  for buckets of about 2 500 records or more — a small gold set gives no ECE, not a good one.
- **Ship a model only when it beats its baselines** — zero-shot and a deterministic one — on held-out data.
  Thresholds are tuned on calibrated scores, never before calibration.

## 5. Releasing And Deploying Checkpoints

A released model is a folder plus an optional side file in `LAYA_MODELS_DIRECTORY` on the deploying machine
(`user files/Directories.conf`):

```
<LAYA_MODELS_DIRECTORY>\recipe_classification\
<LAYA_MODELS_DIRECTORY>\recipe_classification.calibration.json
```

With `INCLUDE_LAYA_MODELS=true`, `Deploy.ps1` calls `DeployLaya.ps1` **after** the software syncs; a consumer's
deploy script calls it directly.

- **Its own top-level destination, never a `$SyncList` entry.** `<SOFTWARE_DIRECTORY>\DiGi.Laya\` holds
  `requirements.txt`, `InstallPythonEnvironment.ps1` and `models\`. Nested under another destination, it would be
  cleared by that one's sync (the trap of `Coding - YOLO.md` §5); synchronized as a whole, every deploy would
  recopy every checkpoint and delete the models a host still uses.
- **Allowlist of the checkpoint layout:** `model.safetensors` and `*.json` at the root (`rl_agent_config.json`,
  `questions.json`, `train_report.json`), `encoder\*.json`, `tokenizer\*.json|*.model|*.txt`. Everything else is
  printed on the `Not deployed:` line — `checkpoint_latest/`, `scratch/`, logs. laya writes only
  `model.safetensors` as weights; a new file type the layout needs is left out silently until added to the
  allowlist, and `Not deployed:` is where it shows.
- **The manifest makes a redeploy cheap.** `models\<name>.manifest.json` records each file's SHA-256 and size, the
  `directorySHA256` of the deployed file set, `calibrationSHA256`, `sourcePath` and `deployedAt`. An unchanged
  model whose deployed files are all present at their recorded sizes is `skipped (unchanged)`. A changed one is
  copied to `<name>.staging`, re-hashed, swapped in, and its manifest is written last, so an interrupted deploy is
  recopied next time. One model never touches another.
- **The released SHA is the deployed-folder SHA.** `directorySHA256` covers only the allowlisted files, so a
  release folder that still holds excluded files hashes differently at the source than on the host. Release a
  clean folder — the output of DiGi.Laya's `train.py` is — and its `LayaTrainingResult.ModelSHA256` equals the
  manifest's.
- **A deployed model is removed only by `-Remove <name>`.** A model the source no longer has is reported, not
  deleted; turning `INCLUDE_LAYA_MODELS` off leaves `DiGi.Laya\` as it is.
- **Read the size line.** Each model prints `N file(s), X MB`; the fine-tuned layout is seven files. Above
  `-MaxFileCount` (50) or `-MaxMB` (4096) the five largest files are listed.

## 6. The Host Environment

Run on each host, never by `Deploy.ps1` — servers have no development tooling (`Coding - Deployed WebAPI.md` §5):

1. Install CPython ≥ 3.10, readable and executable by the account of the service that runs the consumer
   (`DiGi.WebAPI.WindowsService` on the database server) — the same policy as the YOLO runner's Python.
2. `InstallPythonEnvironment.ps1 -PythonPath <python.exe> -RequirementsPath <SOFTWARE_DIRECTORY>\DiGi.Laya\requirements.txt -Destination <venv> -Torch cpu|cuda`.
   **`<venv>` lies outside the synced software directory:** the environment is several GB, specific to that
   host's Python, and a file-sync service would carry it to every other machine.
3. Set the consumer's conf: `PythonPath` = the printed venv `python.exe`, `ModelPath` =
   `...\DiGi.Laya\models\<name>`, `CalibrationPath` = `...\DiGi.Laya\models\<name>.calibration.json`.
4. Run the consumer's preflight (`Query.LayaEnvironmentResult`, e.g. bodyplan's `--check`).

- **`requirements.txt` pins `laya` exactly and sets floors for `transformers` and `torch`.** `check.py` refuses any
  other laya version. torch is installed first from the PyTorch index the variant names — `cpu`, or `cu128` by
  default for `cuda` (Blackwell GPUs need CUDA 12.8) — and the requirements file after it.
- **`environment.json` records the install** (Python, `pip freeze`, requirements SHA-256, torch variant and
  version, whether CUDA is available). Re-running with the same requirements and variant is a no-op; a new
  `requirements.txt` deployed by `DeployLaya.ps1` makes the next run reinstall.

## 7. Running

- **`InactivityTimeout` counts silence, not duration.** `predict.py` prints a progress line per 256 states;
  `calibrate.py` prints nothing until it is done, so its limit must cover the whole calibration.
- **Two runs never share a `WorkingDirectory`.** Leave it `null` for a temporary one.
- **Measure latency on the host that runs it.** The training machine's GPU numbers say nothing about the
  database server's CPU; GPU inference on the database server is out of scope.

---

## Checklist

- [ ] Is every released checkpoint outside the workspace, with no file added inside it after training?
- [ ] Was the model fine-tuned **and** calibrated on the consumer's data, and does it beat zero-shot and the
      deterministic baseline on held-out data?
- [ ] Does the deploy print `skipped (unchanged)` for every model you did not change, and nothing unexpected on
      `Not deployed:`?
- [ ] Does the host's consumer conf name the venv `python.exe`, the deployed model folder and its calibration
      file, and does the consumer's preflight pass on the host?
- [ ] Is the venv outside the synced software directory?
- [ ] Is the `ModelSHA256` the host reports equal to the manifest's `directorySHA256` and the one recorded at
      training?
