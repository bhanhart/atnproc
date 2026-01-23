#!/usr/bin/env bash

# Runs a single tcpdump | awk pipeline, rotates at UTC midnight, handles signals gracefully.

set -o nounset
set -o pipefail

# shellcheck disable=SC2155
readonly SCRIPT_NAME="$(basename "$0")"

function info
{
	echo "${SCRIPT_NAME} INFO: $*"
}

function error
{
	echo "${SCRIPT_NAME} ERROR: $*" >&2
}

function require_cmd
{
	if ! command -v "$1" >/dev/null 2>&1
	then
		error "required command '$1' not found"
		exit 2
	fi
}

require_cmd tcpdump
require_cmd awk

# check_required_envs: verify all variables passed as arguments are set
function check_required_envs
{
	local required=("$@")
	local missing=()
	local env_var
	for env_var in "${required[@]}"
	do
		if [ -z "${!env_var:-}" ]
		then
			missing+=("$env_var")
		fi
	done
	if (( ${#missing[@]} != 0 ))
	then
		error "missing required environment variables: ${missing[*]}"
		return 1
	fi
	return 0
}

# required environment variables for operation
REQUIRED_ENVS=(
	NETWORK_INTERFACE
	RTCD_SNIFFED_ADDRESS
	AWK_CONVERSION_SCRIPT
	ARCHIVE_DIR
)

# validate required envs
check_required_envs "${REQUIRED_ENVS[@]}" || exit 4

if ! mkdir -p "${ARCHIVE_DIR}"
then
	error "failed to create ARCHIVE_DIR ${ARCHIVE_DIR}"
	exit 5
fi

function make_output_filename
{
	local host
	host=$(hostname -s)
	host="${host%%-*}"
	local timestamp
	timestamp=$(date --utc +%Y%m%d_%H%M%S)
	printf "%s_%s_%s.log" "${host}" "${NETWORK_INTERFACE}" "${timestamp}"
}

TCPDUMP_CMD=( \
tcpdump \
-i "${NETWORK_INTERFACE}" \
-n \
-e \
-x \
-tttt \
-l \
--immediate-mode \
"ip host ${RTCD_SNIFFED_ADDRESS} and proto 80" \
)

AWK_CMD=( \
awk \
-v RTCD_SNIFFED_ADDRESS="${RTCD_SNIFFED_ADDRESS}" \
-f "${AWK_CONVERSION_SCRIPT}" \
)

CURRENT_PG=0
WATCHER_PID=0

function start_capture_pipeline
{
	local outfile
	local tcp_cmd_str
	local awk_cmd_str
	outfile="${ARCHIVE_DIR}/$(make_output_filename)"
	info "starting pipeline: tcpdump -> awk -> ${outfile}"

	# Build safely-quoted command strings
	tcp_cmd_str=$(printf '%q ' "${TCPDUMP_CMD[@]}")
	awk_cmd_str=$(printf '%q ' "${AWK_CMD[@]}")

	# Start pipeline in a new session so we can signal the whole group
	setsid bash -c "exec ${tcp_cmd_str} 2>&1 | exec ${awk_cmd_str} >>\"${outfile}\"" &
	CURRENT_PG=$!
	# give the new session a moment and verify the process-group exists
	sleep 0.1
	if ! kill -0 -"${CURRENT_PG}" 2>/dev/null
	then
		error "failed to start pipeline pgid=${CURRENT_PG}"
		# attempt cleanup
		stop_capture_pipeline || true
		exit 6
	fi
	info "pipeline started pgid=${CURRENT_PG}"
		write_health_file "${CURRENT_PG}" "${outfile}"
}

function stop_capture_pipeline
{
	if (( ${CURRENT_PG:-0} == 0 ))
	then
		return
	fi
	info "stopping pipeline pgid=${CURRENT_PG}"
	# send SIGTERM to process group
	kill -TERM -"${CURRENT_PG}" 2>/dev/null || true
	local waited=0
	while kill -0 -"${CURRENT_PG}" 2>/dev/null
	do
		sleep 0.2
		waited=$((waited + 1))
		# stop waiting after ~9 seconds (45 * 0.2s) to fit systemd TimeoutStopSec
		if (( waited > 45 ))
		then
			info "pipeline did not exit within grace period, sending KILL to pgid ${CURRENT_PG}"
			kill -KILL -"${CURRENT_PG}" 2>/dev/null || true
			break
		fi
	done
	CURRENT_PG=0
	# remove health file
		remove_health_file
	info "pipeline stopped"
}

function write_health_file
{
	local pg=$1
	local outfile=$2
	if [ -n "${ARCHIVE_DIR:-}" ]
	then
		local hf
		local tmp
		hf="${ARCHIVE_DIR}/.current_pipeline"
		tmp=$(mktemp "${hf}.tmp.XXXXXX")
		printf 'pgid=%s started_at=%s outfile=%s\n' "${pg}" "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" "${outfile}" >"${tmp}"
		mv -f "${tmp}" "${hf}" || true
	fi
}

function remove_health_file
{
	if [ -n "${ARCHIVE_DIR:-}" ]
	then
		rm -f "${ARCHIVE_DIR}/.current_pipeline" 2>/dev/null || true
	fi
}

# watcher: wait for the pipeline process group; if it exits unexpectedly (not via our stop), exit non-zero
function watch_capture_pipeline
{
	local pg=$1
	# wait for the process to die; when it does, check whether we expected it
	while kill -0 -"${pg}" 2>/dev/null
	do
		sleep 1
	done
	# if CURRENT_PG is non-zero and equals pg, then pipeline stopped unexpectedly
	if (( ${CURRENT_PG:-0} == pg ))
	then
		error "pipeline process group ${pg} exited unexpectedly; shutting down"
		# ensure we clean up
		stop_capture_pipeline || true
		exit 6
	fi
}

# manage a background watcher that monitors the current pipeline process group
function start_pipeline_watcher
{
	if (( ${CURRENT_PG:-0} != 0 ))
	then
		watch_capture_pipeline "${CURRENT_PG}" &
		WATCHER_PID=$!
	else
		WATCHER_PID=0
	fi
}

function stop_pipeline_watcher
{
	if (( ${WATCHER_PID:-0} != 0 ))
	then
		kill "${WATCHER_PID}" 2>/dev/null || true
		wait "${WATCHER_PID}" 2>/dev/null || true
	fi
	WATCHER_PID=0
}

function sig_handler
{
	info "signal received, shutting down..."
	# stop watcher first to avoid it exiting the script with an error
	stop_pipeline_watcher
	stop_capture_pipeline
	info "exiting cleanly"
	exit 0
}

trap sig_handler EXIT TERM INT

function seconds_until_utc_midnight
{
	local now
	local next_mid
	now=$(date --utc +%s)
	next_mid=$(date --utc -d 'tomorrow 00:00:00 UTC' +%s)
	echo $((next_mid - now))
}

# wait_until_utc_midnight: sleeps in short increments until next UTC midnight
function wait_until_utc_midnight
{
	local secs
	local slept
	local tosleep
	secs=$(seconds_until_utc_midnight)
	info "sleeping ${secs}s until next UTC midnight rotation"
	slept=0
	while (( slept < secs ))
	do
		tosleep=$((secs - slept))
		if (( tosleep > 10 ))
		then
			tosleep=10
		fi
		sleep "$tosleep" || true
		slept=$((slept + tosleep))
	done
	info "UTC midnight reached, rotating pipeline"
}

function main
{
	while true
	do
		start_capture_pipeline
		start_pipeline_watcher
		wait_until_utc_midnight
		stop_capture_pipeline
		stop_pipeline_watcher
	done
}

main
