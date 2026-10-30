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
echo "PASS fehlende languages-Option verwendet de/en"
unset MISSING_LANGUAGES

printf 'vorheriger-export\n' > "$OUT_CFG/de/test.csv"
printf 'vorheriger-export\n' > "$OUT_CFG/en/test.csv"
export LANGS_CFG="de en" FAIL_LANGUAGE=en
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL fehlgeschlagener Compile wurde als Erfolg gemeldet"; exit 1
fi
grep -q '^vorheriger-export' "$OUT_CFG/de/test.csv"
grep -q '^vorheriger-export' "$OUT_CFG/en/test.csv"
echo "PASS Compilerfehler lässt beide vorherigen Exporte unverändert"
unset FAIL_LANGUAGE

export BRANCH_CFG=pull/999/head
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL ungültige PR-Ref wurde akzeptiert"; exit 1
fi
echo "PASS nicht vorhandene PR-Ref schlägt fehl"
export BRANCH_CFG=main LANGS_CFG="../unsafe"
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL unsichere Sprache wurde akzeptiert"; exit 1
fi
echo "PASS ungültige Sprache wird vor Checkout abgelehnt"

export LANGS_CFG="de en" ENTRYPOINT_CFG=src/test.tsp
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^direct compiler' "$OUT_CFG/de/test.csv"
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
grep -q '^entrypoint=src/test.tsp' "$OUT_CFG/en/.addon-build-info"
echo "PASS direkter Einstiegspunkt mit de/en und Herkunftsnachweis"

export ENTRYPOINT_CFG=../outside.tsp
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL externer Einstiegspunkt wurde akzeptiert"; exit 1
fi
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
echo "PASS externer Einstiegspunkt abgelehnt, Export unverändert"
unset ENTRYPOINT_CFG

export LANGS_CFG="de en" FAIL_LANGUAGE=en FAIL_WITH_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL ohne Opt-in wurden fehlerhafte CSVs exportiert"; exit 1
fi
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
echo "PASS fehlende Option bleibt strikt, auch wenn fehlerhafter Compiler CSVs erzeugt"

export IGNORE_ERRORS_CFG=true
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^r,test,,en' "$OUT_CFG/en/test.csv"
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_errors_ignored=true$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_exit_code=0$' "$OUT_CFG/de/.addon-build-info"
grep -q '^compile_errors_ignored=false$' "$OUT_CFG/de/.addon-build-info"
grep -q 'KEIN erfolgreicher Compile-Test' "$TEST_DIR/log"
echo "PASS Opt-in exportiert erzeugte CSVs mit Warnung und sprachspezifischem Fehlerstatus"

export FAIL_WITH_OUTPUT=0
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL Opt-in akzeptierte Compilerfehler ohne Ausgabeverzeichnis"; exit 1
fi
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS Compilerfehler ohne Ausgabe bleiben fatal"
unset FAIL_LANGUAGE FAIL_WITH_OUTPUT
export EMPTY_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL Opt-in akzeptierte leere CSV-Ausgabe"; exit 1
fi
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS leeres Ausgabeverzeichnis bleibt fatal, bestehender Export unverändert"
unset EMPTY_OUTPUT

export ENTRYPOINT_CFG=src/test.tsp DIRECT_COMPILER_EXIT=7
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^direct compiler' "$OUT_CFG/en/test.csv"
grep -q '^compile_exit_code=7$' "$OUT_CFG/en/.addon-build-info"
echo "PASS Opt-in unterstützt direkten TypeSpec-Einstiegspunkt"
export NO_COMPILER_OUTPUT=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL direkter Compilerfehler ohne Ausgabe wurde ignoriert"; exit 1
fi
unset NO_COMPILER_OUTPUT DIRECT_COMPILER_EXIT ENTRYPOINT_CFG

# A successful later run must not retain the previous error marker.
bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1
grep -q '^compile_exit_code=0$' "$OUT_CFG/en/.addon-build-info"
grep -q '^compile_errors_ignored=false$' "$OUT_CFG/en/.addon-build-info"
echo "PASS erfolgreicher Folgelauf setzt Fehlerstatus zurück"

export FAIL_INSTALL=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL Installationsfehler wurde ignoriert"; exit 1
fi
unset FAIL_INSTALL
export FAIL_TREE=1
if bash "$RUN_FILE" > "$TEST_DIR/log" 2>&1; then
    echo "FAIL Abhängigkeitsfehler wurde ignoriert"; exit 1
fi
unset FAIL_TREE
echo "PASS Installations- und Abhängigkeitsfehler werden auch bei aktiviertem Opt-in nicht übergangen"
