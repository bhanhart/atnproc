#!/usr/bin/env bash

set -o pipefail
set -o nounset

: "${CAPTURE_DIR:=/archives/captures}"
: "${RETENTION_DAYS:=7}"

declare -r OUTPUT_DIR="${CAPTURE_DIR}/pcap"

function _format_message
{
    local -r category="$1" ; shift
    local -r message="$*"
    printf "%s - %b" "${category}" "${message}"
}

function _to_stdout { printf "%b\n" "$*" ; }
function _to_stderr { _to_stdout "$*" 1>&2 ; }
function info { _to_stdout "$( _format_message "INFO " "$*" )" ; }
function fatal { _to_stderr "$( _format_message "FATAL" "$*" )" ; exit 1 ; }

function main
{
    if [[ ! -d "${OUTPUT_DIR}" ]]
    then
        info "Directory '${OUTPUT_DIR}' does not exist (yet), nothing to do"
        return 0
    fi

    info "Searching '${OUTPUT_DIR}' for files older than ${RETENTION_DAYS} days..."
    # Files are separated by a NUL character due to the "-print0" option of the
    # find command. Therefore, also set the separator to NUL using the -d ''
    # option of the read command
    while IFS= read -r -d '' file
    do
        info "Deleting '${file}'"
        rm -f -- "${file}"

    done < <( find "${OUTPUT_DIR}" -type f -mtime +"${RETENTION_DAYS}" -print0 )

    info "Finished searching '${OUTPUT_DIR}' for files older than ${RETENTION_DAYS} days"
}

main
