#!/bin/bash

#
# Utility script to stop a live capture
# Must be run with superuser privileges
# Usage:
#      ./stop_capture.sh
#

killall tcpdump
RETVAL=$?
if [ ${RETVAL} -eq 0 ] ; then
    echo "Stopped tcpdump"
else
    echo "No tcpdump running"
fi
