#!/bin/sh
set -u

MAX_ATTEMPTS=50
HOLD_SECONDS=8
COUNTER_FILE=/tmp/sast-process-count

cleanup() {
    for proc_path in /proc/[0-9]*; do
        pid="${proc_path#/proc/}"
        if [ "${pid}" != 1 ]; then
            kill "${pid}" 2>/tmp/sast-cleanup-errors || true
        fi
    done
    wait 2>/tmp/sast-cleanup-errors || true
}
trap cleanup EXIT INT TERM

echo "attempting at most ${MAX_ATTEMPTS} short-lived processes"
: >"${COUNTER_FILE}"

spawn_worker() {
    i=1
    while [ "${i}" -le "${MAX_ATTEMPTS}" ]; do
        sleep "${HOLD_SECONDS}" </etc/passwd &
        echo "${i}" >"${COUNTER_FILE}"
        i=$((i + 1))
    done
}

worker_status=0
spawn_worker </etc/passwd &
worker_pid=$!
wait "${worker_pid}" || worker_status=$?

cleanup
trap - EXIT INT TERM

started=0
if [ -s "${COUNTER_FILE}" ]; then
    read -r started <"${COUNTER_FILE}"
fi

echo "successfully started ${started} child processes"

if [ "${worker_status}" -eq 0 ] || [ "${started}" -ge "${MAX_ATTEMPTS}" ]; then
    echo 'no process limit was observed; check pids.max and cgroup membership' >&2
    exit 1
fi

echo 'process limit observed; cleanup will terminate the test children'
