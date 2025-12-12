"""Helpers for capture file metadata and timestamp parsing.

This module provides the :class:`CaptureFile` helper which wraps a
``pathlib.Path`` and extracts the timestamp from filenames that use the
project naming convention (timestamp at the end of the stem in
``%Y%m%d%H%M%S`` format).
"""

import logging
from datetime import datetime, date
from pathlib import Path
from typing import List, Optional


class CaptureFile:
    """Represents a capture file and provides access to the file's creation
       timestamp.

    Extracts a timestamp from the file stem using the expected naming
    convention and exposes convenience properties used by the processing
    code.
    """
    def __init__(self, file: Path):
        self._file: Path = file

    @property
    def date(self) -> date:
        return self.timestamp.date()

    @property
    def timestamp(self) -> datetime:
        timestamp_str = self._file.stem.split("_")[-1]
        return datetime.strptime(timestamp_str, "%Y%m%d%H%M%S")

    @property
    def name(self) -> str:
        return self._file.name

    @property
    def path(self) -> Path:
        return self._file

    def __eq__(self, other: object) -> bool:
        if isinstance(other, CaptureFile):
            return self.name == other.name
        return NotImplemented


class CaptureFileList:
    """Represents a list of capture files, sorted most recent first.
    """
    def __init__(self, files: List[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._sorted_files: List[CaptureFile] = sorted(
            [CaptureFile(file) for file in files],
            key=lambda file: file.timestamp,
            reverse=True
        )

    @property
    def latest(self) -> Optional[CaptureFile]:
        if len(self._sorted_files) == 0:
            return None
        return self._sorted_files[0]

    @property
    def previous(self) -> Optional[CaptureFile]:
        if len(self._sorted_files) < 2:
            return None
        return self._sorted_files[1]
