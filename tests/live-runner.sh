#!/usr/bin/env bash
# Runs the real fetch/install/compile/export pipeline without HA/s6.
# Example: tests/live-runner.sh https://github.com/john30/ebusd-configuration \
#          pull/702/head en src/vaillant/08.hmu.tsp
# Only run with repositories whose npm scripts you trust.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export TEST_REPO=${1:?Repository required} TEST_REF=${2:-master}
export TEST_LANGUAGES=${3:-en} TEST_ENTRYPOINT=${4:-}
export TEST_MODE=${TEST_MODE:-compatible}
export TEST_OUTPUT=${TEST_OUTPUT:-$(mktemp -d /tmp/ebusd-live-output.XXXXXX)}
RUN_FILE=$(mktemp)
trap 'rm -f "$RUN_FILE"' EXIT
sed -e 's|/run/s6/basedir/bin/halt|true|' \
    -e "s|/opt/ebusd-typespec-compiler/resolve-toolchain.mjs|$ROOT/rootfs/opt/ebusd-typespec-compiler/resolve-toolchain.mjs|" \
    "$ROOT/rootfs/etc/s6-overlay/s6-rc.d/ebusd-typespec-compiler/run" > "$RUN_FILE"
bashio::config() {
    case "$1" in
        repo_url) printf '%s' "$TEST_REPO" ;;
        branch) printf '%s' "$TEST_REF" ;;
        output_path) printf '%s' "$TEST_OUTPUT" ;;
        languages) printf '%s' "$TEST_LANGUAGES" ;;
        dependency_mode) printf '%s' "$TEST_MODE" ;;
        entrypoint) printf '%s' "$TEST_ENTRYPOINT" ;;
    esac
}
bashio::log.info() { printf '[INFO] %s\n' "$*"; }
bashio::log.fatal() { printf '[FATAL] %s\n' "$*"; }
export -f bashio::config bashio::log.info bashio::log.fatal
printf 'Export directory: %s\n' "$TEST_OUTPUT"
bash "$RUN_FILE"
