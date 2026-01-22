#!/usr/bin/env bash

set -o nounset
set -o pipefail

# atn_capture_convert.sh
# Runs a single tcpdump | awk pipeline, rotates at UTC midnight, handles signals gracefully.

LOG_PREFIX="[atn_capture_convert]"
function info
{
	echo "${LOG_PREFIX} INFO: $*" >&2
}

function error
{
	echo "${LOG_PREFIX} ERROR: $*" >&2
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

if [ -z "${NETWORK_INTERFACE:-}" ] || [ -z "${RTCD_SNIFFED_ADDRESS:-}" ] || [ -z "${AWK_CONVERSION_SCRIPT:-}" ] || [ -z "${ARCHIVE_DIR:-}" ]
then
	error "NETWORK_INTERFACE, RTCD_SNIFFED_ADDRESS, AWK_CONVERSION_SCRIPT and ARCHIVE_DIR must be set in environment"
	exit 4
fi

if ! mkdir -p "${ARCHIVE_DIR}"
then
	error "failed to create ARCHIVE_DIR ${ARCHIVE_DIR}"
	exit 5
fi

function make_filename
{
	local host
	host=$(hostname -s)
	host="${host%%-*}"
	local timestamp
	timestamp=$(date --utc +%Y%m%d_%H%M%S)
	printf "%s_%s_%s.log" "${host}" "${NETWORK_INTERFACE}" "${timestamp}"
}

TCPDUMP_CMD=(tcpdump -i "${NETWORK_INTERFACE}" -n -e -x -tttt -l --immediate-mode "ip host ${RTCD_SNIFFED_ADDRESS} and proto 80")
AWK_CMD=(awk -v RTCD_SNIFFED_ADDRESS="${RTCD_SNIFFED_ADDRESS}" -f "${AWK_CONVERSION_SCRIPT}")

CURRENT_PG=0

function start_pipeline
{
	local outfile
	local tcp_cmd_str
	local awk_cmd_str
	outfile="${ARCHIVE_DIR}/$(make_filename)"
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
		stop_pipeline || true
		exit 6
	fi
	info "pipeline started pgid=${CURRENT_PG}"
	# write a small health file so monitoring can detect the active pipeline
	if [ -n "${ARCHIVE_DIR}" ]
	then
		local hf
		local tmp
		hf="${ARCHIVE_DIR}/.current_pipeline"
		# use mktemp for a secure temporary file
		tmp=$(mktemp "${hf}.tmp.XXXXXX")
		printf 'pgid=%s started_at=%s outfile=%s\n' "${CURRENT_PG}" "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" "${outfile}" >"${tmp}"
		mv -f "${tmp}" "${hf}" || true
	fi
}

function stop_pipeline
{
	if [ ${CURRENT_PG:-0} -eq 0 ]
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
		if [ $waited -gt 45 ]
		then
			info "pipeline did not exit within grace period, sending KILL to pgid ${CURRENT_PG}"
			kill -KILL -"${CURRENT_PG}" 2>/dev/null || true
			break
		fi
	done
	CURRENT_PG=0
	# remove health file
	if [ -n "${ARCHIVE_DIR}" ]
	then
		rm -f "${ARCHIVE_DIR}/.current_pipeline" 2>/dev/null || true
	fi
	info "pipeline stopped"
}

# watcher: wait for the pipeline process group; if it exits unexpectedly (not via our stop), exit non-zero
function watch_pipeline
{
	local pg=$1
	# wait for the process to die; when it does, check whether we expected it
	while kill -0 -"${pg}" 2>/dev/null
	do
		sleep 1
	done
	# if CURRENT_PG is non-zero and equals pg, then pipeline stopped unexpectedly
	if [ "${CURRENT_PG:-0}" -eq "${pg}" ]
	then
		error "pipeline process group ${pg} exited unexpectedly; shutting down"
		# ensure we clean up
		stop_pipeline || true
		exit 6
	fi
}

function sig_handler
{
	info "signal received, shutting down"
	stop_pipeline
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

function main_loop
{
	while true
	do
		start_pipeline
		# start watcher in background to detect unexpected pipeline termination
		if [ ${CURRENT_PG:-0} -ne 0 ]
		then
			watch_pipeline "${CURRENT_PG}" &
			watcher_pid=$!
		else
			watcher_pid=0
		fi
		local secs
		local slept
		local tosleep
		secs=$(seconds_until_utc_midnight)
		info "sleeping ${secs}s until next UTC midnight rotation"
		slept=0
		while [ $slept -lt "$secs" ]
		do
			tosleep=$((secs - slept))
			if [ $tosleep -gt 10 ]
			then
				tosleep=10
			fi
			sleep "$tosleep" || true
			slept=$((slept + tosleep))
		done
		info "UTC midnight reached, rotating pipeline"
		stop_pipeline
		# stop watcher if running
		if [ "${watcher_pid:-0}" -ne 0 ]; then
			kill "${watcher_pid}" 2>/dev/null || true
			wait "${watcher_pid}" 2>/dev/null || true
		fi
		# continue and start a new pipeline with new filename
	done
}

main_loop
