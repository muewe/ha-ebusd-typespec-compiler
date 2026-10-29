import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import semver from "semver";

export const COMPILER = "@typespec/compiler";
export const EMITTER = "@ebusd/ebus-typespec";
export const ASSET = "@typespec/asset-emitter";

function releases(rows, range, nodeVersion) {
  return rows.filter(row =>
    semver.valid(row.version) &&
    semver.satisfies(row.version, range) &&
    (!row.engines?.node || semver.satisfies(nodeVersion, row.engines.node))
  ).sort((a, b) => semver.rcompare(a.version, b.version));
}

function acceptsCompiler(row, compilerVersion) {
  const range = row.peerDependencies?.[COMPILER];
  return !range || semver.satisfies(compilerVersion, range);
}

// Never upgrade the compiler outside the source repository's declared range.
// Resolve the two emitter peer dependencies together instead of asking npm
// to pick their newest releases independently.
export function selectToolchain(manifest, metadata, nodeVersion = process.versions.node) {
  const dependencies = { ...manifest.devDependencies, ...manifest.dependencies };
  const compilerRange = dependencies[COMPILER];
  const emitterRange = dependencies[EMITTER];
  for (const [name, range] of [[COMPILER, compilerRange], [EMITTER, emitterRange]]) {
    if (typeof range !== "string" || !range.trim() || !semver.validRange(range)) {
      throw new Error(`${name}: npm-Semver-Vorgabe fehlt oder wird nicht unterstützt (${range}). Für Git-/Datei-Abhängigkeiten dependency_mode: repository verwenden.`);
    }
  }
  const compilers = releases(metadata[COMPILER], compilerRange, nodeVersion);
  const emitters = releases(metadata[EMITTER], emitterRange, nodeVersion);
  for (const compiler of compilers) {
    for (const emitter of emitters) {
      if (!acceptsCompiler(emitter, compiler.version)) continue;
      const assetRange = emitter.dependencies?.[ASSET];
      if (!assetRange || !semver.validRange(assetRange)) continue;
      const asset = releases(metadata[ASSET], assetRange, nodeVersion)
        .find(row => acceptsCompiler(row, compiler.version));
      if (asset) return {
        compiler: compiler.version,
        emitter: emitter.version,
        asset: asset.version,
        compilerRange,
        emitterRange,
      };
    }
  }
  throw new Error(`Keine kompatible Toolchain innerhalb von ${COMPILER} ${compilerRange} und ${EMITTER} ${emitterRange} gefunden. Keine Versionsgrenzen wurden aufgeweicht.`);
}

function npmMetadata(name, range = "*") {
  const view = args => JSON.parse(execFileSync("npm", [
    "view", ...args, "--json",
  ], { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 }));
  // npm view package@* may return only the latest release. Enumerate versions
  // explicitly so historical, compiler-compatible releases are not omitted.
  const versions = view([name, "versions"]);
  return versions.filter(version => semver.valid(version) && semver.satisfies(version, range))
    .map(version => view([
      `${name}@${version}`, "version", "peerDependencies", "dependencies", "engines",
    ]));
}

export function prepareToolchain(directory, metadataProvider = npmMetadata) {
  const file = resolve(directory, "package.json");
  const original = readFileSync(file, "utf8");
  const manifest = JSON.parse(original);
  const dependencies = { ...manifest.devDependencies, ...manifest.dependencies };
  // Validate before sending unsupported range expressions to npm.
  for (const name of [COMPILER, EMITTER]) {
    if (typeof dependencies[name] !== "string" || !dependencies[name].trim() ||
        !semver.validRange(dependencies[name])) {
      throw new Error(`${name}: keine unterstützte Semver-Vorgabe. dependency_mode: repository verwenden.`);
    }
  }
  const compilers = metadataProvider(COMPILER, dependencies[COMPILER]);
  const emitters = metadataProvider(EMITTER, dependencies[EMITTER]);
  const assetRanges = emitters.map(row => row.dependencies?.[ASSET]).filter(Boolean);
  const metadata = {
    [COMPILER]: compilers,
    [EMITTER]: emitters,
    [ASSET]: assetRanges.length ? metadataProvider(ASSET, assetRanges.join(" || ")) : [],
  };
  const choice = selectToolchain(manifest, metadata);
  writeFileSync(resolve(directory, "package.json.addon-original"), original);
  for (const [name, version] of [[COMPILER, choice.compiler], [EMITTER, choice.emitter]]) {
    const section = Object.hasOwn(manifest.dependencies ?? {}, name)
      ? manifest.dependencies : manifest.devDependencies;
    section[name] = version;
    // If declared in both sections, keep them in sync.
    if (manifest.devDependencies?.[name]) manifest.devDependencies[name] = version;
  }
  manifest.overrides = {
    ...manifest.overrides,
    [COMPILER]: `$${COMPILER}`,
    [EMITTER]: `$${EMITTER}`,
    [ASSET]: choice.asset,
  };
  if (manifest.dependencies?.[ASSET]) manifest.dependencies[ASSET] = choice.asset;
  if (manifest.devDependencies?.[ASSET]) manifest.devDependencies[ASSET] = choice.asset;
  writeFileSync(file, `${JSON.stringify(manifest, null, 2)}\n`);
  // Only the disposable checkout is changed; repository mode keeps lockfiles.
  rmSync(resolve(directory, "package-lock.json"), { force: true });
  rmSync(resolve(directory, "npm-shrinkwrap.json"), { force: true });
  return choice;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const choice = prepareToolchain(process.argv[2] ?? ".");
    console.log(`Toolchain: compiler ${choice.compiler} (Vorgabe ${choice.compilerRange}), emitter ${choice.emitter} (Vorgabe ${choice.emitterRange}), asset-emitter ${choice.asset}`);
    console.log("Nur package.json/Lockfiles im temporären Checkout angepasst; TypeSpec-Quellen unverändert.");
  } catch (error) {
    console.error(`Toolchain-Auflösung fehlgeschlagen: ${error.message}`);
    process.exitCode = 1;
  }
}
