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
    """Represents a capture file and provides timestamp helpers.

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
        return self.parse_timestamp(self._file)

    @staticmethod
    def parse_timestamp(file: Path) -> datetime:
        timestamp_str = file.stem.split("_")[-1]
        return datetime.strptime(timestamp_str, "%Y%m%d%H%M%S")

    @property
    def name(self) -> str:
        return self._file.name

    @property
    def path(self) -> Path:
        return self._file


class LatestCaptureFiles:
    """Represents the two most recent capture files (latest and previous).

    Provides helpers to compare a `CaptureFile` instance against the
    discovered `latest` and `previous` capture files.
    """
    def __init__(self, files: List[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._latest: Optional[CaptureFile] = None
        self._previous: Optional[CaptureFile] = None
        sorted_files: List[Path] = sorted(
            files,
            key=CaptureFile.parse_timestamp,
            reverse=True
        )[:2]
        if len(sorted_files) > 0:
            self._latest = CaptureFile(sorted_files[0])
            if len(sorted_files) > 1:
                self._previous = CaptureFile(sorted_files[1])

    def is_empty(self) -> bool:
        return self._latest is None

    def is_equal_to_latest(self, capture_file: CaptureFile) -> bool:
        if self._latest is None:
            return False
        return self._latest.name == capture_file.name

    def is_equal_to_previous(self, capture_file: CaptureFile) -> bool:
        if self._previous is None:
            return False
        return self._previous.name == capture_file.name

    @property
    def latest(self) -> Optional[CaptureFile]:
        return self._latest

    @property
    def previous(self) -> Optional[CaptureFile]:
        return self._previous
