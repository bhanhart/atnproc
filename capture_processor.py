import dpkt
import logging
import json
import shutil
import socket
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterator, Tuple

from config import Configuration

logger = logging.getLogger(__name__)

# Define the IP protocol number for ISO-on-TCP
ISO_ON_TCP_PROTO = 80


class CaptureFile:
    def __init__(self, file: Path):
        self._file: Path = file

    @property
    def date(self) -> datetime.date:
        return self.timestamp.date()

    @property
    def timestamp(self) -> datetime:
        return self.parse_timestamp(self)

    @staticmethod
    def parse_timestamp(file: Path) -> datetime:
        timestamp_str = file.stem.split("_")[-1]
        return datetime.strptime(timestamp_str, "%Y%m%d%H%M%S")


class LatestCaptureFiles:
    def __init__(self, files: list[Path]) -> None:
        self._logger: logging.Logger = logging.getLogger(__class__.__name__)
        self._latest: CaptureFile|None = None
        self._previous: CaptureFile|None = None
        sorted_files: list[Path] = sorted(
            files,
            key=CaptureFile.parse_timestamp,
            reverse=True
        )[:2]
        if len(sorted_files) > 0:
            self._latest = CaptureFile(sorted_files[0])
            if len(sorted_files) > 1:
                self._previous = CaptureFile(sorted_files[1])

    def is_latest(self, capture_file: CaptureFile) -> bool:
        return self._latest and self._latest.name == capture_file.name

    @property
    def latest(self) -> CaptureFile:
        return self._latest

    def is_previous(self, capture_file: CaptureFile):
        return self._previous and self._previous.name == capture_file.name

    @property
    def previous(self) -> CaptureFile:
        return self._previous


class FileLoader:
    def __init__(self, directories: list[Path], pattern: str) -> None:
        self._logger: logging.Logger = logging.getLogger(__class__.__name__)
        self._files: list[Path] = []
        self.load_files(directories, pattern)

    def load_files(self, directories: list[Path], pattern: str) -> None:
        for directory in directories:
            files: list[Path] = list(directory.glob(pattern))
            self._logger.debug(f"Found {len(files)} file(s) in {directory} with pattern {pattern}")
            self._files.extend(files)

    @property
    def num_files(self):
        return len(self._files)

    @property
    def files(self) -> list[Path]:
        return self._files


class RecentCaptureFileLoader:
    def __init__(self):
        self._logger: logging.Logger = logging.getLogger(__class__.__name__)
        self._files: list[Path] = []

    def load_files(self, directories: list[Path]) -> None:
        self._files = []  # Reset on each call
        today = datetime.today()

        # Load today's files
        today_loader = FileLoader(directories, f"*_{self._date_to_str(today)}*.pcap")
        self._files.extend(today_loader.files)

        if len(self._files) < 2:
            yesterday = today - timedelta(days=1)
            yesterday_loader = FileLoader(directories, f"*_{self._date_to_str(yesterday)}*.pcap")
            self._files.extend(yesterday_loader.files)

    def emtpy(self):
        return not self._files

    @property
    def files(self):
        return self._files

    @staticmethod
    def _date_to_str(date: datetime) -> str:
        return date.strftime("%Y%m%d")


class ProcessorState:
    """Manages the processing state (file offsets) via a JSON file."""
    def __init__(self, state_file: Path):
        self._logger: logging.Logger = logging.getLogger(__class__.__name__)
        self._state_file = state_file
        self._offsets = self._load()

    def _load(self) -> dict[str, int]:
        if not self._state_file.exists():
            return {}
        try:
            with self._state_file.open('r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            self._logger.error(f"Could not load state file {self._state_file}: {e}")
            return {}

    def save(self):
        with self._state_file.open('w') as f:
            json.dump(self._offsets, f, indent=2)

    def get_offset(self, file: Path) -> int:
        return self._offsets.get(file.name, 0)

    def set_offset(self, file: Path, offset: int):
        self._offsets[file.name] = offset

    def cleanup(self, active_files: list[Path]):
        """Remove state for files that are no longer active."""
        active_filenames = {f.name for f in active_files}
        stale_keys = [k for k in self._offsets if k not in active_filenames]
        for key in stale_keys:
            self._logger.debug(f"Removing stale state for file: {key}")
            del self._offsets[key]


def process_pcap_stream(
    pcap_path: Path,
    filter_ip: str,
    start_offset: int = 0
) -> Iterator[Tuple[float, str, str, bytes, int]]:
    """
    Processes a PCAP file, filtering for specific packets, starting from a given offset.

    Args:
        pcap_path: The path to the .pcap file.
        filter_ip: The IP address to filter on (source or destination).
        start_offset: The byte offset from which to start processing.

    Yields:
        A tuple containing:
        - timestamp (float)
        - direction (str, 'SENT' or 'RCVD')
        - remote_ip (str)
        - payload (bytes, the ISO-on-TCP data)
        - end_offset (int, file offset after this packet)
    """
    if not pcap_path.exists():
        return

    with pcap_path.open('rb') as f:
        try:
            pcap_reader = dpkt.pcap.Reader(f)
        except (dpkt.dpkt.UnpackError, ValueError) as e:
            logger.error(f"Error: Could not parse PCAP header in {pcap_path}: {e}")
            return

        current_offset = f.tell()

        for timestamp, buf in pcap_reader:
            if current_offset >= start_offset:
                try:
                    eth = dpkt.ethernet.Ethernet(buf)
                    if not isinstance(eth.data, dpkt.ip.IP):
                        current_offset = f.tell()
                        continue

                    ip = eth.data
                    if ip.p == ISO_ON_TCP_PROTO:
                        src_ip = socket.inet_ntoa(ip.src)
                        dst_ip = socket.inet_ntoa(ip.dst)

                        if filter_ip in (src_ip, dst_ip):
                            direction = "SENT" if src_ip == filter_ip else "RCVD"
                            remote_ip = dst_ip if direction == "SENT" else src_ip
                            yield timestamp, direction, remote_ip, ip.data, f.tell()

                except dpkt.dpkt.UnpackError:
                    pass  # Skip malformed packets
            current_offset = f.tell()


def format_output_line(timestamp: float, direction: str, remote


def process_capture_files(config: Configuration) -> None:
    work_area = WorkArea(config.active_directory)

    capture_files = RecentCaptureFileLoader()
    capture_files.load_files(config.capture_directories)
    if not capture_files.emtpy():
        latest_files = LatestCaptureFiles(capture_files.files)
        active_file: CaptureFile = work_area.get_active_file()
        if active_file:
            logger.info(f"Found active file: {active_file}")
            if latest_files.is_latest(active_file):
                logger.info(f"Active file is latest available: {active_file}")
            elif latest_files.is_previous(active_file):
                logger.info(f"Active file is latest available: {active_file}")
        else:
            logger.info(f"No currently active file, processing: {latest_files.latest}")
            work_area.stage_capture_file(latest_files.latest)
