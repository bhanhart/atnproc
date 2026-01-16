"""Capture file name parsing.

This module provides the :class:`CaptureFileName` helper which wraps a
filename string and extracts the timestamp from capture files that conform
to the expected naming convention:
    <host>_<interface>_<count>_<date><time>.pcap.
where:
- <host> is the hostname or IP address of the capture source.
- <interface> is the network interface on which the capture was taken.
- <count> is a numeric counter.
- <date> is the date in YYYYMMDD format.
- <time> is the time in HHMMSS format.
"""

from datetime import datetime, date


class CaptureFileName:
    """Represents a capture file name and provides access to the file's
    creation timestamp.

    Extracts a timestamp from the file stem using the expected naming
    convention.
    """

    def __init__(self, file_name: str):
        self._file_name: str = file_name
        file_stem = file_name.rsplit('.', 1)[0]
        timestamp_str = file_stem.rsplit('_', 1)[-1]
        self._timestamp: datetime = datetime.strptime(
            timestamp_str, f"{self.date_format()}{self.time_format()}"
        )

    @staticmethod
    def date_format() -> str:
        return "%Y%m%d"

    @staticmethod
    def time_format() -> str:
        return "%H%M%S"

    @property
    def timestamp(self) -> datetime:
        """Extracts and returns the timestamp from the filename."""
        return self._timestamp

    @property
    def date(self) -> date:
        """Returns the date part of the timestamp."""
        return self._timestamp.date()

    @property
    def name(self) -> str:
        """Returns the name of the file (stem)."""
        return self._file_name

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, CaptureFileName):
            return NotImplemented
        return self._file_name == other._file_name

    def __hash__(self) -> int:
        return hash(self._file_name)

    def __str__(self) -> str:
        """Return the original filename for human-readable representations."""
        return self._file_name
