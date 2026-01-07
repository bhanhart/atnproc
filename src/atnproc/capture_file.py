"""Capture file metadata and timestamp parsing.

This module provides the :class:`CaptureFile` helper which wraps a
``pathlib.Path`` and extracts the timestamp from filenames that use the
project naming convention (timestamp at the end of the stem in
``%Y%m%d%H%M%S`` format).
"""

from datetime import datetime, date
from pathlib import Path


class CaptureFile:
    """Represents a capture file and provides access to the file's creation
       timestamp.

    Extracts a timestamp from the file stem using the expected naming
    convention and exposes convenience properties used by the processing
    code.
    """

    def __init__(self, file: Path):
        self._file: Path = file

    @staticmethod
    def date_format() -> str:
        return "%Y%m%d"

    @staticmethod
    def time_format() -> str:
        return "%H%M%S"

    @property
    def date(self) -> date:
        return self.timestamp.date()

    @property
    def timestamp(self) -> datetime:
        timestamp_str = self._file.stem.split("_")[-1]
        return datetime.strptime(
            timestamp_str, f"{self.date_format()}{self.time_format()}"
        )

    @property
    def name(self) -> str:
        return self._file.name

    @property
    def path(self) -> Path:
        return self._file
