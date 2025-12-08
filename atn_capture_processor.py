import logging
from datetime import timedelta
from pathlib import Path
from typing import Optional
from capture_file import CaptureFile
from capture_file_loader import LatestCaptureFiles, RecentCaptureFileLoader
from processor_interface import ProcessorInterface
from config import Configuration


class WorkArea:
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
        # shutil.copy(capture_file.path, destination)


class AtnCaptureProcessor(ProcessorInterface):
    def __init__(self, config: Configuration) -> None:
        self._config: Configuration = config
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._work_area = WorkArea(config.active_directory)

    def process(self) -> timedelta:
        capture_files = RecentCaptureFileLoader()
        capture_files.load_files(self._config.capture_directories)
        if not capture_files.empty():
            latest_files = LatestCaptureFiles(capture_files.files)
            active_file = self._work_area.get_active_file()
            if active_file:
                self._logger.info(f"Found active file: {active_file}")
                if latest_files.is_latest(active_file):
                    self._logger.info(
                        f"Active file is latest available: {active_file}")
                elif latest_files.is_previous(active_file):
                    self._logger.info(
                        f"Active file is previous available: {active_file}")
            elif latest_files.latest:
                latest = latest_files.latest
                self._logger.info(
                    f"No currently active file, processing: {latest}")
                self._work_area.stage_capture_file(latest)

        return timedelta(seconds=10)  # Placeholder implementation
