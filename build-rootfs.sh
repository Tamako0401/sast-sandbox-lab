#!/usr/bin/env bash
set -euo pipefail

umask 022

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${OUTPUT:-${SCRIPT_DIR}/rootfs.tar.zst}"
CHECKSUM_OUTPUT="${CHECKSUM_OUTPUT:-${OUTPUT}.sha256}"

BUSYBOX_VERSION="1.36.1-4"
BUSYBOX_PACKAGE_URL="${BUSYBOX_PACKAGE_URL:-https://github.com/Tamako0401/sast-sandbox-lab/releases/download/2026.8-lab1/busybox-${BUSYBOX_VERSION}-x86_64.pkg.tar.zst}"
BUSYBOX_PACKAGE_SHA256="14b14151bbc901c6e0c7cbb21fa73db2540df91cdea2a0ff1caf20be2cd8c333"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1784332800}"

for command_name in curl sha256sum tar zstd install find grep; do
    command -v "${command_name}" >/dev/null 2>&1 || {
        echo "missing required command: ${command_name}" >&2
        exit 1
    }
done

case "$(uname -m)" in
    x86_64|amd64) ;;
    *)
        echo "this rootfs build is pinned to x86_64/amd64" >&2
        exit 1
        ;;
esac

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sast-rootfs.XXXXXXXX")"
cleanup() {
    rm -rf -- "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

PACKAGE="${WORK_DIR}/busybox.pkg.tar.zst"
PACKAGE_ROOT="${WORK_DIR}/package"
ROOTFS="${WORK_DIR}/rootfs"
ARCHIVE_TMP="${WORK_DIR}/rootfs.tar.zst"

mkdir -p "${PACKAGE_ROOT}" "${ROOTFS}"
curl --fail --location --retry 3 --silent --show-error \
    "${BUSYBOX_PACKAGE_URL}" --output "${PACKAGE}"

printf '%s  %s\n' "${BUSYBOX_PACKAGE_SHA256}" "${PACKAGE}" \
    | sha256sum --check --status -

tar --zstd -xf "${PACKAGE}" -C "${PACKAGE_ROOT}" usr/bin/busybox

install -d -m 0755 \
    "${ROOTFS}/bin" \
    "${ROOTFS}/dev" \
    "${ROOTFS}/etc" \
    "${ROOTFS}/proc" \
    "${ROOTFS}/tmp" \
    "${ROOTFS}/usr/bin" \
    "${ROOTFS}/workspace"
install -m 0755 "${PACKAGE_ROOT}/usr/bin/busybox" "${ROOTFS}/bin/busybox"
cp -a "${SCRIPT_DIR}/rootfs-overlay/." "${ROOTFS}/"

applets=(
    '[' awk cat chmod cp cut date echo find grep head hostname id kill ln ls
    mkdir mount printf ps pwd readlink realpath rm rmdir sed seq sh sleep sort
    tail test touch tr true umount uname wc
)

available_applets="$(${ROOTFS}/bin/busybox --list)"
for applet in "${applets[@]}"; do
    grep -Fxq -- "${applet}" <<<"${available_applets}" || {
        echo "BusyBox is missing required applet: ${applet}" >&2
        exit 1
    }
    ln -s busybox "${ROOTFS}/bin/${applet}"
done
ln -s ../../bin/busybox "${ROOTFS}/usr/bin/env"

find "${ROOTFS}" -type d -exec chmod 0755 {} +
find "${ROOTFS}/etc" -type f -exec chmod 0644 {} +
chmod 1777 "${ROOTFS}/tmp"

tar --sort=name \
    --format=gnu \
    --mtime="@${SOURCE_DATE_EPOCH}" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -C "${ROOTFS}" \
    -cf - . \
    | zstd -19 --threads=0 --quiet --stdout >"${ARCHIVE_TMP}"

install -m 0644 "${ARCHIVE_TMP}" "${OUTPUT}"
read -r output_sha256 _ < <(sha256sum "${OUTPUT}")
printf '%s  %s\n' "${output_sha256}" "$(basename -- "${OUTPUT}")" \
    >"${CHECKSUM_OUTPUT}"

echo "built ${OUTPUT}"
echo "checksum: $(cat "${CHECKSUM_OUTPUT}")"
