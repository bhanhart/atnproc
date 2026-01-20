1. Directory structure:
 - cron: Capture and decoding scripts
 - cron.d: Cronjob file
 - utility: Utility scripts

2. Capture and decoding scripts:
 2.1 start_capture.sh
   * Utility script to start a live IP capture
   * Must be run with superuser privileges
   * Configuration:
     - Capture IP address needs to be configured via SNIFFED_ADDRESS variable
   * Usage:
     - if run manually:
       ./start_capture.sh <logfile> 
     - if run from cronjob:
       ./start_capture.sh
   * Output: 
     - stops previous live capture
     - a log file following Airtel's router log format
     - if cron job, default OUTDIR=${HOME}/livemonitoring/logs/${DATE}_live_capture.log
   * Cron job configuration:
     - To produce one output file per day, add the following to /etc/crontab:
       0  0  *  *  * root /home/atnuser/livemonitoring/cron/start_capture.sh
     - cron job output is logged in the system log (eg /var/log/messages)

 2.2 decode_capture.sh, decode_capture_midnight.sh, decode_capture_inc_yesterday.sh
   * Utility scripts to decode the live capture log.
     decode_capture_midnight.sh is used to decode the log from 23:50 et 00:00 on the previous day
     decode_capture_inc_yesterday.sh is used to decode the logs at the start of a new day,
        including the previous day log, to keep connection information knowledge
   * Usage:
      - if run manually:
        ./decode_capture.sh <logfile> 
        ./decode_capture_midnight.sh <logfile> 
        ./decode_capture_inc_yesterday.sh <logfile> 
      - if run from cronjob:
        ./decode_capture.sh
        ./decode_capture_midnight.sh
   * Configuration:
     - Protocol Decoder version and location needs to be configured via PDEC_DIR variable
   * Input:
     - a log file following Airtel's router log format
     - if cron job, default LOGFILE=${HOME}/livemonitoring/logs/${DATE}_live_capture.log
   * Output: 
     - pdus CSV files in OUTDIR (default: OUTDIR=${HOME}/livemonitoring/data/${DATE_TIME}_pdus.csv)
     - the pdu CSV files will only contain the new data since the last pdu CSV file
   * Cron job configuration:
     - To produce pdu CSV files every 10 minutes, add the following to the user crontab (crontab -e):
       0 0 *  *  * /bin/bash ${HOME}/livemonitoring/cron/decode_capture_midnight.sh
       10,20,30,40,50  0  *  *  * /bin/bash ${HOME}/livemonitoring/cron/decode_capture_inc_yesterday.sh
       0,10,20,30,40,50  1-23  *  *  * /bin/bash ${HOME}/livemonitoring/cron/decode_capture.sh
     - cron job output is logged in the system log (eg /var/log/messages)

