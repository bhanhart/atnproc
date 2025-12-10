"""Processor implementation for ATN capture processing.

Contains `AtnCaptureProcessor` which implements `ProcessorInterface` and
coordinates discovery of recent capture files and staging them into the
work area for downstream processing.
"""

import logging
from datetime import timedelta
from capture_file_loader import LatestCaptureFiles, RecentCaptureFileLoader
from processor_interface import ProcessorInterface
from config import Configuration
from work_area import WorkArea


class AtnCaptureProcessor(ProcessorInterface):
    """Processor that coordinates capture file discovery and staging.

    Implements `ProcessorInterface.process()` to locate the two most recent
    capture files and stage the appropriate file into the work area for
    downstream processing.
    """
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
