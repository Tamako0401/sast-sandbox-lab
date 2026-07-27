#!/bin/sh
set -u

TOTAL=5
PASSED=0
FAILED=0

pass_check() {
    PASSED=$((PASSED + 1))
    printf '[PASS] %s\n' "$1"
}

fail_check() {
    FAILED=$((FAILED + 1))
    printf '[FAIL] %s\n' "$1"
    if [ "$#" -ge 2 ]; then
        printf '       %s\n' "$2"
    fi
}

detail() {
    printf '       %s\n' "$1"
}

printf '%s\n' '== SAST sandbox acceptance job =='

# The Runner records these values before unshare(1), then passes them into the
# rootfs. Namespace IDs let this job fail safely instead of changing the host
# hostname when the UTS namespace has not actually been isolated.
HOST_UTS_NS="${SAST_HOST_UTS_NS:-}"
HOST_PID_NS="${SAST_HOST_PID_NS:-}"
HOST_MNT_NS="${SAST_HOST_MNT_NS:-}"

CURRENT_UTS_NS="$(readlink /proc/self/ns/uts 2>/dev/null)"
if [ -z "${HOST_UTS_NS}" ] || [ -z "${CURRENT_UTS_NS}" ]; then
    fail_check 'independent UTS namespace' \
        'missing SAST_HOST_UTS_NS or /proc namespace information'
elif [ "${HOST_UTS_NS}" = "${CURRENT_UTS_NS}" ]; then
    fail_check 'independent UTS namespace' \
        'the job is still in the host UTS namespace; hostname was not changed'
else
    ORIGINAL_HOSTNAME="$(hostname 2>/dev/null)"
    PROBE_HOSTNAME="sast-box-$$"
    if hostname "${PROBE_HOSTNAME}" 2>/dev/null \
        && [ "$(hostname 2>/dev/null)" = "${PROBE_HOSTNAME}" ]; then
        pass_check 'independent UTS namespace'
        detail "namespace: host=${HOST_UTS_NS}, box=${CURRENT_UTS_NS}"
        detail "hostname changed inside the box: ${ORIGINAL_HOSTNAME} -> ${PROBE_HOSTNAME}"
    else
        fail_check 'independent UTS namespace' \
            'namespace differs, but changing the box hostname failed'
    fi
    if [ -n "${ORIGINAL_HOSTNAME}" ]; then
        hostname "${ORIGINAL_HOSTNAME}" 2>/dev/null || true
    fi
fi

CURRENT_PID_NS="$(readlink /proc/self/ns/pid 2>/dev/null)"
PROC_ONE_PID_NS="$(readlink /proc/1/ns/pid 2>/dev/null)"
VISIBLE_PROCESSES=0
for PROC_PATH in /proc/[0-9]*; do
    if [ -d "${PROC_PATH}" ]; then
        VISIBLE_PROCESSES=$((VISIBLE_PROCESSES + 1))
    fi
done

if [ -z "${HOST_PID_NS}" ] || [ -z "${CURRENT_PID_NS}" ]; then
    fail_check 'independent PID namespace' \
        'missing SAST_HOST_PID_NS or /proc namespace information'
elif [ "${HOST_PID_NS}" = "${CURRENT_PID_NS}" ]; then
    fail_check 'independent PID namespace' \
        'the job is still in the host PID namespace'
elif [ "${PROC_ONE_PID_NS}" != "${CURRENT_PID_NS}" ]; then
    fail_check 'independent PID namespace' \
        '/proc/1 does not belong to the job PID namespace'
else
    pass_check 'independent PID namespace'
    detail "namespace: host=${HOST_PID_NS}, box=${CURRENT_PID_NS}"
    detail "processes visible through /proc: ${VISIBLE_PROCESSES}"
fi

CURRENT_MNT_NS="$(readlink /proc/self/ns/mnt 2>/dev/null)"
PROC_IS_MOUNTED=0
if awk '
    $5 == "/proc" {
        for (i = 1; i <= NF; i++) {
            if ($i == "-" && $(i + 1) == "proc") {
                found = 1
            }
        }
    }
    END { exit(found ? 0 : 1) }
' /proc/self/mountinfo 2>/dev/null; then
    PROC_IS_MOUNTED=1
fi

if [ -z "${HOST_MNT_NS}" ] || [ -z "${CURRENT_MNT_NS}" ]; then
    fail_check 'independent mount namespace with a private /proc' \
        'missing SAST_HOST_MNT_NS or /proc namespace information'
elif [ "${HOST_MNT_NS}" = "${CURRENT_MNT_NS}" ]; then
    fail_check 'independent mount namespace with a private /proc' \
        'the job is still in the host mount namespace'
elif [ "${PROC_IS_MOUNTED}" -ne 1 ]; then
    fail_check 'independent mount namespace with a private /proc' \
        '/proc is not a proc filesystem mount'
elif [ "${PROC_ONE_PID_NS}" != "${CURRENT_PID_NS}" ]; then
    fail_check 'independent mount namespace with a private /proc' \
        '/proc exposes PID 1 from a different PID namespace'
else
    pass_check 'independent mount namespace with a private /proc'
    detail "namespace: host=${HOST_MNT_NS}, box=${CURRENT_MNT_NS}"
fi

ROOTFS_VERSION="$(sed -n 's/^SAST_ROOTFS_VERSION=//p' /etc/sast-rootfs-release 2>/dev/null)"
ROOTFS_ARCH="$(sed -n 's/^TARGET_ARCH=//p' /etc/sast-rootfs-release 2>/dev/null)"
MACHINE_ARCH="$(uname -m 2>/dev/null)"

if [ -z "${ROOTFS_VERSION}" ]; then
    fail_check 'provided minimal rootfs' \
        '/etc/sast-rootfs-release is missing or invalid'
elif [ "${ROOTFS_ARCH}" = "x86_64" ] && [ "${MACHINE_ARCH}" != "x86_64" ]; then
    fail_check 'provided minimal rootfs' \
        "rootfs targets ${ROOTFS_ARCH}, but the machine reports ${MACHINE_ARCH}"
else
    pass_check 'provided minimal rootfs'
    detail "version=${ROOTFS_VERSION}, target=${ROOTFS_ARCH}, machine=${MACHINE_ARCH}"
fi

SCRIPT_PATH="$(realpath "$0" 2>/dev/null)"
case "${SCRIPT_PATH}" in
    /workspace/*) SCRIPT_IN_WORKSPACE=1 ;;
    *) SCRIPT_IN_WORKSPACE=0 ;;
esac

if [ "${SCRIPT_IN_WORKSPACE}" -ne 1 ]; then
    fail_check 'repository cloned outside the sandbox' \
        "job path is not under /workspace: ${SCRIPT_PATH:-unknown}"
elif command -v git >/dev/null 2>&1; then
    fail_check 'repository cloned outside the sandbox' \
        'git is available inside the minimal rootfs'
else
    pass_check 'repository cloned outside the sandbox'
    detail "pre-cloned job exposed at ${SCRIPT_PATH}; git is absent inside the rootfs"
fi

printf '%s\n' '== completion status =='
printf 'passed: %s/%s\n' "${PASSED}" "${TOTAL}"
printf 'failed: %s/%s\n' "${FAILED}" "${TOTAL}"

if [ "${FAILED}" -eq 0 ]; then
    printf '%s\n' 'overall: COMPLETE'
    exit 0
fi

printf '%s\n' 'overall: INCOMPLETE'
exit 1
