#!/bin/bash
#
# Author: D. Schmutz, M. Rebmeister
# Date : 14.12.2020
# Description: The following script archives and removes log files
#
# Run Information: This script is run in a CRON job
#
# Standard Output: -
# 
###################################################
#
# Replay variables & call the functions
#
. /opt/cpdlc/config/general_parameter_file
. /opt/cpdlc/scripts/cc-functions.sh
# PDEC
#cc-delete ${PDEC} ${PDEC_LOGDIR} ${PDEC_LOGRETENTION}
cc-delete "*.log" /usr/PDEC/livemonitoring/logs +${XCPDLC_ARCHIVERETENTION}

# Manage xcpdlc log files
cc-createDailyFiles ${XCPDLC_PATTERN} ${XCPDLC_MINDIR} ${XCPDLC_MINARCHIVEDIR} ${XCPDLC_DIR}
cc-move ${XCPDLC_PATTERN} ${XCPDLC_DIR} ${XCPDLC_LOGRETENTION} ${XCPDLC_ARCHIVEDIR}
cc-delete ${XCPDLC_PATTERN} ${XCPDLC_MINARCHIVEDIR} ${XCPDLC_LOGRETENTION}
cc-delete ${XCPDLC_PATTERN} ${XCPDLC_ARCHIVEDIR} ${XCPDLC_ARCHIVERETENTION}

# Manage asterix log files
cc-move ${ADSB_PATTERN} ${ADSB_DIR} ${ADSB_LOGRETENTION} ${ADSB_ARCHIVEDIR}
cc-delete ${ADSB_PATTERN} ${ADSB_ARCHIVEDIR} ${ADSB_ARCHIVERETENTION}

# Manage df log files
cc-move ${DF_PATTERN} ${DF_DIR} ${DF_LOGRETENTION} ${DF_ARCHIVEDIR}
cc-delete ${DF_PATTERN} ${DF_ARCHIVEDIR} ${DF_ARCHIVERETENTION}

# Manage LISAT log files
cc-delete ${LISAT_PATTERN} ${LISAT_DIR} ${LISAT_LOGRETENTION}


