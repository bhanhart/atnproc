#!/usr/bin/env bash

set -o nounset
set -o pipefail

: "${CAPTURE_DIR:=/archives/captures}"

declare -r OUTPUT_DIR="${CAPTURE_DIR}/routerlog"
declare -r LOG_DIR="${CAPTURE_DIR}/log"
declare -r HEALTH_FILE="${LOG_DIR}/current_pipeline.info"

declare CURRENT_PGID=0
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

function assert_command_available
{
    local -r cmd="$1"

    if ! command -v "${cmd}" >/dev/null 2>&1
    then
        fatal "Required command '${cmd}' not found"
    fi
}

function assert_required_variables
{
    local -r required=("$@")

    local -a missing=()
    local env_var
    for env_var in "${required[@]}"
    do
        if [[ -z ${!env_var:-} ]]
        then
            missing+=("${env_var}")
        fi
    done

    if (( ${#missing[@]} != 0 ))
    then
        fatal "Environment variables missing: ${missing[*]}"
    fi
}

function assert_prerequisites
{
    assert_command_available tcpdump
    assert_command_available awk
    assert_command_available stdbuf

    # Required environment variables to be provided via systemd EnvironmentFile
    local -r required_variables=( NETWORK_INTERFACE RTCD_SNIFFED_ADDRESS CAPTURE_DIR AWK_CONVERSION_SCRIPT )
    assert_required_variables "${required_variables[@]}"

    if [[ ! -f "${AWK_CONVERSION_SCRIPT}" ]]
    then
        fatal "AWK conversion script not found: ${AWK_CONVERSION_SCRIPT}"
    fi

    if ! mkdir -p "${OUTPUT_DIR}"
    then
        fatal "Cannot create OUTPUT_DIR ${OUTPUT_DIR}"
    fi
    if ! mkdir -p "${LOG_DIR}"
    then
        fatal "Cannot create LOG_DIR ${LOG_DIR}"
    fi
}

function get_today_timestamp
{
    date --utc +%Y-%m-%dT%H:%M:%SZ # ISO 8601 UTC timestamp
}

function day_from_timestamp
{
    local -r ts="$1"
    local date_part="${ts%%T*}" # Extract date part
    date_part="${date_part//-/}" # Remove hyphens
    printf "%s" "${date_part}" # YYYYMMDD
}

function time_from_timestamp
{
    local -r ts="$1"
    local time_part="${ts#*T}" # Extract time part
    time_part="${time_part%Z}" # Remove trailing Z
    time_part="${time_part//:/}" # Remove colons
    printf "%s" "${time_part}" # HHMMSS
}

function make_output_filename
{
    local -r timestamp="$1"
    local -r date_part=$(day_from_timestamp "${timestamp}")
    local -r time_part=$(time_from_timestamp "${timestamp}")
    local host
    host=$(hostname -s)
    host=${host%%-*}
    printf "%s_%s_%s_%s.log" "${host}" "${NETWORK_INTERFACE}" "${date_part}" "${time_part}"
}

function write_pipeline_info_file
{
    local -r pipeline_pgid="$1"
    local -r outfile="$2"

    printf 'pgid=%s started_at=%s outfile=%s\n' "${pipeline_pgid}" "$(get_today_timestamp)" "${outfile}" >"${HEALTH_FILE}" || true
}

function remove_pipeline_info_file
{
    rm -f "${HEALTH_FILE}" 2>/dev/null || true
}

function start_capture_pipeline
{
    local -r processing_timestamp="$1"

    info "Starting pipeline at ${processing_timestamp}"

    local -ra tcpdump_cmd=(
        tcpdump
        -i "${NETWORK_INTERFACE}"
        -n
        -e
        -x
        -tttt
        -l
        --immediate-mode
        "ip host ${RTCD_SNIFFED_ADDRESS} and proto 80" )

    local -ra awk_cmd=(
        stdbuf -oL
        awk
        -v RTCD_SNIFFED_ADDRESS="${RTCD_SNIFFED_ADDRESS}"
        -f "${AWK_CONVERSION_SCRIPT}" )

    local tcp_cmd_safe
    tcp_cmd_safe=$(printf '%q ' "${tcpdump_cmd[@]}")
    local awk_cmd_safe
    awk_cmd_safe=$(printf '%q ' "${awk_cmd[@]}")

    local -r output_filename="$(make_output_filename "${processing_timestamp}")"
    local -r outfile="${OUTPUT_DIR}/${output_filename}"
    local -r logfile_base="${LOG_DIR}/${output_filename}"

    info "Starting pipeline with output to '${outfile}' (error logs: '${logfile_base}.tcpdump.stderr', '${logfile_base}.awk.stderr')"

    # The `$!` contains the PID of the new process group
    # This process group PID is then used for signalling the entire pipeline.
    setsid bash -c "exec ${tcp_cmd_safe} 2>\"${logfile_base}.tcpdump.stderr\" | exec ${awk_cmd_safe} >>\"${outfile}\" 2>\"${logfile_base}.awk.stderr\"" &
    CURRENT_PGID=$!

    info "Pipeline started with pgid=${CURRENT_PGID} outputting to '${outfile}'"

    write_pipeline_info_file "${CURRENT_PGID}" "${outfile}"
}

function stop_capture_pipeline
{
    if (( CURRENT_PGID == 0 )); then
        return
    fi

    info "Stopping pipeline pgid=${CURRENT_PGID}"
    kill -TERM -"${CURRENT_PGID}" 2>/dev/null || true

    local -r GRACE_PERIOD_SEC=4
    local -r POLL_INTERVAL=0.2
    local -r MAX_LOOPS=$(( GRACE_PERIOD_SEC * 5 ))

    local loops=0
    while kill -0 -"${CURRENT_PGID}" 2>/dev/null
    do
        sleep "${POLL_INTERVAL}" || true
        loops=$((loops + 1))

        if (( loops > MAX_LOOPS ))
        then
            info "Pipeline did not exit within ${GRACE_PERIOD_SEC}s; sending KILL to pgid ${CURRENT_PGID}"
            kill -KILL -"${CURRENT_PGID}" 2>/dev/null || true
            break
        fi
    done

    CURRENT_PGID=0
    remove_pipeline_info_file
    info "Pipeline stopped at $(get_today_timestamp)"
}

function script_exit
{
    local -r exit_code="$1" ; shift
    local -r message="$*"

    stop_capture_pipeline || true

    if (( exit_code != 0 ))
    then
        fatal "${message} (exit code ${exit_code})"
    fi
    info "${message}"
    exit 0
}

function monitor_capture_pipeline
{
    local -r processing_timestamp="$1"

    info "Starting pipeline monitoring for ${processing_timestamp}"

    local processing_day
    processing_day=$(day_from_timestamp "${processing_timestamp}" )

    while true
    do
        sleep 1 || true

        if (( STOP_REQUESTED == 1 ))
        then
            script_exit 0 "Stop requested, exiting"
        fi

        # Check if pipeline is still running
        if ! kill -0 -"${CURRENT_PGID}" 2>/dev/null
        then
            script_exit 2 "Pipeline with pgid ${CURRENT_PGID} died unexpectedly"
        fi

        # Check for day change
        local current_day
        current_day=$(day_from_timestamp "$(get_today_timestamp)")
        if [[ "${current_day}" != "${processing_day}" ]]
        then
            info "Day change detected (was ${processing_day}, now ${current_day}); restarting pipeline"
            break
        fi
    done
}

function main
{
    info "Script started"
    assert_prerequisites

    while true
    do
        local today_timestamp
        today_timestamp=$(get_today_timestamp)

        start_capture_pipeline "${today_timestamp}"

        # Returns on day rotation
        monitor_capture_pipeline "${today_timestamp}"

        stop_capture_pipeline
    done
    info "Script stopped"
}

main
