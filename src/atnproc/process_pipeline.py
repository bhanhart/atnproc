"""Module for executing piped processes."""

from __future__ import annotations

import logging
import subprocess
from contextlib import ExitStack
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ProcessCommand:
    """Encapsulates a command and its display name."""
    cmd: list[str]
    name: str


class ProcessPipeline:
    """Executes a chain of processes, piping the output of one into the next."""

    def __init__(self) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)

    def run(
        self,
        commands: list[ProcessCommand],
        output_file: Path,
    ) -> None:
        """Runs cmd1 | cmd2 | ... | cmdN > output_file.

        Args:
            commands: A list of process definitions to execute in the pipeline.
            output_file: Path to the file where the last process's stdout will be written.
        """
        if not commands:
            return

        procs: list[tuple[subprocess.Popen[bytes], str]] = []
        prev_stdout = None

        with ExitStack() as stack:
            out_f = stack.enter_context(open(output_file, "w", encoding="utf-8"))
            for i, command in enumerate(commands):
                is_last = i == len(commands) - 1
                stdout = out_f if is_last else subprocess.PIPE
                stdin = prev_stdout

                proc = stack.enter_context(
                    subprocess.Popen(
                        command.cmd,
                        stdin=stdin,
                        stdout=stdout,
                        stderr=subprocess.PIPE,
                    )
                )
                procs.append((proc, command.name))

                # Close the read end of the previous pipe in the parent
                # so that only the child has it open.
                if prev_stdout:
                    prev_stdout.close()

                prev_stdout = proc.stdout

            self._wait_for_pipeline(procs)

    def _wait_for_pipeline(
        self, procs: list[tuple[subprocess.Popen[bytes], str]]
    ) -> None:
        """Waits for processes in the pipeline to finish and logs errors."""
        # Wait for the last process to finish first (the sink)
        last_proc, last_name = procs[-1]
        _, last_err = last_proc.communicate()

        if last_proc.returncode != 0:
            self._logger.error(
                "%s error: %s", last_name, last_err.decode().strip()
            )

        # Handle upstream processes in reverse order
        for proc, name in reversed(procs[:-1]):
            # We can't use communicate() because we closed stdout in parent.
            # Read stderr directly.
            err_output = proc.stderr.read() if proc.stderr else b""
            proc.wait()

            if proc.returncode != 0:
                self._logger.error(
                    "%s error: %s", name, err_output.decode().strip()
                )
