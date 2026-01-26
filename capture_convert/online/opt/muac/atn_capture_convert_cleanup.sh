#!/usr/bin/env bash

set -o pipefail
set -o nounset

: "${CAPTURE_DIR:=/archives/captures}"
: "${RETENTION_DAYS:=7}"

declare -r OUTPUT_DIR="${CAPTURE_DIR}/routerlog"
declare -r LOG_DIR="${CAPTURE_DIR}/log"

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

function cleanup_old_files
{
    local -r directory="$1"
    local -r retention_days="$2"

    if [[ ! -d "${directory}" ]]
    then
        info "Directory '${directory}' does not exist (yet), nothing to do"
        return 0
    fi

    info "Searching '${directory}' for files older than ${retention_days} days..."

    # Files are separated by a NUL character due to the "-print0" option of the
    # find command. Therefore, also set the separator to NUL using the -d ''
    # option of the read command
    while IFS= read -r -d '' file
    do
        info "Deleting '${file}'"
        rm -f -- "${file}"

    done < <( find "${directory}" -type f -mtime +"${retention_days}" -print0 )
}

function main
{
    info "Starting cleanup of files older than ${RETENTION_DAYS} days"

    cleanup_old_files "${OUTPUT_DIR}" "${RETENTION_DAYS}"
    cleanup_old_files "${LOG_DIR}" "${RETENTION_DAYS}"

    info "Finished cleanup of files older than ${RETENTION_DAYS} days"
}

main
