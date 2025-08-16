import logging
import os
import select
import signal
from datetime import timedelta
from typing import Protocol

class TerminationHandler(Protocol):
    def handle_termination_signal(self, sig_no: int) -> None:
        ...


class InterruptibleSleeper:
    def __init__(self, termination_handler: TerminationHandler) -> None:
        self._logger = logging.getLogger(__class__.__name__)
        self._termination_callback = termination_handler
        self._read_fd, self._write_fd = os.pipe()
        signal.signal(signal.SIGTERM, self._handle_termination_signal)
        signal.signal(signal.SIGINT, self._handle_termination_signal)

    def sleep(self, duration: timedelta) -> bool:
        """
        Sleeps for the given duration
        Returns True if the select timed-out, i.e., the sleep completed
        Returns False if interrupted by a termination signal.
        """
        read_fds, _, _ = select.select([self._read_fd], [], [], duration.total_seconds())
        timed_out = True
        if read_fds:
            timed_out = False
            os.read(self._read_fd, 1)
        return timed_out

    def close(self):
        os.close(self._read_fd)
        os.close(self._write_fd)

    def _handle_termination_signal(self, signum, _frame):
        self._logger.info(f"Sleep interrupted (signal={signal.Signals(signum).name})")
        if self._termination_callback:
            self._termination_callback.handle_termination_signal(signum)
        os.write(self._write_fd, b'\x01')  # Wake up select()
