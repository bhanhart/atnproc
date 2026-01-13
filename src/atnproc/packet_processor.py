"""Packet processing logic using tcpdump and awk.

This module implements the core logic described in PRD Section 6.2,
handling the extraction and transformation of packets from pcap files.
"""

import logging
import subprocess
from pathlib import Path


class PacketProcessor:
    """Executes tcpdump and awk to process capture files."""

    def __init__(self, filter_ip: str, awk_script: Path) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._filter_ip = filter_ip
        self._awk_script = awk_script

    def process_file(self, capture_file: Path, output_file: Path) -> None:
        """Process the given capture file and write output to output_file.

        Executes tcpdump on the capture file and pipes the output to the
        configured awk script. The result is written (overwritten) to the
        output file.
        """
        # PRD 6.2.2: tcpdump arguments
        tcpdump_cmd = [
            "tcpdump",
            "-r",
            str(capture_file),
            "-n",      # Do not convert host addresses to names
            "-e",      # Output link level header
            "-x",      # Output data in hex
            "-tttt",   # Detailed timestamp
            "-l",      # Line buffered (good practice for pipes)
            f"ip host {self._filter_ip} and proto 80",
        ]

        # PRD 6.2.4: awk command
        awk_cmd = [
            "awk",
            "-v",
            f"RTCD_SNIFFED_ADDRESS={self._filter_ip}",
            "-f",
            str(self._awk_script),
        ]

        self._logger.info(f"Processing {capture_file} -> {output_file}")

        try:
            # PRD 6.2.6: Write to output file
            # We use 'w' to overwrite, ensuring re-processing growing files
            # doesn't result in duplicate logs.
            with open(output_file, "w", encoding="utf-8") as out_f:
                # Pipe: tcpdump | awk > output_file.
                # Using 'with' for Popen ensures that the child processes are
                # waited for, preventing zombies in case of errors.
                tcpdump_proc = subprocess.Popen(
                    tcpdump_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
                with tcpdump_proc:
                    if tcpdump_proc.stdout is None:
                        # This should not happen with stdout=PIPE, but check for safety.
                        _, tcpdump_err = tcpdump_proc.communicate()
                        if tcpdump_proc.returncode != 0:
                            self._logger.error(
                                "tcpdump failed to create pipe: %s",
                                tcpdump_err.decode().strip(),
                            )
                        return

                    awk_proc = subprocess.Popen(
                        awk_cmd,
                        stdin=tcpdump_proc.stdout,
                        stdout=out_f,
                        stderr=subprocess.PIPE,
                    )
                    with awk_proc:
                        # Allow tcpdump to receive SIGPIPE if awk exits.
                        tcpdump_proc.stdout.close()
                        _, awk_err = awk_proc.communicate()

                    # We can't use communicate() on tcpdump_proc as its stdout was
                    # passed to another process and then closed. We read stderr
                    # directly and the 'with' block will wait for the process.
                    tcpdump_err = tcpdump_proc.stderr.read() if tcpdump_proc.stderr else b""

                    if awk_proc.returncode != 0:
                        self._logger.error("awk error: %s", awk_err.decode().strip())

                if tcpdump_proc.returncode != 0:
                    self._logger.error("tcpdump error: %s", tcpdump_err.decode().strip())

        except Exception as e:  # pylint: disable=broad-exception-caught
            self._logger.exception("Failed to process %s: %s", capture_file, e)
