# ATN Network Capture Processor (ANCP) - Product Requirements

## 1. Overview

The ATN Network Capture Processor (ANCP) is a standalone application that automates the processing of network traffic captures from ATN (Aeronautical Telecommunication Network) routers. It monitors specified directories for incoming `.pcap` files, extracts ATN network packets matching a configurable IP address, and transforms them into line-delimited text format suitable for ingestion by data analysis platforms like Elasticsearch Filebeat.

The system handles capture files continuously transferred via `rsync` from remote hosts, where files may be incomplete and growing during processing.

## 2. Goals

- **Automate Processing**: Fully automate extraction and transformation of ATN network traffic from raw PCAP files.
- **Ensure Data Integrity**: Guarantee all packets from a capture file are processed, even when files are actively being written to.
- **Timely Data Availability**: Make processed data available for analysis within a short, predictable timeframe.
- **Enable Data Pipeline**: Serve as a reliable data source for external log analysis and monitoring platforms (e.g., ELK Stack).

## 3. Functional Requirements

| ID | Requirement |
| --- | --- |
| FR-1 | **File Selection**: Scan for files with a `.pcap` extension. |
| FR-2 | **File Filtering**: Filter files based on the date timestamp encoded in the filename. |
| FR-3 | **Packet Filtering**: Extract network packets matching a specific, configurable IP address and ATN protocol. |
| FR-4 | **Data Transformation**: Convert each extracted ATN packet into a single-line text record. |
| FR-5 | **Output Generation**: Write transformed text records to a `processed` output file in a designated work directory. |
| FR-6 | **Incremental Updates**: Compare new `processed` files with previous output and append only new records to the final output file. |
| FR-7 | **Handle Growing Files**: Correctly process capture files that may be growing due to ongoing `rsync` transfers. |
| FR-8 | **Sequential Processing**: Fully process the previous capture file before processing a new one. |

## 4. Non-Functional Requirements

| ID | Requirement |
| --- | --- |
| NFR-1 | **Platform**: Standalone Python application compatible with Python 3.9 or newer. |
| NFR-2 | **Performance**: Detect new or updated capture files within one minute of arrival. |
| NFR-3 | **Configuration**: All operational parameters (source/work directories, filter IP address) configurable via a single YAML configuration file. |
| NFR-4 | **Reliability**: Run continuously as a service with graceful shutdown on `SIGINT` or `SIGTERM` signals. |
| NFR-5 | **Logging**: Provide comprehensive logging to console and rotating log files for operational monitoring and debugging. |

## 5. File Naming and Selection

### 5.1. Filename Format

Capture filenames follow this format:

```text
<host>_<interface>_<count>_<date><time>.pcap
```

- **host**: Source router identifier (e.g., `atnr01`, `atnr02`)
- **interface**: Network interface (e.g., `net3`)
- **count**: Integer counter with leading zeros (e.g., `00001`)
- **date**: Capture start date in `YYYYMMDD` format
- **time**: Capture start time in `HHMMSS` format

The timestamp (`<date><time>`) determines chronological file order.

### 5.2. File Selection Logic

The application identifies files to process as follows:

1. Scan source directories for files matching today's date (`*_<YYYYMMDD>*.pcap`)
2. If fewer than two files are found, also scan the previous day
3. Select the two most recent files as `latest` and `previous` based on filename timestamp

## 6. Processing Strategy

### 6.1. File Processing Pipeline

The application uses a working directory structure and stateful loop to handle growing files and ensure no data is missed. Older files are fully processed before newer ones.

**Processing Steps:**

1. **Identify Candidates**: Find the two most recent capture files (`latest` and `previous`)
2. **Copy to Work Area**: Copy candidate files to an `input` directory to prevent conflicts with ongoing `rsync` transfers
3. **Maintain State**: Track three file concepts:
   - `current`: The pcap file currently being processed (stored in `current` directory)
   - `processed`: The output file generated from processing (stored in `processed` directory)
   - `output`: The final aggregated output file (stored in `output` directory)

4. **Initial Run**: If no `current` file exists:
   - Process the `previous` file first
   - Process the `latest` file and mark it as `current`

5. **Steady State**: On subsequent runs:
   - **New File Detected**: If `latest` is newer than `current`, re-process `current` (now the old file) once more for completeness, then process and mark `latest` as new `current`
   - **File Growing**: If `latest` equals `current` but has increased in size, re-process it to capture new data

### 6.2. Packet Extraction and Transformation

The application uses `tcpdump` and an awk script to filter and transform packets into line-delimited format.

**For each capture file:**

1. Execute `tcpdump` on the `.pcap` file with the following options:
   - `-n`: Do not resolve hostnames
   - `-e`: Output link-level headers
   - `-x`: Output packet data in hex
   - `-tttt`: Output detailed timestamp with sub-second precision
   - Filter: `ip host <configured_ip> and proto 80` (ISO-on-TCP)

   Example: `/usr/sbin/tcpdump -r atnr01_net3_00001_20251229154959.pcap -n -e -x -tttt -l ip host 156.135.249.28 and proto 80`

2. Pipe output to `rtcd_routerlog.awk` which transforms multi-line packet data into single-line records:
   - `ROUTER CLNS_DT_PDU` (literal string)
   - Timestamp from tcpdump header
   - Direction: `SENT` (source IP matches monitored IP) or `RCVD`
   - ATN PDU length (IP packet payload)
   - Remote IP address
   - Raw ATN (CLNP) PDU as hex string (IPv4 header removed)

3. Write records to a temporary file
4. If no previous `processed` file exists, copy temporary file to the `processed` directory; otherwise, diff and append only new records to the output file

### 6.3. Working Directories

The application uses the following configurable working directories:

- **input**: Stores identified latest and previous pcap files
- **current**: Stores the latest processed pcap file
- **processed**: Contains the output file from processing the latest pcap
- **output**: Contains the final aggregated output file

## 7. Assumptions

- The `rsync` interval from ATN routers is frequent enough (e.g., every minute) that tracking the two most recent files is sufficient to prevent data gaps
- Source directories are mounted and accessible with read permissions
- Working directories are on local filesystems with read/write permissions
- `.pcap` files are well-formed and not corrupt
- `tcpdump` is installed and available in the execution environment
