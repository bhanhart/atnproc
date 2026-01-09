"""Runner implementation for ATN capture processing.

Contains `ApplicationRunner` which implements `RunnerInterface` and
coordinates discovery of recent capture files and staging them into the
work area for downstream processing.
"""

import logging
from datetime import timedelta
from atnproc.recent_capture_file_loader import RecentCaptureFileLoader
from atnproc.recent_capture_files import RecentCaptureFiles
from atnproc.runner_interface import RunnerInterface
from atnproc.config import Configuration
from atnproc.work_area import WorkArea


class ApplicationRunner(RunnerInterface):
    """Processor that coordinates capture file discovery and staging.

    Implements `RunnerInterface.process()` to locate the two most recent
    capture files and stage the appropriate file into the work area for
    downstream processing.
    """

    def __init__(self, config: Configuration) -> None:
        self._config: Configuration = config
        self._logger: logging.Logger = logging.getLogger(self.__class__.__name__)
        self._work_area = WorkArea(config.work_area)

    def run(self) -> timedelta:
        file_loader = RecentCaptureFileLoader(self._config.capture_directories)
        capture_files = RecentCaptureFiles(file_loader.files)
        self._work_area.ingest_files(capture_files.files)
        if capture_files.latest:
            current_capture_file = self._work_area.get_current_file()
            if not current_capture_file:
                self._logger.info(
                    f"No current capture file, processing: {capture_files.latest}"
                )
                self._work_area.set_current_file(capture_files.latest)
            else:
                self._logger.info(f"Found current capture file: {current_capture_file}")
                if current_capture_file.name == capture_files.latest.name:
                    self._logger.info(
                        f"Processing latest capture file: {current_capture_file}"
                    )
                else:
                    if capture_files.previous:
                        if current_capture_file == capture_files.previous:
                            self._logger.info(
                                f"Processing previous capture file: {capture_files.previous}")
                            self._logger.info(
                                f"Processing latest capture file: {capture_files.latest}")
                            self._work_area.set_current_file(capture_files.latest)
                    else:
                        self._logger.info(
                            f"Processing new capture file: {capture_files.latest}")
                        self._work_area.set_current_file(capture_files.latest)

        return timedelta(seconds=self._config.processing_interval_seconds)
