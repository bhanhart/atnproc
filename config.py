from pathlib import Path
from typing import Any

import yaml


class Configuration:
    _capture_directories: list[Path]
    _input_directory: Path
    _active_directory: Path
    _output_directory: Path

    def __init__(self, config_file: Path):
        with open(config_file) as f:
            config: Any = yaml.safe_load(f)
        self._capture_directories = [Path(d) for d in config["capture_directories"]]
        self._input_directory = Path(config["work_directories"]["input_directory"])
        self._active_directory = Path(config["work_directories"]["active_directory"])
        self._output_directory = Path(config["work_directories"]["output_directory"])

    @property
    def capture_directories(self) -> list[Path]:
        return self._capture_directories

    @property
    def active_directory(self) -> Path:
        return self._active_directory

    @property
    def input_directory(self) -> Path:
        return self._input_directory

    @property
    def output_directory(self) -> Path:
        return self._output_directory
