from abc import ABC, abstractmethod
from datetime import timedelta


class ProcessorInterface(ABC):
    @abstractmethod
    def process(self) -> timedelta:
        pass
