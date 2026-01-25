#!/usr/bin/env bash

set -o nounset
set -o pipefail

function info
{
    echo "$(basename "$0") INFO: $*"
}

function error
{
    echo "$(basename "$0") ERROR: $*" >&2
}

function require_cmd
{
    local -r cmd="$1"

    if ! command -v "${cmd}" >/dev/null 2>&1
    then
        error "Required command '${cmd}' not found"
        exit 2
    fi
}

require_cmd tcpdump
require_cmd awk

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
        error "Aborting: Environment variables missing: ${missing[*]}"
        exit 4
     fi
}

# Required environment variables to be provided via systemd EnvironmentFile
REQUIRED_ENVS=( NETWORK_INTERFACE RTCD_SNIFFED_ADDRESS ARCHIVE_DIR AWK_CONVERSION_SCRIPT )
assert_required_variables "${REQUIRED_ENVS[@]}"

if ! mkdir -p "${ARCHIVE_DIR}"
then
    error "Cannot create ARCHIVE_DIR ${ARCHIVE_DIR}"
    exit 5
fi

# Global filenames for health and failure indicators
HEALTH_FILE="${ARCHIVE_DIR}/.current_pipeline"
FAILURE_FILE="${ARCHIVE_DIR}/.pipeline_failure"

function make_output_filename
{
    local -r current_day="$1"
    local host

    host=$(hostname -s)
    host=${host%%-*}
    # Convert current_day from YYYY-MM-DD to YYYYMMDD format
    local -r date_part="${current_day//-/}"
    printf "%s_%s_%s_%s.log" "${host}" "${NETWORK_INTERFACE}" "${date_part}" "$(date --utc +%H%M%S)"
}



CURRENT_PG=0
SHUTDOWN_REQUESTED=0

function write_health_file
{
    local -r pipeline_pgid="$1"
    local -r outfile="$2"

    printf 'pgid=%s started_at=%s outfile=%s\n' "${pipeline_pgid}" "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" "${outfile}" >"${HEALTH_FILE}" || true
}

function remove_health_file
{
    rm -f "${HEALTH_FILE}" 2>/dev/null || true
}

function write_failure_file
{
    local -r pipeline_pgid="$1"

    printf 'code=6 reason="pipeline exited unexpectedly" pg=%s failed_at=%s\n' "${pipeline_pgid}" "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" >"${FAILURE_FILE}" 2>/dev/null || true
}

function start_capture_pipeline
{
    local -r current_day="$1"

    info "Starting pipeline for day ${current_day}"

    local outfile
    outfile="${ARCHIVE_DIR}/$(make_output_filename "${current_day}")"

    local -a tcpdump_cmd
    local -a awk_cmd

    tcpdump_cmd=( tcpdump -i "${NETWORK_INTERFACE}" -n -e -x -tttt -l --immediate-mode "ip host ${RTCD_SNIFFED_ADDRESS} and proto 80" )
    awk_cmd=( awk -v RTCD_SNIFFED_ADDRESS="${RTCD_SNIFFED_ADDRESS}" -f "${AWK_CONVERSION_SCRIPT}" )

    local tcp_cmd_safe
    tcp_cmd_safe=$(printf '%q ' "${tcpdump_cmd[@]}")
    local awk_cmd_safe
    awk_cmd_safe=$(printf '%q ' "${awk_cmd[@]}")

    info "Starting pipeline with output to '${outfile}' (error logs: '${outfile}.tcpdump.stderr', '${outfile}.awk.stderr')"
    setsid bash -c "exec ${tcp_cmd_safe} 2>\"${outfile}.tcpdump.stderr\" | exec ${awk_cmd_safe} >>\"${outfile}\" 2>\"${outfile}.awk.stderr\"" &
    CURRENT_PG=$!

    sleep 0.5 || true
    if ! kill -0 -"${CURRENT_PG}" 2>/dev/null
    then
        error "Failed to start pipeline pgid=${CURRENT_PG}"
        stop_capture_pipeline || true
        exit 6
    fi

    info "Pipeline started with pgid=${CURRENT_PG}"
    write_health_file "${CURRENT_PG}" "${outfile}"
}

function stop_capture_pipeline
{
    if (( CURRENT_PG == 0 ))
    then
        return
    fi

    info "Stopping pipeline pgid=${CURRENT_PG}"
    kill -TERM -"${CURRENT_PG}" 2>/dev/null || true

    local waited
    waited=0
    while kill -0 -"${CURRENT_PG}" 2>/dev/null
    do
        sleep 0.2
        waited=$((waited + 1))

        if (( waited > 50 ))
        then
            info "Pipeline did not exit in grace period; sending KILL to pgid ${CURRENT_PG}"
            kill -KILL -"${CURRENT_PG}" 2>/dev/null || true
            break
        fi
    done

    CURRENT_PG=0
    remove_health_file
    info "Pipeline stopped"
}

function manage_capture_pipeline
{
    local -r current_day="$1"

    info "Starting pipeline management for day ${current_day}"

    while true
    do
        sleep 1 || true

        if (( SHUTDOWN_REQUESTED == 1 ))
        then
            info "Shutdown requested, stopping pipeline..."
            stop_capture_pipeline || true
            info "Exiting normally"
            exit 0
        fi

        if ! kill -0 -"${CURRENT_PG}" 2>/dev/null
        then
            error "Pipeline with pgid ${CURRENT_PG} died unexpectedly, aborting..."
            write_failure_file "${CURRENT_PG}"
            stop_capture_pipeline || true
            exit 6
        fi

        if [[ $(date --utc +%Y-%m-%d) != "${current_day}" ]]
        then
            info "Day change detected; rotating pipeline"
            break
        fi
    done
}

function sig_handler
{
    SHUTDOWN_REQUESTED=1
}

trap sig_handler TERM INT

function main
{
    info "Script started"
    while true
    do
        local current_day
        current_day=$(date --utc +%Y-%m-%d)

        start_capture_pipeline "${current_day}"

        # Returns only on successful day rotation
        manage_capture_pipeline "${current_day}"

        stop_capture_pipeline
    done
    info "Script stopped"
}

main
