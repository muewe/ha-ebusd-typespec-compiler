#!/usr/bin/env bash
# Offline runner tests: real git refs, fake npm/CSV compilation and bashio.
# The resolver has its own tests with registry metadata fixtures.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
export TEST_DIR
export RUN_FILE="$TEST_DIR/run"

sed 's|/run/s6/basedir/bin/halt|true|' \
    "$ROOT/rootfs/etc/s6-overlay/s6-rc.d/ebusd-typespec-compiler/run" > "$RUN_FILE"

node --input-type=module <<'JS'
import { mkdirSync, writeFileSync } from "node:fs";
const root = `${process.env.TEST_DIR}/source`;
for (const dir of ["node_modules/@typespec/compiler/cmd", "node_modules/@ebusd/ebus-typespec", "src"]) {
  mkdirSync(`${root}/${dir}`, { recursive: true });
}
writeFileSync(`${root}/package.json`, '{"name":"runner-fixture","version":"1.0.0"}');
writeFileSync(`${root}/package-lock.json`, '{}');
writeFileSync(`${root}/src/test.tsp`, '// test entrypoint');
writeFileSync(`${root}/src/de.yaml`, '{}');
writeFileSync(`${root}/node_modules/@typespec/compiler/cmd/tsp.js`, `
const fs = require("node:fs");
if (process.env.NO_COMPILER_OUTPUT === "1") process.exit(7);
fs.mkdirSync("outcsv/@ebusd/ebus-typespec", {recursive: true});
fs.writeFileSync("outcsv/@ebusd/ebus-typespec/test.csv", "direct compiler");
process.exit(Number(process.env.DIRECT_COMPILER_EXIT || 0));
`);
writeFileSync(`${root}/node_modules/@typespec/compiler/package.json`, '{"version":"1.12.0"}');
writeFileSync(`${root}/node_modules/@ebusd/ebus-typespec/package.json`, '{"version":"0.29.0"}');
JS
git init -q -b main "$TEST_DIR/source"
git -C "$TEST_DIR/source" add -f .
git -C "$TEST_DIR/source" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
SHA=$(git -C "$TEST_DIR/source" rev-parse HEAD)
git -C "$TEST_DIR/source" update-ref refs/pull/123/head "$SHA"
git -C "$TEST_DIR/source" update-ref refs/pull/123/merge "$SHA"
export REPO_URL_CFG="file://$TEST_DIR/source"
export OUT_CFG="$TEST_DIR/output" CALL_LOG="$TEST_DIR/calls"

bashio::log.info() { printf '[INFO] %s\n' "$*"; }
bashio::log.fatal() { printf '[FATAL] %s\n' "$*"; }
bashio::log.warning() { printf '[WARNING] %s\n' "$*"; }
bashio::config() {
    case "$1" in
        repo_url) printf '%s' "$REPO_URL_CFG" ;;
        branch) printf '%s' "$BRANCH_CFG" ;;
        output_path) printf '%s' "$OUT_CFG" ;;
        dependency_mode) printf repository ;;
        entrypoint) printf '%s' "${ENTRYPOINT_CFG:-}" ;;
        ignore_compile_errors) printf '%s' "${IGNORE_ERRORS_CFG:-}" ;;
        languages)
            if [ "${MISSING_LANGUAGES:-0}" = 1 ]; then return 1; fi
            printf '%s' "${LANGS_CFG:-de en}" ;;
    esac
}
npm() {
    printf '%s\n' "$*" >> "$CALL_LOG"
    case "$1 ${2:-}" in
        "ci "*|"install "*) return "${FAIL_INSTALL:-0}" ;;
        "ls "*) return "${FAIL_TREE:-0}" ;;
        "run maintsp") return 0 ;;
        "run compile-de"|"run compile-en")
            local result=0
            if [ "${2#compile-}" = "${FAIL_LANGUAGE:-none}" ]; then
                [ "${FAIL_WITH_OUTPUT:-0}" = 1 ] || return 7
                result=7
            fi
            local base=outcsv
            [ "$2" != compile-de ] || base=outcsv.de
            mkdir -p "$base/@ebusd/ebus-typespec"
            if [ "${EMPTY_OUTPUT:-0}" != 1 ]; then
                printf 'r,test,,%s\n' "${2#compile-}" > "$base/@ebusd/ebus-typespec/test.csv"
            fi
            return "${result}"
            ;;
        *) return 99 ;;
    esac
}
export -f bashio::config bashio::log.info bashio::log.fatal bashio::log.warning npm

