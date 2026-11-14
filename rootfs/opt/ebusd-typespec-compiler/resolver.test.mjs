import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { selectToolchain, prepareToolchain, COMPILER, EMITTER, ASSET } from "./resolve-toolchain.mjs";

const compiler = version => ({ version, engines: { node: ">=22" } });
const asset = (version, peer) => ({ version, peerDependencies: { [COMPILER]: peer } });
const emitter = (version, peer, assetRange) => ({
  version, peerDependencies: { [COMPILER]: peer }, dependencies: { [ASSET]: assetRange },
});
const metadata = {
  [COMPILER]: ["1.8.0", "1.12.0", "1.17.0"].map(compiler),
  [EMITTER]: [
    emitter("0.26.0", "^1.8.0", "^0.78.0"),
    emitter("0.29.0", "^1.11.0", "^0.79.1"),
    emitter("0.31.0", "~1.17.0", "~0.79.3"),
  ],
  [ASSET]: [
    asset("0.78.0", "^1.8.0"), asset("0.79.1", "^1.10.0"),
    asset("0.79.2", "^1.16.0"), asset("0.79.3", "^1.17.0"),
  ],
};
const manifest = (compilerRange, emitterRange) => ({
  dependencies: { [COMPILER]: compilerRange, [EMITTER]: emitterRange },
});

test("old fork with open emitter range gets matching 1.8/0.26/0.78 toolchain", () => {
  const result = selectToolchain(manifest("~1.8.0", ">=0.26.0"), metadata, "24.0.0");
  assert.deepEqual([result.compiler, result.emitter, result.asset], ["1.8.0", "0.26.0", "0.78.0"]);
});
test("john30 master gets asset-emitter 0.79.1 instead of incompatible 0.79.3", () => {
  const result = selectToolchain(manifest("~1.12.0", "~0.29.0"), metadata, "24.0.0");
  assert.deepEqual([result.compiler, result.emitter, result.asset], ["1.12.0", "0.29.0", "0.79.1"]);
});
test("new PR can use the newest declared toolchain", () => {
  const result = selectToolchain(manifest("~1.17.0", "~0.31.0"), metadata, "24.0.0");
  assert.deepEqual([result.compiler, result.emitter, result.asset], ["1.17.0", "0.31.0", "0.79.3"]);
});
test("incompatible exact pins are not silently relaxed", () => {
  assert.throws(() => selectToolchain(manifest("1.8.0", "0.31.0"), metadata, "24.0.0"), /No compatible toolchain/);
});
test("Node engine is respected", () => {
  assert.throws(() => selectToolchain(manifest("~1.12.0", "~0.29.0"), metadata, "20.0.0"), /No compatible toolchain/);
});
test("missing or unsupported semver ranges are rejected", () => {
  for (const range of [undefined, "", "github:user/compiler", "file:../compiler"]) {
    assert.throws(() => selectToolchain(manifest(range, "^0.29"), metadata, "24.0.0"), /unsupported/);
  }
});
test("only temporary manifest/lockfile changed; scripts and TypeSpec sources are preserved", () => {
  const directory = mkdtempSync(join(tmpdir(), "toolchain-test-"));
  try {
    const value = manifest("~1.12.0", "~0.29.0");
    value.scripts = { maintsp: "custom command", "compile-en": "custom compiler" };
    value.overrides = { "some-library": "1.0.0" };
    const original = JSON.stringify(value);
    writeFileSync(join(directory, "package.json"), original);
    writeFileSync(join(directory, "package-lock.json"), "{}");
    writeFileSync(join(directory, "main.tsp"), "// source\n");
    prepareToolchain(directory, name => metadata[name]);
    const result = JSON.parse(readFileSync(join(directory, "package.json"), "utf8"));
    assert.equal(result.dependencies[COMPILER], "1.12.0");
    assert.equal(result.dependencies[EMITTER], "0.29.0");
    assert.equal(result.overrides[ASSET], "0.79.1");
    assert.equal(result.overrides[COMPILER], `$${COMPILER}`);
    assert.equal(result.overrides["some-library"], "1.0.0");
    assert.deepEqual(result.scripts, value.scripts);
    assert.equal(readFileSync(join(directory, "package.json.addon-original"), "utf8"), original);
    assert.equal(readFileSync(join(directory, "main.tsp"), "utf8"), "// source\n");
    assert.equal(existsSync(join(directory, "package-lock.json")), false);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
