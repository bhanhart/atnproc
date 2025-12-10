"""Work area helpers for staging and querying the active capture file.

This module contains `WorkArea` which abstracts the local working/active
directory used to stage capture files for processing.
"""

import logging
from pathlib import Path
from typing import Optional
from capture_file import CaptureFile


class WorkArea:
    """Manage the local active/work directory for staging capture files.

    Provides helpers to query the currently staged active capture file and
    to stage a new capture file into the active directory.
    """
    def __init__(self, active_directory: Path):
        self.active_directory = active_directory
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)

    def get_active_file(self) -> Optional[CaptureFile]:
        pattern = "active_capture_*.pcap"
        active_files = list(self.active_directory.glob(pattern))
        if active_files:
            return CaptureFile(active_files[0])
        return None

    def stage_capture_file(self, capture_file: CaptureFile) -> None:
        destination = self.active_directory / capture_file.name
        self._logger.info(
            f"Staging capture file {capture_file.path} to {destination}")
        # Here you would add code to copy/move the file to the active directory
        # For example:
        # import shutil
        # shutil.copy2(capture_file.path, destination)
