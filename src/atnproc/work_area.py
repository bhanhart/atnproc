"""Work area helpers for staging and querying the current capture file.

This module contains `WorkArea` which abstracts the local working/current
directory used to stage capture files for processing.
"""

import logging
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
        for file in files:
            self._logger.debug(f"Ingested file into work area: {file}")

    def get_current_file(self) -> Optional[CaptureFile]:
        pattern = "active_capture_*.pcap"
        active_files = list(self._current_directory.glob(pattern))
        if active_files:
            return CaptureFile(active_files[0])
        return None

    def set_current_file(self, capture_file: CaptureFile) -> None:
        destination = self._current_directory / capture_file.name
        self._logger.info(
            f"Staging capture file {capture_file.path} to {destination}")
        # Here you would add code to copy/move the file to the current directory
        # For example:
        # import shutil
        # shutil.copy2(capture_file.path, destination)
