from datetime import timedelta
import logging
import signal
import threading
from config import Configuration
from interruptable_sleeper import InterruptibleSleeper


class Application:
    def __init__(self, config: Configuration):
        self._logger: logging.Logger = logging.getLogger(__class__.__name__)
        self._config = config
        self._shutdown_requested: threading.Event = threading.Event()
        self._logger.info("Application initialized")

    def run(self):
        self._logger.info("Application running")
        sleeper = InterruptibleSleeper(self)
        while not self._shutdown_requested.is_set():
            self._logger.info("Application sleeping...")
            sleeper.sleep(timedelta(seconds=5))
        self._logger.info("Shutdown requested, exiting application")
        sleeper.close()

    def handle_termination_signal(self, sig_no: int) -> None:
        self._logger.info(f"Shutdown request (signal={signal.Signals(sig_no).name})")
        self._shutdown_requested.set()