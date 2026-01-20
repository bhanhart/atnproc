#!/bin/bash

#
# Utility script to generate LISAT reports from live capture log
# Usage:
#   - if run manually:
#      ./generate_lisat.sh <YYYYMMDD> 
#   - if run from cronjob:
#      ./generate_lisat.sh
#

# Protocol decoder
PDEC_VER=C5p2
OS_VER=RHEL8
PDEC_DIR=/usr/PDEC/Airtel_PDEC_EXE_${PDEC_VER}_${OS_VER}
PDEC_CLNP=${PDEC_DIR}/bin/pdec_clnp
PDEC_LISAT=${PDEC_DIR}/bin/pdec_intermediate
PDEC_DB=${PDEC_DIR}/data/atsu.csv

# Live Monitoring
LOGDIR=/usr/PDEC/livemonitoring/logs

# Lisat
# Create the directory for the data
LISAT_OUTDIR=/usr/PDEC/livemonitoring/lisat
mkdir -p $LISAT_OUTDIR 2>/dev/null

LOG=${LOG:-logger}

# Check if specific date has been passed from command line.
# If not, then it means we are running as a cron job, and
# we use today's date to find the input file among the router logs.
DATE=$(date -d "-1 days" +'%Y%m%d')
YESTERDAY=$(date -d "-2 days" +'%Y%m%d')
DATE_FMT=$(date -d "-1 days" +'%Y/%m/%d')
DATE_FMT_OLD=$(date -d "-1 days" +'%Y-%m-%d')

# Use specific date if passed in - expected format YYYYMMDD
if [ $# -eq 1 ]; then
    if [ `expr length "$1"` -ne 8 ]; then
        ${LOG} "$0: Usage: $0 [YYYYMMDD]"
        exit 1
    else
        DATE=$(date -d $1 +'%Y%m%d' 2>&1)
        if [ $? -eq 0 ]; then
           DATE_FMT=$(date -d $1 +'%Y/%m/%d')
           DATE_FMT_OLD=$(date -d $1 +'%Y-%m-%d')
           YESTERDAY=$(date -d "$1 -1 days" +'%Y%m%d')
        else
            ${LOG} "$0: Usage: $0 [YYYYMMDD]"
            exit 1
        fi
    fi
fi
SUFFIX="-${DATE}"

${LOG} "${0}: PDEC-LISAT Running for logs from ${DATE}..."

function create_empty_if_missing() {  # $1 : filename
    [ -e "${1}" ] && return
    ${LOG} "$0:   WARNING - ${1} missing, creating empty"
    # create empty file
    touch ${1}
}

LOGFILE=${LOGDIR}/${DATE}_live_capture.log
LOGFILE_YESTERDAY=${LOGDIR}/${YESTERDAY}_live_capture.log
# Sanity check date file
create_empty_if_missing ${LOGFILE}
# Sanity check yesterday file
create_empty_if_missing ${LOGFILE_YESTERDAY}

# Determine whether the log file is plain ASCII or is compressed
# with GZIP
CAT=
FTYPE=$(file -b ${LOGFILE})
case "${FTYPE}" in
    ASCII*)
        CAT=cat
        ;;
    gzip*)
        CAT=zcat
        ;;
    empty)
        CAT=cat
        ;;
    *)
        ${LOG} "${0}: ${LOGFILE}: unsupported file type: ${FTYPE}"
        exit 1
        ;;
esac

# Create a temporary directory
if [ -z "${TMPDIR}" ] ; then
    TMPDIR=/tmp
fi
WDIR=$(mktemp -d ${TMPDIR}/lisat_XXXXXXXXX)
pushd ${WDIR} 2>&1 >/dev/null

# Make sure that we will clean after ourselves
trap "rm -rf ${WDIR}" SIGINT SIGTERM

#
# 1. Run PDEC CLNP decoder
#    a. Merge the day's log with the previous date (required in case CM occured the day before)
#    b. Run the PDEC CLNP decoder
#
${LOG} "${0}: Decode livemonitoring logs from ${DATE}..."
${CAT} ${LOGFILE_YESTERDAY} ${LOGFILE} | ${PDEC_CLNP} -s ${PDEC_DB} -i - >/dev/null
RETVAL=$?
if [ ${RETVAL} -eq 0 ] ; then
    # Process all intermediate CSV files if any
    for file in intermediate*.csv; do
        # Check if there are intermediate CSV files
        if [ ${file} = "intermediate*.csv" ]; then
            ${LOG} "${0}: ${PDEC_CLNP} didn't create intermediate CSV files - no transport/application data present"
        else
            #
            # 2.a Keep only output from DATE
            #
            cp ${file} ${file}.old
            grep -a ${DATE_FMT_OLD} ${file}.old > ${file}

            #
            # 2.b Reformat date in file from YYYY-MM-DD to YYYY/MM/DD
	    #     (due to livemonitoring log datestamp)
            #
            sed -i "s!${DATE_FMT_OLD}!${DATE_FMT}!g" ${file}

	    # Extract GFD from intermediate filename (intermediate_XXXX.csv)
	    GFD=`echo ${file} | cut -d'.' -f1 | cut -d'_' -f2`
	    LISATFILE=lisat_${GFD}.xml

            #
            # 2.c Run PDEC INTERMEDIATE to produce LISAT output
            #
            ${LOG} "${0}: Generating Full LISAT for ${GFD}..."
            ${PDEC_LISAT} -n ${GFD} --nogold -i ${file} --full --emptyflightid=UNK0000 > intermediate.out
            RETVAL=$?
            if [ ${RETVAL} -eq 0 ] ; then
                # Check for LISAT
                if [ -f ${LISATFILE} ] ; then
                    # 2.d Format XML output
                    /usr/bin/xmllint --format ${LISATFILE} > ${LISAT_OUTDIR}/lisat-${GFD}${SUFFIX}.xml
                    ${LOG} "${0}:   LISAT file lisat-${GFD}${SUFFIX}.xml generated in ${LISAT_OUTDIR}"
                else
                    ${LOG} "${0}: ${PDEC_LISAT}: failed to create ${LISATFILE}"
                    RETVAL=1
                fi
            else
                ${LOG} "${0}: ${PDEC_LISAT}: failed to process ${file}"
            fi
        fi
    done
else
    ${LOG} "${0}: ${PDEC_CLNP}: failed to decode ${LOGFILE}"
fi

# Leave the temporary directory and remove it
popd 2>&1 >/dev/null
rm -fr ${WDIR}
