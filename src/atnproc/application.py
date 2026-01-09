"""
The ApplicationLoop class provides a generic event loop and support for
graceful shutdown.

Functionality:

- Constructed with with a `RunnerInterface` instance.
- Repeatedly calls `runner.run()` to perform work; that method
    returns a `datetime.timedelta` indicating how long the application should
    sleep before the next iteration.
- Uses `InterruptibleSleeper` to sleep in an interruptible manner so shutdown
    can interrupt the sleep period.
- Provides `handle_termination_signal(sig_no)` which marks a shutdown request
    (suitable to be registered as a SIGINT/SIGTERM handler).

The module's responsibility is lifecycle and orchestration of the run loop
and allows for graceful shutdown of the application.
"""

from datetime import timedelta
import logging
import signal
import threading
from atnproc.interruptable_sleeper import InterruptibleSleeper
from atnproc.runner_interface import RunnerInterface


class ApplicationLoop:
    """Generic application run loop.

    The :class:`ApplicationLoop` repeatedly calls ``runner.run()`` and
    uses :class:`InterruptibleSleeper` to sleep between iterations while
    allowing graceful shutdown via signals.
    """

    def __init__(self, runner: RunnerInterface) -> None:
        self._logger: logging.Logger = logging.getLogger(
            self.__class__.__name__)
        self._runner = runner
        self._shutdown_requested: threading.Event = threading.Event()
        self._logger.info("Application initialized")

    def start(self) -> None:
        self._logger.info("Application running")
        sleeper = InterruptibleSleeper(self)
        while not self._shutdown_requested.is_set():
            self._logger.debug("Run loop iteration starting...")
            sleep_duration: timedelta = self._runner.run()
            self._logger.debug("Run loop iteration finished")
            self._logger.debug(f"Sleeping for {sleep_duration.total_seconds()} seconds...")
            sleeper.sleep(sleep_duration)
        self._logger.info("Shutdown requested, exiting application")
        sleeper.close()

    def handle_termination_signal(self, sig_no: int) -> None:
        sig_name = signal.Signals(sig_no).name
        self._logger.info(f"Shutdown request (signal={sig_name})")
        self._shutdown_requested.set()
