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
import sys
from pathlib import Path

from application import Application
from atn_capture_processor import AtnCaptureProcessor

from config import Configuration

import logging.config

import yaml


logger: logging.Logger | None = None


def info(message: str):
    if logger:
        logger.info(message)
    else:
        print(message)


def fatal(message: str):
    if logger:
        logger.fatal(f"FATAL: {message}")
    else:
        print(f"FATAL: {message}")
    sys.exit(1)


def get_config_file_path() -> Path:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-c", "--config-file", type=str, required=True, help="Configuration file"
    )
    args = parser.parse_args()
    config_file = Path(args.config_file)
    if not config_file.is_file():
        fatal(f"Configuration file does not exist: {config_file}")
    return config_file


def configure_logging():
    log_dir = Path("./log")
    log_dir.mkdir(exist_ok=True)
    with open("logging.yaml", "r") as f:
        logging.config.dictConfig(yaml.safe_load(f))


def main() -> int:
    config = Configuration(get_config_file_path())
    processor = AtnCaptureProcessor(config)
    application = Application(processor)
    application.run()
    return 0


if __name__ == "__main__":
    try:
        configure_logging()
        logger = logging.getLogger(__name__)
        exit_code = main()
        info(f"Normal exit with exit code: {exit_code}")
    except Exception as exc:
        fatal(f"Unexpected exception: {exc}")
        fatal("Exiting...")
        exit_code = 1
    sys.exit(exit_code)
