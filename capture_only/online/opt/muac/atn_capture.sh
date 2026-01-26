#!/usr/bin/env bash

set -o pipefail
set -o nounset

: "${NETWORK_INTERFACE:=net3}"
: "${CAPTURE_DIR:=/archives/captures}"
: "${CAPTURE_FILE_DURATION_SECS:=3600}"
: "${CAPTURE_NUM_CAPTURE_FILES:=72}"

declare -r OUTPUT_DIR="${CAPTURE_DIR}"/pcap

declare STOP_REQUESTED=0

function signal_handler
{
    echo "Caught termination signal, stopping capture..."
    STOP_REQUESTED=1
}
trap signal_handler SIGTERM SIGINT

function _format_message
{
    local -r category="$1" ; shift
    local -r message="$*"
    printf "%s - %b" "${category}" "${message}"
}

function _to_stdout { printf "%b\n" "$*" ; }
function _to_stderr { _to_stdout "$*" 1>&2 ; }
function info { _to_stdout "$( _format_message "INFO " "$*" )" ; }
function error { _to_stderr "$( _format_message "ERROR" "$*" )" ; }
function fatal { _to_stderr "$( _format_message "FATAL" "$*" )" ; exit 1 ; }

function is_process_running
{
    local -r pid="$1"
    kill -0 "${pid}" 2>/dev/null
}

function stop_process
{
    local -r pid="$1"

    if is_process_running "${pid}"
    then
        info "Sending SIGTERM to process ${pid}"
        kill -TERM "${pid}"
        sleep 2
        if is_process_running "${pid}"
        then
            error "LAN capture process failed to stop"
            info "Sending SIGKILL to process ${pid}"
            kill -KILL "${pid}"
        fi
    fi
}

function main
{
    if ! command -v dumpcap >/dev/null 2>&1
    then
        fatal "No 'dumpcap' command found"
    fi

    mkdir -p "${OUTPUT_DIR}"

    local -r hostname="$(hostname -s)"
    local -r capture_file="${OUTPUT_DIR}"/"${hostname%%-*}"_"${NETWORK_INTERFACE}".pcap

    info "Start capturing on interface ${NETWORK_INTERFACE} to file ${capture_file}"

    # Use ring buffer with 72 files of 60 minutes each (total=3 days)
    if ! dumpcap \
-i "${NETWORK_INTERFACE}" \
-p \
-f 'not stp and not ether multicast and not ip multicast' \
-b duration:"${CAPTURE_FILE_DURATION_SECS}" \
-b files:"${CAPTURE_NUM_CAPTURE_FILES}" \
-P \
-q \
-w "${capture_file}" &
    then
        fatal "Failed to start LAN capture on interface ${NETWORK_INTERFACE}"
    fi

    local -r dumpcap_pid=$!
    sleep 2
    if ! is_process_running "${dumpcap_pid}"
    then
        fatal "LAN capture on interface ${NETWORK_INTERFACE} has failed"
    fi

    while (( STOP_REQUESTED == 0 ))
    do
        sleep 1
        if ! is_process_running "${dumpcap_pid}"
        then
            fatal "LAN capture on interface ${NETWORK_INTERFACE} has failed"
        fi
    done
    info "Stopped LAN capture on ${NETWORK_INTERFACE}, stopping capture process ..."
    stop_process "${dumpcap_pid}"
    info "Finished"
}

main
