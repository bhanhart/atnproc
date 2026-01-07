"""Configuration loader for the application.

Loads YAML configuration and exposes working and capture directories as
pathlib `Path` properties used elsewhere in the application.
"""

from pathlib import Path
from typing import Any

import yaml



class WorkAreaConfig:
    """Configured filesystem paths for work area directories."""

    _input_directory: Path
    _current_directory: Path
    _output_directory: Path

    def __init__(self, input_directory: Path, current_directory: Path, output_directory: Path):
        self._input_directory = input_directory
        self._current_directory = current_directory
        self._output_directory = output_directory

    @property
    def input_directory(self) -> Path:
        return self._input_directory

    @property
    def current_directory(self) -> Path:
        return self._current_directory

    @property
    def output_directory(self) -> Path:
        return self._output_directory


class Configuration:
    """Load and expose configured filesystem paths for the application.

    Holds `capture_directories` and `work_directories` entries parsed from the
    YAML configuration file and exposes them as `pathlib.Path` properties.
    """
    _capture_directories: list[Path]
    _work_area: WorkAreaConfig
    _processing_interval_seconds: int

    def __init__(self, config_file: Path):
        with open(config_file, encoding="utf-8") as f:
            config: Any = yaml.safe_load(f)
        self._processing_interval_seconds = config["processing_interval_seconds"]
        capture_dirs = config["capture_directories"]
        self._capture_directories = [Path(d) for d in capture_dirs]
        work_dirs = config["work_directories"]
        self._work_area = WorkAreaConfig(
            input_directory=Path(work_dirs["input_directory"]),
            current_directory=Path(work_dirs["current_directory"]),
            output_directory=Path(work_dirs["output_directory"])
        )

    @property
    def processing_interval_seconds(self) -> int:
        return self._processing_interval_seconds

    @property
    def capture_directories(self) -> list[Path]:
        return self._capture_directories

    @property
    def work_area(self) -> WorkAreaConfig:
        return self._work_area
