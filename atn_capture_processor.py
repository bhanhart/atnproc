from datetime import timedelta
from processor_interface import ProcessorInterface

class AtnCaptureProcessor(ProcessorInterface):
    def __init__(self, config):
        self.config = config

    def process(self) -> timedelta:
        return timedelta(seconds=10)  # Placeholder implementation
