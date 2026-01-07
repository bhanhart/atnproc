"""Module for managing a collection of recent capture files.
"""

import logging

from pathlib import Path
from typing import List, Optional

from atnproc.capture_file import CaptureFile


class RecentCaptureFiles:
    """Represents a list of capture files, sorted most recent first."""

    def __init__(self, files: List[CaptureFile]) -> None:
        self._logger: logging.Logger = logging.getLogger(self.__class__.__name__)
        self._recent_files: List[CaptureFile] = sorted(
            files,
            key=lambda file: file.timestamp,
            reverse=True,
        )

    @property
    def num_files(self) -> int:
        return len(self._recent_files)

    @property
    def files(self) -> List[Path]:
        return [file.path for file in self._recent_files]

    @property
    def latest(self) -> Optional[CaptureFile]:
        if len(self._recent_files) == 0:
            return None
        return self._recent_files[0]

    @property
    def previous(self) -> Optional[CaptureFile]:
        if len(self._recent_files) < 2:
            return None
        return self._recent_files[1]
