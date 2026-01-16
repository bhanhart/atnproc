"""Configuration loader for the application.

Loads YAML configuration and exposes working and capture directories as
pathlib `Path` properties used elsewhere in the application.
"""

from pathlib import Path
from typing import Any

import yaml



class WorkDirectories:
    """Filesystem paths for work area directories."""

    _input: Path
    _current: Path
    _processed: Path
    _output: Path

    def __init__(self, input: Path, current: Path, processed: Path, output: Path):  # pylint: disable=W0622
        self._input = input
        self._current = current
        self._processed = processed
        self._output = output

    @property
    def input(self) -> Path:
        return self._input

    @property
    def current(self) -> Path:
        return self._current

    @property
    def processed(self) -> Path:
        return self._processed

    @property
    def output(self) -> Path:
        return self._output


class Configuration:
    """Load and expose configured filesystem paths for the application.

    Holds `capture_directories` and `work_directories` entries parsed from the
    YAML configuration file and exposes them as `pathlib.Path` properties.
    """
    _capture_directories: list[Path]
    _work_directories: WorkDirectories
    _processing_interval_seconds: int
    _filter_ip: str
    _awk_script: Path

    def __init__(self, config_file: Path):
        with open(config_file, encoding="utf-8") as f:
            config: Any = yaml.safe_load(f)
        self._processing_interval_seconds = config["processing_interval_seconds"]
        self._filter_ip = config["filter_ip"]
        self._awk_script = Path(config["awk_script"])
        capture_dirs = config["capture_directories"]
        self._capture_directories = [Path(d) for d in capture_dirs]
        work_dirs = config["work_directories"]
        self._work_directories = WorkDirectories(
            input=Path(work_dirs["input"]),
            current=Path(work_dirs["current"]),
            processed=Path(work_dirs["processed"]),
            output=Path(work_dirs["output"])
        )

    @property
    def processing_interval_seconds(self) -> int:
        return self._processing_interval_seconds

    @property
    def filter_ip(self) -> str:
        return self._filter_ip

    @property
    def awk_script(self) -> Path:
        return self._awk_script

    @property
    def capture_directories(self) -> list[Path]:
        return self._capture_directories

    @property
    def work_directories(self) -> WorkDirectories:
        return self._work_directories
