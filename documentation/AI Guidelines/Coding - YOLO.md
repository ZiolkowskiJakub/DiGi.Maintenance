# AI Guidelines: YOLO Year Built Detector — Runner, Training & Deployment

Rules for the YOLO building detector that feeds the Year Built prediction: the repositories it spans, how the
headless runner resolves its weights and scratch folders, where training data lives, and how the runner is
deployed. Every rule below exists because breaking it once cost a run, a deploy or a day.

## Mandatory Rule

> **Only the shipped detector `YOLO/models/model.pt` is deployment content. Training inputs, earlier
> weights and run scratch live in a training directory outside the workspace, and the runner extension is
> deployed from an allowlist — never a blocklist.**

---

## 1. Components

| Repository / project | Role |
|----------------------|------|
| `DiGi.YOLO` | The CPython (ultralytics) wrapper: prediction, `train.py` / `val.py`, `Modify.Train` / `Modify.Validate`, the environment preflight (`YOLOEnvironmentResult`). |
| `DiGi.YOLO.ONNX` | In-process ONNX inference through `Microsoft.ML.OnnxRuntime.Managed`. **Not** the pipeline default — the in-process engine was closed as not planned (DiGi.GIS.YOLO.UI#1), and `model.onnx` is kept in sync with `model.pt` by DiGi.YOLO.ONNX#2. |
| `DiGi.GIS.YOLO` | `Create.Building2DYearBuiltPredictions` — turns a detector's bounding-box result into per-building predictions. |
| `DiGi.GIS.YOLO.UI` | The pipeline library: options classes, `Modify.RunYearBuiltPredictionsAsync`, dataset build and training orchestration. |
| `DiGi.GIS.YOLO.UI.ConsoleApp` | The headless runner. No flag: a prediction run with the options file passed as the first argument. `--dataset`, `--check-labels`, `--evaluate-detector` take a `YOLOTrainingDatasetOptions` file; `--train` takes a `YOLOTrainingRunOptions` file. |
| `DiGi.GIS.PostgreSQL.UI` | The tray application. `UIYearBuiltPredictionsTask` and `UIYOLOTrainingTask` start the runner with `Process.Start` from `bin\extensions\DiGi.GIS.YOLO.UI.ConsoleApp\` (§5). |

- **Prediction runs on the CPython path with `model.pt`.** Every inference host needs the ultralytics version
  the weights were trained with (8.4.165 for `train9_fresh`; YOLO26 does not load under 8.3.130), and the
  runner's preflight refuses an older one (DiGi.GIS.YOLO.UI#23).
- **Detector and regressor ship as a pair.** `OrtoBuildingDetectionModel.mlnet` (DiGi.GIS.ML, copied beside
  the runner) is fitted to one detector's features. A regressor fitted to `train9_fresh` detections must
  never score a county whose stored detections still come from `train8` — the feature-coverage guard does
  not catch it, because the columns are populated, just by the wrong detector (DiGi.GIS.YOLO.UI#23).
- **GPU inference through Emgu is not available.** `Emgu.CV.runtime.windows.cuda` stops at 4.4 on nuget.org
  while the workspace uses `Emgu.CV` 4.12, which is why `DiGi.YOLO.ONNX` uses ONNX Runtime and keeps Emgu for
  imaging only (`Coding - General.md` §4, *Before Adding One*).

## 2. Weights — `model.pt` And How A Path Resolves

- **`ModelPath` defaults to `user files/YOLO/models/model.pt`**, in both `YearBuiltPredictionPipelineOptions`
  and `YOLOTrainingDatasetOptions`. `Query.ModelPath` resolves it as given, then against the application base
  directory, then — for a `user files/` prefix — with that segment stripped against the base directory and
  the current directory. `CopyUserFiles` flattens `user files/` into `bin`, so the same value names the
  weights in a workspace checkout and beside a deployed executable. An absolute path is used as is.
- **`model.pt` is replaced in place when a new detector ships**, so a file name says nothing about which
  detector produced a run. The run log records the weights' SHA-256 at start; compare that, not the name.
- **The detector that is replaced is kept in the training directory** (`model_train8.pt`, its ONNX export),
  not beside the deployed `model.pt` — it is a rollback and an evaluation baseline, not deployment content.
- **A preflight must resolve the path the way the runner will before calling it absent.** The weights
  probe once ran only `if (!string.IsNullOrWhiteSpace(path_Model))`, so a `null` `ModelPath` passed the
  preflight, exported 55 366 images and failed on the first step that opened the file
  (`Coding - General.md` §1 item 15).

## 3. Training Data Lives Outside The Workspace

`user files/` **ships**: `CopyUserFiles` flattens it into `bin`, and `Deploy.ps1` carries `bin` to the hosts.
It therefore holds only what the deployed runner reads at runtime — `GIS_WebAPI_Client.conf`, the prediction
options and `YOLO/models/model.pt`.

Everything else belongs to training and lives in a **training directory outside the workspace** on the
training machine:

- earlier or alternative weights (`model_train8.*`, `model_train9_*`), ONNX exports, and the pretrained
  base weights (`base/yolo26x.pt`);
- the legacy reference table `Data_2025.05.27.tsv`;
- training datasets, training runs (`runs/<RunName>/`), training and experiment options, training reports;
- the scratch folders of training and labelling runs (§4).

The options kept there name those inputs by **absolute path** and are passed to the runner explicitly
(`--dataset <path>`, `--train <path>`, or the path as the first argument of a prediction run). DiGi.GIS.YOLO.UI's
`user files/` once carried 1.17 GB of model variants plus the 38 MB legacy table to every deploy.

**Known gap — tray training defaults.** `UIYOLOTrainingTask` resolves its default start weights
(`YOLO/models/base/yolo26x.pt` for *Start from yolo26x.pt*) and the dataset step's `LegacyReferencesFilePath`
(`user files/Data_2025.05.27.tsv`) against the runner folder, where they are no longer deployed. The start
weights can be typed into the dialog; the legacy table cannot, so a tray run with the Dataset step is refused
("the legacy references file … was not found beside the runner"). Run the dataset step from the console with an
options file in the training directory until the tray takes a configurable training location. Update this
paragraph when it does.

## 4. Scratch Folders

- **`ScratchDirectory` is resolved against the current directory — the runner's own `bin`** — so a relative
  value writes exported imagery into the deployable folder. A county folder holds `images/`, the scripts and
  `results.bbrf`.
- **`CleanScratchDirectory` (default `true`) removes a county's folder once it finished without a failed
  step;** a failed county keeps it, so a re-run costs seconds rather than repeating the export and inference.
  Set it to `false` only for a run whose scratch you will read afterwards.
- **`Resume` is passed to the image export**, which then skips images already on disk. With `RunPrediction`
  on, the detector always runs again. With it off (a score-only run), the county's `results.bbrf` in scratch
  **is** the input — the stored detection columns are never read back — so a scratch folder left by an
  earlier detector is scored as if it were the current one. Delete scratch from a replaced detector rather
  than keeping it "for resume".
- **Production prediction runs** may use the relative default (`scratch`), because they clean up after
  themselves. Started from the tray, a relative `scratch` resolves against the **tray application's** current
  directory, normally `DiGi.GIS.PostgreSQL.UI\bin`: the options file of every run stays there, and so does the
  imagery of every county that failed (a median county is about 370 000 images / 6 GB). `Deploy.ps1`
  therefore deploys that bin's top-level directories from an allowlist too (§5). **Training and labelling runs** (`CleanScratchDirectory: false`, hundreds of thousands of files)
  set an absolute `ScratchDirectory` in the training directory: `scratch_train9` written into `bin` was
  235 042 files / 3.4 GB.

## 5. Deploying The Runner Extension

`DiGi.GIS.PostgreSQL.UI\bin\extensions\DiGi.GIS.YOLO.UI.ConsoleApp\` holds a standalone executable, not an
assembly loaded into the tray application (`Coding - General.md` §4, *The Other `extensions\` Folder*).

- **It is its own deployment unit.** It carries its own dependency closure and its own `*.conf` — the runner
  authorizes with the `GIS_WebAPI_Client.conf` beside its own executable, not with the tray application's.
  `CheckHostDependencies.ps1` audits it as a unit of its own rather than with `Recurse`.
- **Its absence is a supported state, not a gap.** `Deploy.ps1` assembles it only when
  `INCLUDE_YEAR_BUILT_PREDICTION_EXTENSION` is set in `user files/Directories.conf`, so a database host that
  will never score a building never receives it. The tray application withholds the task rather than
  offering a row whose only outcome is a missing executable, discovered after the counties have been chosen.
- **Assemble it as a LOCAL sync into the host's own `bin`, never as a software destination of its own.**
  `SyncDirectory.ps1` clears each destination's top level, so a destination nested *underneath* another one
  is deleted by that one's sync, and the ordering of `$SyncList` silently becomes load-bearing. Assembled
  into `bin` first, the extension travels to the host as part of the application, and a workspace checkout
  and a deployed machine then resolve it by the same path.
- **Assemble it from an allowlist, never a blocklist.** The runner's `bin` is also where its runs and its
  training land. `Deploy.ps1` once excluded `scratch` by name; a labelling run then wrote `scratch_train9`
  (235 042 files, 3.4 GB), which went to the host and the synced software directory, and the deploy slowed
  to a crawl. `Deploy.ps1` now copies:
  - the root files, minus `Data_*.tsv`, `YOLOTraining*Options*.json`, `*.hold` and `*.log`
    (`SyncDirectory.ps1 -ExcludeFile`);
  - `runtimes` and the satellite resource folders — no subfolders, nothing but `*.resources.dll`
    (`Test-DeployableDirectory`);
  - of `YOLO`, only `YOLO\models\model.pt` (the `IncludePath` entry). `model.onnx` is not read by the runner
    and is not deployed.
- **The tray application's own bin is allowlisted as well.** Of `DiGi.GIS.PostgreSQL.UI\bin`'s top-level
  directories only `extensions`, `runtimes` and the satellite resource folders reach the software directory.
  Everything else (the tray runs' `scratch`, `logs`) is printed on the `DiGi.GIS.PostgreSQL.UI - not deployed:`
  line. A new folder the tray needs at runtime has to be added there explicitly.
- **Read the deploy's size line.** Every deploy prints
  `Year Built prediction extension: N file(s), X MB. Not deployed: …` — about 212 files / 268 MB — and warns
  above 1 000 files or 1 GB, or when `model.pt` is missing. The flip side of an allowlist: a new runtime
  folder the runner needs is left out **silently** until it is added to `Test-DeployableDirectory` or
  `IncludePath`, and the `Not deployed:` list is where it shows.
- **The runner's NuGet closure is declared on the runner.** DiGi libraries reach it by `HintPath`, so their
  packages are re-declared in `DiGi.GIS.YOLO.UI.ConsoleApp.csproj` — and only the ones actually loaded:
  stale `TorchSharp`/`OneDal` declarations once shipped about 1.6 GB of native runtimes for a LightGbm
  regressor that never touched them. Verify with `CheckHostDependencies.ps1`, not a green build.

---

## Checklist

- [ ] Does `user files/` hold only what the deployed runner reads (conf, prediction options, `model.pt`)?
- [ ] Does every training or labelling options file name an absolute `ScratchDirectory` and absolute
      inputs in the training directory?
- [ ] After a deploy, is the extension about 212 files / 268 MB, with `scratch*`, `logs`, `reports` in
      `Not deployed:` and no warning?
- [ ] When shipping a new detector: is `model.pt` replaced together with its regressor, the old weights kept
      in the training directory, and the SHA-256 recorded on the issue?
