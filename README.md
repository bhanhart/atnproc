# ATN Network Capture Processor (ANCP)

## Requirements

### Functional Requirements Description

Extract ATN network packets related to a particular IP address from network capture files and convert them to single line text files that serve as input for Elasticsearch Filebeat.
The application shall process network capture files that are rsynced at regular intervals from two remote hosts to two distinct NFS mounted directories.
The most recent network capture file may be updated due to a running rsync.
Each network capture file is in the PCAP format and contains captured network traffic up to a maximum duration (typically 1 hour).
Assuming a sufficiently high rsync frequency, only the most recent network capture file and the file before that need to be evaluated.
The network capture file shall be filtered based on a particular IP address and the network protocol that identifies ATN traffic.

### Technical Requirements Description

1. The functionality shall be implemented as a stand-alone Python application
1. The Python version shall be >= 3.9
1. The 2 NFS mounted directories shall be efficiently monitored for any new and updated network capture files.
1. The application shall initiate capture file processing to extract and convert the ATN messages on detecting file updates or creation of new files.
1. File updates or new file creations shall be detected within a maximum of one minute.
1. Capture file processing shall be performed on the most recently updated capture file.
1. In case the capture file is newly created, the processing shall first be performed on the previous capture file to make sure all packets are processed.
1. The network capture filenames are in the format: `<prefix>_<count>_<date><time>.pcap`
    - where:
        - prefix = `<atnr01|atnr02>`
        - count = integer with format "%05d"
        - date = YYYYMMDD
        - time = HHMMSS
1. The "date" part of the filename shall be used to determine the latest available network capture files.
1. The application shall monitor files with a "date" part equal to the current day unless there are fewer than 2 files available for the current day. In that case, the latest file from the previous day (if present) also needs to be evaluated.
