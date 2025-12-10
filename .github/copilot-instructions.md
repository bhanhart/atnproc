<!-- .github/copilot-instructions.md: Guidance for AI coding agents working on atnproc -->
# Copilot / Agent Instructions — atnproc

Purpose: give an AI coding assistant the minimal, actionable knowledge to be productive in this repository.

Quick start
- **Run**: `python3 main.py -c config.yaml` (the program expects `-c/--config-file`).
- **Logging**: `logging.yaml` config is loaded by `main.py` early; ensure `log` directory exists.

Big picture (core components)
- **Application orchestration**: `application.py` — generic event loop. It calls `processor.process()` repeatedly and expects a `datetime.timedelta` for the sleep interval.
- **Processor**: `atn_capture_processor.py` implements the domain logic. It implements `ProcessorInterface` (see `processor_interface.py`) and should return a `timedelta` to control loop cadence.
- **File selection & loading**: `capture_file_loader.py` discovers recent capture files using a "today then yesterday" strategy and returns up to the two most recent files.
- **Capture file model**: `capture_file.py` parses timestamps from filenames; it expects the timestamp at the end of the stem in `%Y%m%d%H%M%S` format.
- **Config**: `config.py` reads `config.yaml` (PyYAML). Keys of interest: `capture_directories` and `work_directories`.

Key patterns & conventions (project-specific)
- **Filename format**: files are like `atnr01_net3_00001_20250807074909.pcap`. Timestamp parsing uses the final `_YYYYMMDDHHMMSS` segment.
- **Two-file processing rule**: code intentionally only needs the two most recent files (latest + previous) to handle incomplete/ growing `rsync` writes.
- **Processor contract**: `ProcessorInterface.process()` must return a `datetime.timedelta`; `Application` uses that to decide how long to sleep. Implementations should be idempotent and safe to re-run (processing may re-run a file to catch new data).
- **WorkArea staging**: `WorkArea.stage_capture_file()` currently contains a placeholder — real behavior should copy (or atomically move) files into the `active/current` work area. Use `shutil.copy2()` or an atomic move depending on requirements.

Important gotchas discovered
- **Config key mismatch**: `config.yaml` lists `work_directories.current_directory` while `config.py` expects `work_directories.active_directory` (property is `active_directory`). Be careful when editing config or code — reconcile these names before changing behavior.
- **Processing skeleton**: `AtnCaptureProcessor` is currently a scaffold that stages files and returns a fixed `timedelta(seconds=10)`. The real packet extraction (tcpdump + awk) is described in `README.md` but not yet implemented in Python.
- **External runtime dependencies**: The processing strategy described in `README.md` uses `tcpdump` and an AWK script (`rtcd_routerlog.awk`) to transform `tcpdump` output into single-line records. These binaries/scripts must exist on runtime PATH.

Where to make common edits
- Add copying/staging logic in `atn_capture_processor.WorkArea.stage_capture_file()` (currently a TODO). Use `shutil` and preserve metadata if desired.
- Implement packet extraction in a new helper module (e.g., `processor/tcpdump_runner.py`) or directly inside `AtnCaptureProcessor` but keep the `ProcessorInterface` contract.
- Use `LatestCaptureFiles` (in `capture_file_loader.py`) to compare `active` vs `latest/previous` filenames.

Tests and runtime checks
- There are no unit tests in the repo yet. For small changes, run `python3 -m pylint <module>` or simple `python3 -m pyflakes` for quick static checks.
- Run the app locally with a test `config.yaml` that points `capture_directories` to `example/` to exercise filename parsing and loader code.

Files to consult when changing behavior
- `main.py` — entrypoint, logging setup, `-c` flag.
- `application.py` — shutdown, event loop, `InterruptibleSleeper` usage.
- `atn_capture_processor.py` — where capture processing logic belongs.
- `capture_file_loader.py` and `capture_file.py` — file discovery and timestamp parsing.
- `config.py` and `config.yaml` — configuration contract; watch for the `active/current` naming mismatch.
- `README.md` / `PRD.MD` — domain explanation and `tcpdump`+`awk` transformation pipeline description.

If you are an AI making code changes
- Keep PR changes minimal and focused: preserve the `ProcessorInterface` contract and Application orchestration.
- When implementing file operations, avoid destructive moves of original capture files — keep the source read-only and copy into a local work area.
- Add a small local test harness or unit tests for `CaptureFile.parse_timestamp` and `LatestCaptureFiles` before implementing heavy shell integration.

End of instructions.
