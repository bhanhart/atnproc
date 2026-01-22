# ATN Capture Convert - Development files

This directory contains development copies of scripts and unit files for the ATN capture pipeline.

Mapping to production locations:

- Scripts: capture_convert/online/opt/muac/*.sh -> /opt/muac/
- Awk script: /opt/muac/rtcd_routerlog.awk (must be present in production)
- EnvironmentFile: capture_convert/online/etc/sysconfig/atn_capture_convert -> /etc/sysconfig/atn_capture_convert (owner root:root, mode 0640)
- systemd unit: capture_convert/online/etc/systemd/system/atn_capture_convert.service -> /etc/systemd/system/atn_capture_convert.service

Prerequisites on host:

- tcpdump with --immediate-mode support
- awk (gawk recommended)
- lsof (mandatory for cleanup)

Health and monitoring

- The capture script writes a small health file at the start of each pipeline run: `${ARCHIVE_DIR}/.current_pipeline`. The file contains the pipeline pgid, start timestamp, and the current output file. Monitoring systems may check this file to confirm the pipeline is alive and which file is active.

Permissions and install notes

- The `EnvironmentFile` should be installed at `/etc/sysconfig/atn_capture_convert` and must be owned by `root:root` with mode `0640`.
- The `/opt/muac` scripts must be installed as root and executable. Example install commands (run as root):

```sh
install -d -m 0755 /opt/muac
install -m 0755 capture_convert/online/opt/muac/*.sh /opt/muac/
# ensure the rtcd_routerlog.awk file is present at /opt/muac/rtcd_routerlog.awk and readable
install -m 0640 capture_convert/online/etc/sysconfig/atn_capture_convert /etc/sysconfig/atn_capture_convert
chown root:root /etc/sysconfig/atn_capture_convert
install -m 0644 capture_convert/online/etc/systemd/system/atn_capture_convert.service /etc/systemd/system/atn_capture_convert.service
systemctl daemon-reload
systemctl enable --now atn_capture_convert.service
```

If you need to run a different `rtcd_routerlog.awk` during testing, set `RTCD_AWK_PATH` in the environment file to the full path of the awk script. The capture runtime will use this path instead of the default `/opt/muac/rtcd_routerlog.awk`.

Basic install steps (run as root):

```sh
install -d -m 0755 /opt/muac
install -m 0755 capture_convert/online/opt/muac/*.sh /opt/muac/
install -m 0640 capture_convert/online/etc/sysconfig/atn_capture_convert /etc/sysconfig/atn_capture_convert
install -m 0644 capture_convert/online/etc/systemd/system/atn_capture_convert.service /etc/systemd/system/atn_capture_convert.service
systemctl daemon-reload
systemctl enable --now atn_capture_convert.service
```

Testing notes:

- Verify `tcpdump` and `lsof` present: `which tcpdump lsof`.
- Check that the service starts and one tcpdump process is running.
- Monitor /var/log/atn_capture (or configured ARCHIVE_DIR) for timestamped logs and rotation at UTC midnight.
