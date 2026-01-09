"""Runner interface contract.

Modules implementing a processing loop should implement `RunnerInterface`
and return a `datetime.timedelta` from `process()` indicating how long the
application should sleep before the next iteration.
"""

from abc import ABC, abstractmethod
from datetime import timedelta


class RunnerInterface(ABC):
    """Abstract interface for processing loops used by the application.

    Implementations should return a :class:`datetime.timedelta` from
    :meth:`process` indicating how long the :class:`Application` should
    sleep before the next iteration.
    """

    @abstractmethod
    def run(self) -> timedelta:
        """Perform a unit of work and return the desired sleep interval."""
        raise NotImplementedError()
