"""Packet processing logic using tcpdump and awk.

This module implements the core logic described in PRD Section 6.2,
handling the extraction and transformation of packets from pcap files.
"""

import logging
from pathlib import Path

from atnproc.process_pipeline import ProcessCommand, ProcessPipeline


class PacketProcessor:
    """Executes tcpdump and awk to process capture files."""

    def __init__(self, filter_ip: str, awk_script: Path) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._filter_ip = filter_ip
        self._awk_script = awk_script
        self._pipeline = ProcessPipeline()

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
            self._pipeline.run(
                commands=[
                    ProcessCommand(cmd=tcpdump_cmd, name="tcpdump"),
                    ProcessCommand(cmd=awk_cmd, name="awk"),
                ],
                output_file=output_file,
            )

        except Exception as e:  # pylint: disable=broad-exception-caught
            self._logger.exception("Failed to process %s: %s", capture_file, e)
