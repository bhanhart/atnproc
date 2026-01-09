#!/usr/bin/env python3
"""
ATN LAN Capture Processor (ALCP)

Implementation outline:
- Load capture files from the RLI export directories from both ATN routers
- Assume the interval in which we process the capture files is such that we
  only need to process at most the 2 most recent files (e.g. process every
  minute and each capture file contains 1 hour of traffic).
- We need the 2 most recent files to make sure we have fully processed the
  file before the most recent one before we process the most recent file.
- For each directory:
   Load all files from today using the glob pattern '*<today-date>*.pcap'
   If there are fewer than 2 files, also load yesterday's files
- Determine the 2 most recent capture files and copy these to a working
  directory to prevent file changes due to a running RLI rsync.
- If this is the 1st time processing captures, process the most recent file
- Move the most recent capture file to a separate "active" directory and
  remove any remaining files from the work directory.
- If there is a file in the "active" directory:
   If the filename is equal to the most recent file in the work directory
    If the size of the file in the work directory is > the size of the file in
    the "active" directory
     Process
     Move the most recent file in the work directory to the "active"
     directory
"""

import argparse
import logging
import logging.config
import sys
from pathlib import Path

import yaml

from atnproc.application import ApplicationLoop
from atnproc.application_runner import ApplicationRunner
from atnproc.config import Configuration


class MainApp:
    """Main application class"""

    def __init__(self) -> None:
        """Initialize the main application"""
        self.logger: logging.Logger | None = None

    def log_info(self, message: str) -> None:
        """Log an info message"""
        if self.logger:
            self.logger.info(message)
        else:
            print(message)

    def log_fatal(self, message: str) -> None:
        """Log a fatal error and exit"""
        if self.logger:
            self.logger.fatal(f"FATAL: {message}")
        else:
            print(f"FATAL: {message}")
        sys.exit(1)

    def log_exception(self, message: str) -> None:
        """Log an exception"""
        if self.logger:
            self.logger.exception(f"EXCEPTION: {message}")
        else:
            print(f"EXCEPTION: {message}")

    def get_config_file_path(self) -> Path:
        """Parse command line arguments and return the config file path"""
        parser = argparse.ArgumentParser()
        parser.add_argument(
            "-c",
            "--config-file",
            type=str,
            required=True,
            help="Configuration file",
        )
        args = parser.parse_args()
        config_file = Path(args.config_file)
        if not config_file.is_file():
            self.log_fatal(f"Configuration file does not exist: {config_file}")
        return config_file

    def configure_logging(self) -> None:
        """Configure logging from a YAML file"""
        log_dir = Path("./log")
        log_dir.mkdir(exist_ok=True)
        with open("config/logging.yaml", "r", encoding="utf-8") as f:
            logging.config.dictConfig(yaml.safe_load(f))

    def main(self) -> None:
        """Main application entry point"""
        self.configure_logging()
        self.logger = logging.getLogger(__name__)
        exit_status = 0
        try:
            config = Configuration(self.get_config_file_path())
            runner = ApplicationRunner(config)
            main_loop = ApplicationLoop(runner)
            main_loop.start()
        except KeyboardInterrupt:
            self.log_info("Interrupted by user (KeyboardInterrupt)")
            # Standard POSIX exit code for terminated by Ctrl+C
            sys.exit(130)
        except SystemExit as se:
            # Allow explicit sys.exit() calls to propagate after logging.
            self.log_info(f"Exit requested: {se.code}")
            raise
        except Exception:  # pylint: disable=broad-exception-caught
            # Log the full traceback for unexpected exceptions and exit with 1.
            self.log_exception("Unexpected exception during run")
            sys.exit(1)
        else:
            self.log_info(f"Normal exit with exit code: {exit_status}")
            sys.exit(exit_status)


if __name__ == "__main__":
    MainApp().main()
