#!/usr/bin/env bash

set -o pipefail
set -o nounset

: "${ARCHIVE_DIR:=/archives/captures}"
: "${RETENTION_DAYS:=7}"

function _format_message
{
    local -r category="$1" ; shift
    local -r message="$*"
    printf "%s - %b" "${category}" "${message}"
}

function _to_stdout
{
    printf "%b\n" "$*"
}

function _to_stderr
{
    _to_stdout "$*" 1>&2
}

function info
{
    _to_stdout "$( _format_message "INFO " "$*" )"
}

function error
{
    _to_stderr "$( _format_message "ERROR" "$*" )"
}

function fatal
{
    _to_stderr "$( _format_message "FATAL" "$*" )"
    exit 1
}

function main
{
    if ! command -v lsof >/dev/null 2>&1
    then
        fatal "No 'lsof' command found"
    fi

    if [[ -z "${ARCHIVE_DIR}" ]]
    then
        fatal "Variable 'ARCHIVE_DIR' not set"
    fi

    if [[ ! -d "${ARCHIVE_DIR}" ]]
    then
        info "Directory '${ARCHIVE_DIR}' does not exist"
        return 0
    fi

    info "Searching '${ARCHIVE_DIR}' for files older than ${RETENTION_DAYS} days..."

    # Files are separated by a NUL character due to the "-print0" option of the
    # find command. Therefore, also set the separator to NUL using the -d ''
    # option of the read command
    while IFS= read -r -d '' file
    do
        # Just to be on the safe side, check whether the file is open
        if lsof -- "$file" >/dev/null 2>&1
        then
            info "Skipping file '${file}' because it is currently open"
            continue
        fi

        info "Deleting '${file}'"
        rm -f -- "${file}"

    done < <( find "${ARCHIVE_DIR}" -type f -mtime +"${RETENTION_DAYS}" -print0 )

    info "Finished searching '${ARCHIVE_DIR}' for files older than ${RETENTION_DAYS} days"
}

main
