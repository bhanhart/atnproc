"""Module for loading files from specified directories using glob patterns.
"""

import logging
from pathlib import Path
from typing import List


class FileLoader:
    """Load files from a list of directories using a glob pattern.

    Subsequent calls to `load_files()` will append to the existing list of
    loaded files.
    """

    def __init__(self, directories: list[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(self.__class__.__name__)
        self._directories = directories
        self._files: list[Path] = []

    def load_files(self, pattern: str) -> None:
        for directory in self._directories:
            files: list[Path] = list(directory.glob(pattern))
            self._logger.debug(
                f"Found {len(files)} file(s) in {directory} with pattern {pattern}"
            )
            self._files.extend(files)

    @property
    def num_files(self) -> int:
        return len(self._files)

    @property
    def files(self) -> List[Path]:
        return self._files
