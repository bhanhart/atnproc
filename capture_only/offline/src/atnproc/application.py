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
from atnproc.packet_processor import PacketProcessor


class Application(RunnerInterface):
    """Main application functionality.

    Implements `RunnerInterface.run()` to locate the two most recent
    capture files and stage the appropriate file into the work area for
    downstream processing.
    """

    def __init__(self, config: Configuration) -> None:
        self._config: Configuration = config
        self._logger: logging.Logger = logging.getLogger(self.__class__.__name__)
        self._work_area = WorkArea(config.work_directories)
        self._processor = PacketProcessor(
            filter_ip=config.filter_ip,
            awk_script=config.awk_script,
        )

    def run(self) -> timedelta:
        file_loader = RecentCaptureFileLoader(self._config.capture_directories)
        capture_files = RecentCaptureFiles(file_loader.files)
        self._work_area.ingest_files(capture_files.files)
        if capture_files.latest:
            current_capture_file = self._work_area.get_current_capture_file()
            if not current_capture_file:
                self._logger.info(
                    f"No current capture file. Initializing with: {capture_files.latest}"
                )
                # Initial Run (PRD 6.1.4)
                if capture_files.previous:
                    self._work_area.set_current_file(capture_files.previous)
                    self._process_current_file()

                self._work_area.set_current_file(capture_files.latest)
                self._process_current_file()
            else:
                self._logger.info(f"Found current capture file: {current_capture_file}")
                if current_capture_file.name == capture_files.latest.name:
                    # Steady State: Existing File Updated (PRD 6.1.5)
                    # Check if size has increased
                    if (
                        capture_files.latest.path.stat().st_size
                        > current_capture_file.path.stat().st_size
                    ):
                        self._logger.info(
                            f"File grew, re-processing: {current_capture_file}"
                        )
                        self._work_area.set_current_file(capture_files.latest)
                        self._process_current_file()
                else:
                    # Steady State: New File Detected (PRD 6.1.5)
                    if capture_files.previous:
                        if current_capture_file == capture_files.previous:
                            self._logger.info(
                                f"Finishing previous file: {capture_files.previous}"
                            )
                            # Re-process previous one last time to ensure completion
                            self._work_area.set_current_file(capture_files.previous)
                            self._process_current_file()
                    else:
                        # Fallback if previous is missing but we have a new latest
                        pass

                    self._logger.info(f"Moving to new file: {capture_files.latest}")
                    self._work_area.set_current_file(capture_files.latest)
                    self._process_current_file()

        return timedelta(seconds=self._config.processing_interval_seconds)

    def _process_current_file(self) -> None:
        """Helper to trigger processing on the file currently staged in the work area."""
        current_file = self._work_area.get_current_capture_file()
        if current_file:
            # Output file: <name>.log in the configured output directory
            output_name = current_file.path.with_suffix(".log").name
            output_path = self._config.work_directories.output / output_name
            self._processor.process_file(current_file.path, output_path)
