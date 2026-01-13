#!/bin/bash

#
# Utility script to start a live IP capture
# Must be run with superuser privileges
# Usage:
#   - if run manually:
#      ./start_capture.sh <logfile> 
#   - if run from cronjob:
#      ./start_capture.sh
#

# To debug script
# set -x

# Configuration can changed via env variables. Example:
# PLM_SNIFFED_ADDRESS=127.0.0.1 PLM_SNIFFED_INTERFACE=lo start_capture.sh
SNIFFED_ADDRESS=${PLM_SNIFFED_ADDRESS:-156.135.249.28}
SNIFFED_INTERFACE=${PLM_SNIFFED_INTERFACE:-eth0}

TCPDUMP=${PLM_TCPDUMP:-/usr/sbin/tcpdump}
TCPDUMPARGS=${PLM_TCPDUMPARGS:-"-i $SNIFFED_INTERFACE -n -e -x -tttt --immediate-mode -l"}
TCPDUMPEXP=${PLM_TCPDUMPEXP:-"ip host $SNIFFED_ADDRESS and proto 80"}
AWK=${PLM_AWK:-awk}
AWKPROG=${PLM_AWKPROG:-/usr/PDEC/livemonitoring/cron/rtcd_routerlog.awk}
LOGDIR=${PLM_LOGDIR:-/usr/PDEC/livemonitoring/logs}

# Check if the log file has been passed from command line.
# If not, then it means we are running as a cron job
LOGFILE=${1}
if [ -z "${LOGFILE}" ] ; then
    DATE=$(date "+%Y%m%d")
    LOGFILE=${LOGDIR}/${DATE}_live_capture.log
    # Save previous capture log if it exists
    if [ -f ${LOGFILE} ] ; then
        DATE_TIME=$(date "+%Y%m%d%H%M")
        mv ${LOGFILE} ${LOGDIR}/${DATE_TIME}_live_capture.log
    fi
    LOG=logger
else
    LOGFILE=$(readlink -f ${LOGFILE})
    LOG=echo
fi

# Create the directory for the logs
mkdir -p $LOGDIR

# Kill previous tcpdump if any
killall tcpdump
RETVAL=$?
if [ ${RETVAL} -eq 0 ] ; then
    ${LOG} "${0}: stopped tcpdump"
fi

${LOG} "${0}: starting tcpdump with arguments \"${TCPDUMPARGS}\" and expression \"${TCPDUMPEXP}\" storing output in ${LOGFILE}"
${TCPDUMP} ${TCPDUMPARGS} ${TCPDUMPEXP} | \
${AWK} -v RTCD_SNIFFED_ADDRESS="$SNIFFED_ADDRESS" -f "${AWKPROG}" > $LOGFILE &
