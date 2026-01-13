#!/bin/bash

#
# Utility script to cleanup PDEC PDUs CSV output files
# Usage:
#   - if run manually:
#      ./cleanup_capture.sh <directory>
#   - if run from cronjob:
#      ./decode_capture.sh
#

# Check if the directory has been passed from command line.
# If not, then it means we are running as a cron job.
OUTDIR=${1}
if [ -z "${OUTDIR}" ] ; then
    OUTDIR=/usr/PDEC/livemonitoring/data
    LOG=logger
else
    LOG=echo
fi    

# Create the directory for the data
mkdir -p $OUTDIR 2>/dev/null

# Go OUTDIR
pushd ${OUTDIR} 2>&1 >/dev/null

# Cleanup old PDEC PDUs CSV files
if [ -f pdus*.csv ]; then
    rm pdus*.csv
    ${LOG} "${0}: Removed old pdec PDUs CSV files"
else
    ${LOG} "${0}: No pdec PDUs CSV files"
fi

# Leave OUTDIR
popd 2>&1 >/dev/null
