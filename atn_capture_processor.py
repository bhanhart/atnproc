"""Processor implementation for ATN capture processing.

Contains `AtnCaptureProcessor` which implements `ProcessorInterface` and
coordinates discovery of recent capture files and staging them into the
work area for downstream processing.
"""

import logging
from datetime import timedelta
from capture_file_loader import CaptureFileLoader
from capture_file import CaptureFile, LatestCaptureFiles
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
        capture_files = CaptureFileLoader()
        capture_files.load_files(self._config.capture_directories)
        latest_capture_files = LatestCaptureFiles(capture_files.files)
        latest_capture_file: CaptureFile|None = latest_capture_files.latest
        if latest_capture_file:
            active_capture_file = self._work_area.get_active_file()
            if not active_capture_file:
                self._logger.info(
                    f"No currently active capture file, processing: {latest_capture_file}")
                self._work_area.stage_capture_file(latest_capture_file)
            else:
                self._logger.info(f"Found active capture file: {active_capture_file}")
                if latest_capture_files.is_equal_to_latest(active_capture_file):
                    self._logger.info(
                        f"Active capture file is latest available: {active_capture_file}")
                elif latest_capture_files.is_equal_to_previous(active_capture_file):
                    self._logger.info(
                        f"Active capture file is the previous capture file: {active_capture_file}")
                else:
                    self._logger.info(
                        f"Staging new capture file: {latest_capture_file}")
                    self._work_area.stage_capture_file(latest_capture_file)

        return timedelta(seconds=self._config.processing_interval_seconds)
