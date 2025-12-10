"""Helpers to discover recent capture files using today/previous-day logic.

This module exposes `RecentCaptureFileLoader`, `FileLoader` and
`LatestCaptureFiles` to find and compare the two most recent capture files
based on timestamps embedded in filenames.
"""

import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional
from capture_file import CaptureFile


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

    def is_latest(self, capture_file: CaptureFile) -> bool:
        if self._latest is None:
            return False
        return self._latest.name == capture_file.name

    @property
    def latest(self) -> Optional[CaptureFile]:
        return self._latest

    def is_previous(self, capture_file: CaptureFile) -> bool:
        if self._previous is None:
            return False
        return self._previous.name == capture_file.name

    @property
    def previous(self) -> Optional[CaptureFile]:
        return self._previous


class FileLoader:
    """Load files from a list of directories using a glob pattern.

    This is a small utility used by `RecentCaptureFileLoader` to collect
    matching files from multiple directories.
    """
    def __init__(self, directories: list[Path], pattern: str) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._files: list[Path] = []
        self.load_files(directories, pattern)

    def load_files(self, directories: list[Path], pattern: str) -> None:
        for directory in directories:
            files: list[Path] = list(directory.glob(pattern))
            self._logger.debug(
                f"Found {len(files)} file(s) in {directory} "
                f"with pattern {pattern}")
            self._files.extend(files)

    @property
    def num_files(self) -> int:
        return len(self._files)

    @property
    def files(self) -> List[Path]:
        return self._files


class RecentCaptureFileLoader:
    """Find recent capture files using a today-then-yesterday strategy.

    Collects capture files matching today's date and, if fewer than two
    are found, also collects yesterday's files to ensure two recent files
    are available for processing.
    """
    def __init__(self) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._files: list[Path] = []

    def load_files(self, directories: list[Path]) -> None:
        self._files = []  # Reset on each call
        today = datetime.today()

        # Load today's files
        today_pattern = f"*_{self._date_to_str(today)}*.pcap"
        today_loader = FileLoader(directories, today_pattern)
        self._files.extend(today_loader.files)

        if len(self._files) < 2:
            yesterday = today - timedelta(days=1)
            yesterday_pattern = f"*_{self._date_to_str(yesterday)}*.pcap"
            yesterday_loader = FileLoader(directories, yesterday_pattern)
            self._files.extend(yesterday_loader.files)

    def empty(self) -> bool:
        return not self._files

    @property
    def files(self) -> List[Path]:
        return self._files

    @staticmethod
    def _date_to_str(date: datetime) -> str:
        return date.strftime("%Y%m%d")
