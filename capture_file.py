from datetime import datetime, date
from pathlib import Path


class CaptureFile:
    """Represents a capture file and provides timestamp helpers.

    Extracts a timestamp from the file stem using the expected naming
    convention and exposes convenience properties used by the processing
    code.
    """
    def __init__(self, file: Path):
        self._file: Path = file

    @property
    def date(self) -> date:
        return self.timestamp.date()

    @property
    def timestamp(self) -> datetime:
        return self.parse_timestamp(self._file)

    @staticmethod
    def parse_timestamp(file: Path) -> datetime:
        timestamp_str = file.stem.split("_")[-1]
        return datetime.strptime(timestamp_str, "%Y%m%d%H%M%S")

    @property
    def name(self) -> str:
        return self._file.name

    @property
    def path(self) -> Path:
        return self._file
