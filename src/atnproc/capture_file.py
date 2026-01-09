"""Representations of an actual capture file instance in the filesystem.

This module provides the :class:`CaptureFilePath` helper which wraps a
``pathlib.Path`` and provides access to capture-related metadata.
"""

from datetime import datetime, date
from pathlib import Path

from atnproc.capture_file_name import CaptureFileName


class CaptureFile:
    """Represents a capture file on the filesystem."""

    def __init__(self, file: Path):
        self._file: Path = file
        self._name: CaptureFileName = CaptureFileName(file.name)

    @property
    def date(self) -> date:
        """Returns the date part of the file's timestamp."""
        return self._name.date

    @property
    def timestamp(self) -> datetime:
        """Returns the file's timestamp."""
        return self._name.timestamp

    @property
    def name(self) -> CaptureFileName:
        """Returns the file's name."""
        return self._name

    @property
    def path(self) -> Path:
        """Returns the file's path."""
        return self._file

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, CaptureFile):
            return NotImplemented
        return self.path == other.path

    def __hash__(self) -> int:
        return hash(self.path)
