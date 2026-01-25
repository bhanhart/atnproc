# Project Requirements Document: ATN Traffic Capture

Date: 2026-01-16

## Purpose

This document defines the functional and non-functional requirements for a capture application that listens on a configurable network interface, captures ATN traffic using `tcpdump`, pipes each packet through an existing `awk` script that converts packet data into a single-line ASCII representation, and stores the resulting lines into daily timestamped files. The application is intended to run as a Pacemaker-managed service on the MAIN node of a Pacemaker/Corosync high-availability cluster with 2 nodes. The capture implementation shall be packaged as a `systemd` service unit; Pacemaker will manage the lifecycle of that unit (start/stop/failover) rather than relying on standalone systemd restart policies.

## Scope

- Capture ATN (Air Traffic Network) packets visible on a specified network interface.
- Convert packet information to a compact single-line ASCII record using the provided `awk` script.
- Write the ASCII output to files created at service start and rotated daily immediately after UTC midnight.
- Support configurable capture interface, output directory, and retention policy.

## Actors

- Operator / System administrator: configures the interface, retention, and deploys the service.
- Monitoring system: verifies the process is running and alerts on failures.

## Functional Requirements

1. Configurable Interface and IP address

    - The application shall accept a network interface identifier (for example `net3` or `eth0`) and the IP address of the communication partner via environment variables.

2. Packet Capture

    - The application shall use `tcpdump` to capture packets on the configured interface.
    - The capture process shall use the fixed BPF expression `ip host <ip_address> and proto 80`. This BPF expression is not configurable.
    - The `tcpdump` invocation shall be a single process. The textual output of this single `tcpdump` process shall be fed directly to the `awk` script.

3. Transform to Single-Line ASCII

    - Each captured packet shall be transformed to a single ASCII line per packet by the `awk` script `rtcd_routerlog.awk` as provided by Skyguide.
    - The `awk` script shall extract the fields required for offline processing and ensure each output record is a single newline-terminated ASCII line. The runtime `tcpdump` invocation must produce the textual format that this `awk` script expects.

4. Daily Timestamped File Storage

    - The ASCII records shall be appended to a file stored in a configurable `ARCHIVE_DIR`.
    - File naming: files shall always include date and time. The required filename pattern is: `<hostname>_<interface>_YYYYMMDD_HHMMSS.log` where the timestamp is the UTC time when that pipeline instance was started.
    - The `tcpdump | awk` pipeline shall be restarted immediately after each UTC midnight (i.e., once per UTC day). The restart action creates a new file with the new day's UTC timestamp using the filename pattern above. This ensures both a daily file boundary and inclusion of time to distinguish restarts or Pacemaker failovers.
    - Note that all hosts involved in capture and processing shall be configured to use UTC.

5. Rotation and Retention

    - A cleanup script, run as a pre-start action in the systemd service unit, shall remove ASCII log files older than `RETENTION_DAYS` (configurable, default 7 days), while skipping files that are currently open.

    Cleanup tool and behavior

    - The cleanup job invoked at service pre-start shall remove ASCII log files older than `RETENTION_DAYS`. The cleanup script must not prevent service start if it returns non-zero.

6. Start/Stop and Signal Handling

    - The capture process shall handle SIGTERM and SIGINT to gracefully stop capturing, flush buffers, and close files.
    - The service shall be tolerant to the cleanup script returning non-zero (i.e., service start should not be prevented by cleanup failures).

    Failure detection

    - The runtime shall include a watcher that monitors the pipeline process group. If the `tcpdump | awk` pipeline terminates unexpectedly (not due to a received SIGTERM/SIGINT), the runtime shall exit with a non-zero code so the service manager and Pacemaker can observe the failure and take appropriate action. This ensures crash/failure events are visible to HA tooling.

7. Logging and Monitoring

    - The capture script shall emit concise INFO/ERROR messages to stdout/stderr.
    - The systemd default logging behaviour guarantees that all logging is sent to the linux journal.
    - The service shall expose exit codes consistent with expectations: 0 for clean exit, non-zero for fatal errors.

    Health file

    - The capture pipeline shall write a small health file for each running pipeline instance at `${ARCHIVE_DIR}/.current_pipeline`. The file shall contain the pipeline process-group id (pgid), UTC start timestamp, and the active output filename. Monitoring systems may read this file to verify the pipeline is active and to locate the current write file.

8. Security

    - The application shall run as the `root` user.
    - The environment file containing configuration shall be readable only by `root` (mode 0640).

## Non-Functional Requirements

