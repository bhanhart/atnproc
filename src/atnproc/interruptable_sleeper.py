"""Interruptible sleeper utility used by the application run loop.

This module provides the `InterruptibleSleeper` class, that allows the main
application loop to sleep in an interruptible manner so shutdown requests
can wake the sleeper and let the application perform a controlled exit.
"""

import logging
import os
import select
import signal
from datetime import timedelta
from typing import Protocol, Optional


class TerminationHandler(Protocol):
    """Protocol for objects that handle termination signals.

    Implementors should provide ``handle_termination_signal`` which will be
    invoked with the integer signal number when a termination signal is
    received by :class:`InterruptibleSleeper`.
    """

    def handle_termination_signal(self, sig_no: int) -> None:
        ...


class InterruptibleSleeper:
    """Sleeps in an interruptible fashion and forwards termination signals.

    The `InterruptibleSleeper` registers signal handlers for SIGINT and
    SIGTERM and wakes the blocked select() when a termination signal is
    received so the application can handle shutdown promptly.
    """
    def __init__(self, termination_handler: TerminationHandler) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
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
        timeout = duration.total_seconds()
        read_fds, _, _ = select.select([self._read_fd], [], [], timeout)
        timed_out = True
        if read_fds:
            timed_out = False
            os.read(self._read_fd, 1)
        return timed_out

    def close(self) -> None:
        os.close(self._read_fd)
        os.close(self._write_fd)

    def _handle_termination_signal(
        self, signum: int, _frame: Optional[object]
    ) -> None:
        sig_name = signal.Signals(signum).name
        self._logger.info(f"Sleep interrupted (signal={sig_name})")
        if self._termination_callback:
            self._termination_callback.handle_termination_signal(signum)
        os.write(self._write_fd, b'\x01')  # Wake up select()
