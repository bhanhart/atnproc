#!/bin/bash

#
# Utility script to decode the live capture log
# Usage:
#   - if run manually:
#      ./decode_capture.sh <logfile> 
#   - if run from cronjob:
#      ./decode_capture.sh
#

# Protocol decoder
PDEC_VER=C4p5
OS_VER=RHEL8
PDEC_DIR=/usr/PDEC/Airtel_PDEC_EXE_${PDEC_VER}_${OS_VER}
PDEC_CLNP=${PDEC_DIR}/bin/pdec_clnp
PDEC_DB=${PDEC_DIR}/data/atsu.csv

# Create the directory for the data
OUTDIR=/usr/PDEC/livemonitoring/data
mkdir -p $OUTDIR 2>/dev/null

# Check if the log file has been passed from command line.
# If not, then it means we are running as a cron job
LOGFILE=${1}
if [ -z "${LOGFILE}" ] ; then
    DATE=$(date "+%Y%m%d")
    LOGDIR=/usr/PDEC/livemonitoring/logs
    LOGFILE=${LOGDIR}/${DATE}_live_capture.log
    LOG=logger
    # Go OUTDIR
    pushd ${OUTDIR} 2>&1 >/dev/null
else
    LOGFILE=$(readlink -f ${LOGFILE})
    LOG=echo
fi
DATE_TIME=$(date "+%Y%m%d%H%M")

# Check if concatenation was previously used
if [ -f pdus.csv.${DATE} ] ; then
    # Remove all concatenation related files
    rm pdus*.csv
    # Copy backup of todays only trace as pdus.csv
    mv pdus.csv.${DATE} pdus.csv
fi    

# Save all previous pdus CSV files
for file in pdus*.csv; do
    # Check if there are pdus CSV files
    if [ ${file} != "pdus*.csv" ]; then
        cp ${file} ${file}.old
    fi
done

# Run pdec on full live capture
${PDEC_CLNP} -s ${PDEC_DB} -i ${LOGFILE} --csv >/dev/null
RETVAL=$?
if [ ${RETVAL} -eq 0 ] ; then
    # Process all pdus CSV files if any
    for file in pdus*.csv; do
        # Check if there are pdus CSV files
        if [ ${file} = "pdus*.csv" ]; then
            ${LOG} "${0}: pdec_clnp didn't create PDUs CSV files - no transport/application data present"
        else
            # Check if there is previous data
            if [ -f ${file}.old ] ; then
                # Check difference between the old file and the new one
                diff ${file}.old ${file} > diff.out
                RETVAL=$?
                if [ ${RETVAL} -ne 0 ] ; then
                    # Count number of new lines (remove first diff line)
                    var=$(wc -l diff.out | awk '{print $1}')
                    # Rremove first diff line from count
                    var=$((var - 1))
                    ${LOG} "${0}: ${PDEC_CLNP} succeeded: ${file} - ${var} new lines since last run"
                    # Return only new lines
                    tail -n $var ${file} > ${OUTDIR}/${DATE_TIME}_${file}
                else
                    ${LOG} "${0}: ${PDEC_CLNP} succeeded: ${file} - No new lines since last run"
                fi
               
                # Cleanup temporary files
                rm diff.out ${file}.old pdus.txt
            else
                # Count number of lines
                var=$(wc -l ${file} | awk '{print $1}')
                ${LOG} "${0}: ${PDEC_CLNP} succeeded: ${file} - ${var} new lines"
                # Return all lines
                cp ${file} ${OUTDIR}/${DATE_TIME}_${file}
            fi
        fi
    done
else
    ${LOG} "${0}: ${PDEC_CLNP}: failed to decode ${LOGFILE}"
fi