- Performance: The pipeline shall sustain expected packet rates on the target interface without dropping more than an acceptable threshold (to be determined during testing).
- Reliability: The service is intended to be run as a Pacemaker high-availability service and its lifecycle shall therefore be managed by Pacemaker. The unit/service configuration must not rely on systemd restart policies in a single-node sense.
- Observability: The service should provide informative logs and expose a simple health indicator (process alive and writing to current day's file).
- Portability: The solution must run on modern Linux distributions with `tcpdump` and `awk` available.

## Technical Requirements

The `tcpdump` command shall be invoked exactly once per pipeline, with the following required options. These options are required because they produce the textual format that the provided `awk` script expects.

### Invocation of tcpdump

The `tcpdump` command shall use the following commandline options:

- `-i <interface>`: Interface to capture on
- `-n`: Do not resolve hostnames
- `-e`: Output link-level headers (used by the `awk` script)
- `-x`: Output packet data in hex (required by `rtcd_routerlog.awk` which parses hex data lines)
- `-tttt`: Output detailed timestamp with sub-second precision
- `-l`: Output is line buffered
- `--immediate-mode`: Disable internal buffering (real-time behaviour)
- `ip host <host_ip> and proto 80`: Fixed BPF filter expression

Example invocation:

```sh
tcpdump -i "${NETWORK_INTERFACE}" -n -e -x -tttt -l --immediate-mode "ip host ${RTCD_SNIFFED_ADDRESS} and proto 80"
```

### Invocation of awk

- The `awk` script `rtcd_routerlog.awk` shall be invoked as follows (example):

```sh
awk -v RTCD_SNIFFED_ADDRESS="${RTCD_SNIFFED_ADDRESS}" -f /opt/muac/rtcd_routerlog.awk >> "${ARCHIVE_DIR}/${HOSTNAME}_${NETWORK_INTERFACE}_$(date -u +%Y%m%d_%H%M%S).log"
```

Notes:

- The `tcpdump` process must be a single invocation and its stdout fed directly to the `awk` script.
- All timestamps and rotation decisions shall use UTC. Configure all hosts involved to use UTC.

## Deployment

- Provide and install a `systemd` service unit for the capture script; Pacemaker will manage the service unit's lifecycle (start/stop/failover).
- Use an `EnvironmentFile` (for example `/etc/sysconfig/atn_capture_convert`) to set `NETWORK_INTERFACE`, `RTCD_SNIFFED_ADDRESS`, `AWK_CONVERSION_SCRIPT`, `ARCHIVE_DIR` and `RETENTION_DAYS`.
- The cleanup script may be run as a pre-start action but must not block service start if it returns non-zero.
- Ensure the process runs as `root` per the security requirement and that file ownership and permissions of `ARCHIVE_DIR` are correct after any Pacemaker failover.
- Configure the systemd service unit as a Pacemaker-managed resource to always run on the MAIN node.

Shutdown timing and process-group signaling

- The systemd unit shall configure a short graceful shutdown window (for example `TimeoutStopSec=10s`). The runtime must send `SIGTERM` to the pipeline process group and wait for it to exit within the configured systemd timeout. If the pipeline does not exit within that period the runtime may send `SIGKILL`. To support correct signal delivery, the runtime shall start the pipeline in its own session/process-group (for example using `setsid`) and record the pipeline pgid in the health file.

## Testing and Acceptance Criteria

1. Configuration Tests

    - Verify environment variables override defaults when present.

2. Functional Tests

    - Start the service and validate ASCII records are being appended to the current pipeline's file.
    - Confirm each captured packet produces exactly one non-empty line in the ASCII file.

3. Retention Tests

    - Create files with simulated older timestamps and run the cleanup script to verify files older than `RETENTION_DAYS` are deleted and open files are skipped.

4. Daily Restart and Graceful Shutdown

    - Verify the pipeline restarts immediately after UTC midnight and creates a new timestamped file.
    - Send SIGTERM to the capture process and verify it exits cleanly and stops writing.

5. Performance Test

    - Run a traffic generator to produce expected peak packet rate and verify that fewer than X% (to be defined) of packets are dropped by the capture pipeline.

## Acceptance Criteria

- The capture pipeline runs continuously on the configured interface.
- The `awk` script converts packets to single-line ASCII records and writes them into timestamped daily files in `ARCHIVE_DIR`.
- The system respects configuration via the `EnvironmentFile` and defaults when settings are omitted.
- The cleanup process removes files older than `RETENTION_DAYS` without deleting open files.
- The pipeline restarts immediately after each UTC midnight and creates a new timestamped file.
- The service handles SIGTERM gracefully and exits with code 0 on clean stop.

## Risks and Mitigations

- Disk usage growth: enforce retention for ASCII files.
- High packet rates: use performant parsing (`awk`/`gawk`) and test on target hardware.
- Security: process must run as `root`; ensure runbook documents hardening and acceptable risks.