for BRANCH_CFG in main pull/123/head refs/pull/123/head pull/123/merge "$SHA"; do
    export BRANCH_CFG LANGS_CFG=en
    bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
    grep -q "$SHA" "$OUT_CFG/en/.addon-build-info"
    grep -q '^r,test,,en' "$OUT_CFG/en/test.csv"
    printf 'PASS ref %s\n' "$BRANCH_CFG"
done
grep -q '^ci ' "$CALL_LOG"

export BRANCH_CFG=main MISSING_LANGUAGES=1
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
test -f "$OUT_CFG/de/test.csv"
test -f "$OUT_CFG/en/test.csv"
echo "PASS missing languages option defaults to de/en"
unset MISSING_LANGUAGES

printf 'previous-export\n' > "$OUT_CFG/de/test.csv"
printf 'previous-export\n' > "$OUT_CFG/en/test.csv"
export LANGS_CFG="de en" FAIL_LANGUAGE=en
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL failed compile reported as success"; exit 1
fi
grep -q '^previous-export' "$OUT_CFG/de/test.csv"
grep -q '^previous-export' "$OUT_CFG/en/test.csv"
echo "PASS compile error leaves both previous exports unchanged"
unset FAIL_LANGUAGE

export BRANCH_CFG=pull/999/head
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL invalid PR ref accepted"; exit 1
fi
echo "PASS nonexistent PR ref fails"
export BRANCH_CFG=main LANGS_CFG="../unsafe"
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL unsafe language accepted"; exit 1
fi
echo "PASS invalid language rejected before checkout"

export LANGS_CFG="de en" ENTRYPOINT_CFG=src/test.tsp
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^direct compiler' "$OUT_CFG/de/test.csv"
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
grep -q '^entrypoint=src/test.tsp' "$OUT_CFG/en/.addon-build-info"
echo "PASS direct entrypoint with de/en and provenance record"

export ENTRYPOINT_CFG=../outside.tsp
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL external entrypoint accepted"; exit 1
fi
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
echo "PASS external entrypoint rejected, export unchanged"
unset ENTRYPOINT_CFG

export LANGS_CFG="de en" FAIL_LANGUAGE=en FAIL_WITH_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL faulty CSVs exported without opt-in"; exit 1
fi
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
echo "PASS missing option stays strict even when the failing compiler produces CSVs"

export IGNORE_ERRORS_CFG=true
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^r,test,,en' "$OUT_CFG/en/test.csv"
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_errors_ignored=true$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_exit_code=0$' "$OUT_CFG/de/.addon-build-info"
grep -q '^compile_errors_ignored=false$' "$OUT_CFG/de/.addon-build-info"
grep -q 'NOT a successful compile test' "$TEST_DIR/log"
echo "PASS opt-in exports generated CSVs with warning and per-language error status"

export FAIL_WITH_OUTPUT=0
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL opt-in accepted compiler error without output directory"; exit 1
fi
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS compiler errors without output remain fatal"
unset FAIL_LANGUAGE FAIL_WITH_OUTPUT
export EMPTY_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL opt-in accepted empty CSV output"; exit 1
fi
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS empty output directory remains fatal, existing export unchanged"
unset EMPTY_OUTPUT

export ENTRYPOINT_CFG=src/test.tsp DIRECT_COMPILER_EXIT=7
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS opt-in supports direct TypeSpec entrypoint"
export NO_COMPILER_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL direct compiler error without output was ignored"; exit 1
fi
unset NO_COMPILER_OUTPUT DIRECT_COMPILER_EXIT ENTRYPOINT_CFG

# A successful later run must not retain the previous error marker.
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^compile_exit_code=0$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_errors_ignored=false$' "$OUT_CFG/en/.addon-build-info"
echo "PASS successful follow-up run resets error status"

export FAIL_INSTALL=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL installation error was ignored"; exit 1
fi
unset FAIL_INSTALL
export FAIL_TREE=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL dependency error was ignored"; exit 1
fi
unset FAIL_TREE
echo "PASS installation and dependency errors are not skipped even with opt-in enabled"
