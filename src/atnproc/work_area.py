"""Work area helpers for staging and querying the current capture file.

This module contains `WorkArea` which abstracts the local working/current
directory used to stage capture files for processing.
"""

import logging
import shutil
from pathlib import Path
from typing import Optional
from atnproc.capture_file import CaptureFile
from atnproc.config import WorkAreaConfig


class WorkArea:
    """Manage the local current/work directory for staging capture files.

    Provides helpers to query the currently staged current capture file and
    to stage a new capture file into the current directory.
    """
    def __init__(self, config: WorkAreaConfig):
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._input_directory = config.input_directory
        self._current_directory = config.current_directory
        self._output_directory = config.output_directory

    def ingest_files(self, files: list[Path]) -> None:
        for src_file in files:
            dst_file = self._input_directory / src_file.name
            shutil.copy2(src_file, dst_file)
            self._logger.debug(f"Copied {src_file} to {dst_file}")

    def get_current_file(self) -> Optional[CaptureFile]:
        current_files = list(self._current_directory.glob("*.pcap"))
        if current_files:
            return CaptureFile(current_files[0])
        return None

    def set_current_file(self, capture_file: CaptureFile) -> None:
        dst_file = self._current_directory / str(capture_file.name)
        shutil.copy2(capture_file.path, dst_file)
        self._logger.debug(f"Copied {capture_file.path} to {dst_file}")
