"""Helpers to discover recent capture files using today/previous-day logic.

This module exposes `RecentCaptureFileLoader` and `FileLoader` to find and
compare the two most recent capture files based on timestamps embedded in
filenames.
"""

import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import List


class _FileLoader:
    """Load files from a list of directories using a glob pattern.

    Subsequent calls to `load_files()` will append to the existing list of
    loaded files.
    """
    def __init__(self, directories: list[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._directories = directories
        self._files: list[Path] = []

    def load_files(self, pattern: str) -> None:
        for directory in self._directories:
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


def load_recent_capture_files(directories: list[Path]) -> List[Path]:
    """Load recent capture files from the given directories.

    Collects capture files matching today's date and, if fewer than two
    are found, also collects yesterday's files.
    This ensures that after a day change, the latest two files (if available)
    can be provided for processing.
    """

    def _date_to_str(date: datetime) -> str:
        return date.strftime("%Y%m%d")

    file_loader: _FileLoader = _FileLoader(directories)

    # Load today's files
    today = datetime.today()
    today_pattern = f"*_{_date_to_str(today)}*.pcap"
    file_loader.load_files(today_pattern)

    if file_loader.num_files < 2:
        # Load yesterday's files
        yesterday = today - timedelta(days=1)
        yesterday_pattern = f"*_{_date_to_str(yesterday)}*.pcap"
        file_loader.load_files(yesterday_pattern)

    return file_loader.files
