"""Module for loading recent capture files based on filename timestamps."""

import logging

from datetime import datetime, timedelta
from pathlib import Path
from typing import List

from atnproc.capture_file_name import CaptureFileName
from atnproc.capture_file import CaptureFile
from atnproc.file_loader import FileLoader


class RecentCaptureFileLoader:
    """Loads capture files from today and yesterday based on a date-based glob pattern.

    This class searches specified directories for files from today and, if
    fewer than two files are found, from yesterday. It uses a glob pattern
    that includes the date in 'YYYYMMDD' format (e.g., '*_20230101*.pcap').

    """

    def __init__(self, directories: list[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(self.__class__.__name__)
        self._file_loader = FileLoader(directories)
        self._load_files()

    @property
    def files(self) -> List[CaptureFile]:
        return [CaptureFile(file) for file in self._file_loader.files]

    def _load_files(self) -> None:
        # Load today's files
        today = datetime.today()
        today_str = today.strftime(CaptureFileName.date_format())
        today_pattern = f"*_{today_str}*.pcap"
        self._file_loader.load_files(today_pattern)

        if self._file_loader.num_files < 2:
            # Load yesterday's files
            yesterday = today - timedelta(days=1)
            yesterday_str = yesterday.strftime(CaptureFileName.date_format())
            yesterday_pattern = f"*_{yesterday_str}*.pcap"
            self._file_loader.load_files(yesterday_pattern)
