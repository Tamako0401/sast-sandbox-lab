#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="${1:-${SCRIPT_DIR}/rootfs.tar.zst}"
CHECKSUM="${ARCHIVE}.sha256"

if [[ ! -f "${ARCHIVE}" ]]; then
    echo "archive not found: ${ARCHIVE}" >&2
    exit 1
fi

if [[ -f "${CHECKSUM}" ]]; then
    (
        cd -- "$(dirname -- "${ARCHIVE}")"
        sha256sum -c "$(basename -- "${CHECKSUM}")"
    )
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sast-rootfs-verify.XXXXXXXX")"
cleanup() {
    rm -rf -- "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

tar --zstd -xpf "${ARCHIVE}" -C "${WORK_DIR}"

required=(
    bin/sh bin/hostname bin/ps bin/mount bin/cat bin/echo
    proc tmp workspace etc/passwd etc/group etc/os-release
)
for path in "${required[@]}"; do
    [[ -e "${WORK_DIR}/${path}" ]] || {
        echo "missing rootfs entry: /${path}" >&2
        exit 1
    }
done

file "${WORK_DIR}/bin/busybox" | grep -q 'statically linked'

if (( EUID != 0 )); then
    echo "archive structure passed; run with sudo to include the chroot smoke test"
    exit 0
fi

chroot "${WORK_DIR}" /bin/sh -c '
    set -eu
    echo rootfs-smoke-ok
    test -d /proc
    test -d /workspace
    hostname >/tmp/hostname.txt
    ps >/tmp/ps.txt
'

echo "rootfs verification passed"

