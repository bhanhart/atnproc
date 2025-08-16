# ATN Network Capture Processor (ANCP) - Product Requirements

## 1. Overview

The ATN Network Capture Processor (ANCP) is a standalone application designed to automate the processing of network traffic captures from ATN (Aeronautical Telecommunication Network) routers.

The primary function of the ANCP is to monitor specified directories for incoming `.pcap` files, extract relevant ATN network packets based on a specific IP address, and transform these packets into a line-delimited text format. These output files are intended for ingestion by data shippers like Elasticsearch Filebeat, facilitating near real-time analysis and monitoring of ATN communications.

The system is designed to handle capture files that are continuously transferred via `rsync` from remote hosts, meaning the most recent file may be incomplete and growing.

## 2. Goals

- **Automate Processing**: To fully automate the extraction and transformation of ATN network traffic from raw PCAP files.
- **Ensure Data Integrity**: To implement a processing strategy that guarantees all packets from a capture file are processed, even when files are being actively written to.
- **Timely Data Availability**: To make processed data available for analysis within a short, predictable timeframe.
- **Create a Data Pipeline**: To serve as a reliable data source for an external log analysis and monitoring platform (e.g., the ELK Stack).

## 3. Functional Requirements

| ID    | Requirement                                                                                                                                                           |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FR-1  | **File Ingestion**: The application shall monitor two specified source directories (e.g., NFS mounts) for network capture files.                                        |
| FR-2  | **File Filtering**: The application shall identify and process files with a `.pcap` extension.                                                                        |
| FR-3  | **Packet Filtering**: The application shall extract network packets from capture files that are related to a specific, configurable IP address and ATN protocol.        |
| FR-4  | **Data Transformation**: The application shall convert each extracted ATN packet into a single-line text record.                                                        |
| FR-5  | **Output Generation**: The application shall write the transformed text records to output files in a designated directory, ready for consumption by Filebeat.           |
| FR-6  | **Handling of Growing Files**: The application must correctly process capture files that may be growing in size due to an ongoing `rsync` transfer.                      |
| FR-7  | **Sequential Processing**: When a new capture file is detected, the application must first ensure the *previous* capture file has been fully processed before starting the new one. |

## 4. Non-Functional Requirements

| ID     | Requirement                                                                                                                                                           |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NFR-1  | **Platform**: The application shall be a stand-alone Python application, compatible with Python version 3.9 or newer.                                                   |
| NFR-2  | **Performance**: The application shall detect new or updated capture files within a maximum of one minute from their arrival in the source directories.                 |
| NFR-3  | **Configuration**: All key operational parameters (e.g., source/work directories, filter IP address) shall be configurable via a single configuration file in YAML format. |
| NFR-4  | **Reliability**: The application shall run continuously as a service and handle graceful shutdowns upon receiving `SIGINT` or `SIGTERM` signals.                        |
| NFR-5  | **Logging**: The application must provide comprehensive logging to both the console and a rotating log file for operational monitoring and debugging purposes.          |

## 5. File Naming and Selection

### 5.1. Filename Format
The network capture filenames are expected to follow this format:
`
<host>_<interface>_<count>_<date><time>.pcap
`
-   **prefix**: Identifier for the source router, e.g., `atnr01` or `atnr02`.
-   **interface**: Network interface, e.g., `net3`.
-   **count**: An integer counter, formatted with leading zeros (e.g., `%05d`).
-   **date**: The date of the capture start time, in `YYYYMMDD` format.
-   **time**: The time of the capture start time, in `HHMMSS` format.

The timestamp (`<date><time>`) is used to determine the chronological order of the files.

### 5.2. File Selection Logic
To determine which files to process, the application shall:
1.  Scan the source directories for files matching today's date (`*_<YYYYMMDD>*.pcap`).
2.  If fewer than two files are found for the current day, the application shall also scan for files from the previous day.
3.  From the collected list, the two most recent files (based on the filename timestamp) are considered the `latest` and `previous` files for the processing cycle.

## 6. Processing Strategy

To handle growing files and ensure no data is missed, the application will use a working directory and a stateful processing loop. The guiding principle is that older files must be fully processed before newer files.

1.  **Identify Candidates**: In each cycle, identify the two most recent capture files from the source directories (referred to as `latest` and `previous`).
2.  **Copy to Work Area**: To prevent issues with `rsync` changing a file during processing, copy the candidate files to a local working directory for processing.
3.  **State Management**: Maintain the concept of an "active" file, which is the file currently being processed. This file's state is tracked by its presence in a dedicated "active" directory.
4.  **Initial Run**: If no "active" file exists:
    -   If a `previous` file is identified, it is processed first.
    -   The `latest` file is then processed and staged as the new "active" file.
5.  **Steady State Operation**: On subsequent runs:
    -   **New File Detected**: If the `latest` file from the source is newer than the "active" file, the "active" file (which now corresponds to the `previous` file) is re-processed one last time to ensure it is complete. Afterwards, the new `latest` file is processed and staged as the new "active" file.
    -   **Existing File Updated**: If the `latest` file from the source is the same as the "active" file, check if its size has increased. If so, re-process it to capture the new data.

### 6.1. Packet Extraction and Transformation

The core packet processing step (referenced above as "processed") involves using the `tcpdump` command-line utility to filter and transform the data. For each capture file designated for processing:

1.  The `tcpdump` program shall be executed on the `.pcap` file located in the working area.
2.  The filter expression shall select packets based on:
    -   A configurable host IP address.
    -   The ISO-on-TCP protocol (IP protocol number 80).
    3.  The `tcpdump` utility generates a multi-line, hexadecimal output for each packet. This output is then piped to a conversion script (`rtcd_routerlog.awk`) for transformation into a single-line format.
    4.  The conversion script processes each packet and generates a single output line with the following space-separated components:
        1.  The literal string `ROUTER CLNS_DT_PDU`.
        2.  The timestamp from the `tcpdump` header.
        3.  The direction of the packet: `SENT` if the source IP matches the monitored IP, `RCVD` otherwise.
        4.  The length of the ATN PDU (the payload of the IP packet).
        5.  The remote IP address (the other party in the communication).
        6.  The raw ATN (CLNP) PDU as a continuous hex string (with the 20-byte IPv4 header removed).
    5.  The final, single-line records are written to a file in the output directory, ready for consumption.

## 7. Assumptions

-   The `rsync` interval from the ATN routers is frequent enough (e.g., every minute) that considering only the two most recent capture files is sufficient to avoid data gaps.
-   The source directories are mounted and accessible to the application with read permissions.
-   The working directories are on a local filesystem with read/write permissions.
-   The `.pcap` files are well-formed and not corrupt.
-   The `tcpdump` command-line utility is installed on the system and is available in the application's execution `PATH`.


<!--
[PROMPT_SUGGESTION]Based on the new PRD, can you review the `capture_processor.py` file and see if its logic aligns with the "Processing Strategy" section?[/PROMPT_SUGGESTION]
[PROMPT_SUGGESTION]Add a new section to the README for "Installation and Usage" instructions.[/PROMPT_SUGGESTION]
