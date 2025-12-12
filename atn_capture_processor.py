"""Processor implementation for ATN capture processing.

Contains `AtnCaptureProcessor` which implements `ProcessorInterface` and
coordinates discovery of recent capture files and staging them into the
work area for downstream processing.
"""

import logging
from datetime import timedelta
from capture_file_loader import load_recent_capture_files
from capture_file import CaptureFileList
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
        capture_files = CaptureFileList(
            load_recent_capture_files(self._config.capture_directories))
        if capture_files.latest:
            active_capture_file = self._work_area.get_active_file()
            if not active_capture_file:
                self._logger.info(
                    f"No currently active capture file, processing: {capture_files.latest}")
                self._work_area.stage_capture_file(capture_files.latest)
            else:
                self._logger.info(f"Found active capture file: {active_capture_file}")
                if active_capture_file == capture_files.latest:
                    self._logger.info(
                        f"Active capture file is latest available: {active_capture_file}")
                    self._work_area.stage_capture_file(capture_files.latest)
                else:
                    if capture_files.previous and active_capture_file == capture_files.previous:
                        self._logger.info(
                            "Staging previous and latest capture files: "
                            f"{capture_files.previous}, {capture_files.latest}")
                        self._work_area.stage_capture_file(capture_files.previous)
                        self._work_area.stage_capture_file(capture_files.latest)
                    else:
                        self._logger.info(
                            f"Staging new capture file: {capture_files.latest}")
                        self._work_area.stage_capture_file(capture_files.latest)

        return timedelta(seconds=self._config.processing_interval_seconds)
