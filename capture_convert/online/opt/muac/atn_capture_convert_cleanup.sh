#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[atn_capture_cleanup]"
info(){ echo "${LOG_PREFIX} INFO: $*" >&2; }
err(){ echo "${LOG_PREFIX} ERROR: $*" >&2; }

RETENTION_DAYS=${RETENTION_DAYS:-7}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "required command '$1' not found"; exit 2; }; }
require_cmd lsof
require_cmd find

if [ -z "${ARCHIVE_DIR:-}" ]; then
    err "ARCHIVE_DIR must be set in environment"
    exit 3
fi

if [ ! -d "${ARCHIVE_DIR}" ]; then
    info "ARCHIVE_DIR ${ARCHIVE_DIR} does not exist, nothing to clean"
    exit 0
fi

now=$(date +%s)
cutoff=$((now - RETENTION_DAYS*24*60*60))

info "cleaning files in ${ARCHIVE_DIR} older than ${RETENTION_DAYS} days"

while IFS= read -r -d '' file; do
    # check if open using lsof; handle lsof errors explicitly
    if lsof -- "${file}" >/dev/null 2>&1; then
        info "skipping open file ${file}"
        continue
    else
        ls_exit=$?
        if [ ${ls_exit} -ne 1 ]; then
            err "lsof returned error (code ${ls_exit}) for ${file}; skipping deletion"
            continue
        fi
    fi
    info "removing ${file}"
    if ! rm -f -- "${file}"; then
        err "failed to remove ${file}"
    fi
done < <(find "${ARCHIVE_DIR}" -maxdepth 1 -type f -name "*.log" -print0 | while IFS= read -r -d '' f; do
    # check mtime
    mtime=$(stat -c %Y "${f}")
    if [ "${mtime}" -lt ${cutoff} ]; then printf '%s\0' "${f}"; fi
done)

info "cleanup finished"

# exit with non-zero if any rm failed would have been logged; allow failures to propagate
exit 0
