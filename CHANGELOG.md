# Changelog

## Unreleased

- CI/CD: new GitHub Actions workflow lints the add-on configuration, runs the
  offline runner and resolver tests, builds the image for `aarch64` and
  `amd64`, and publishes the multi-arch image to ghcr.io (tag = add-on
  version, existing tags are never overwritten). Images are no longer built
  locally on the Home Assistant host. Per-arch images use the
  `<name>-<arch>` naming convention (`ha-ebusd-typespec-compiler-amd64`).
- `config.yaml` now references the published image; `build.yaml` pins the
  Home Assistant base images to Alpine 3.21.
- All runtime log messages, error messages and test names are now in English.
- Dependabot keeps the pinned workflow action versions up to date.

## 1.6.1

- Documentation switched to English: `DOCS.md`, `CHANGELOG.md`, and a new
  short `README.md`.
- New add-on logo and icon (original design: code brackets with a two-wire
  eBUS bus), referenced from `config.yaml`.
- No functional changes.

## 1.6.0

- New option `ignore_compile_errors`, default `false`: With `true`, CSV files
  generated despite compiler errors can be exported, for example for
  `ebus/duplicate-id` in `src/tem/15.tsp`.
- Compiler diagnostics remain visible; ignored errors are recorded per
  language in `.addon-build-info` and logged as an explicit warning at the end.
- Supports whole-repository builds and the direct `entrypoint` mode.
- Missing/empty outputs as well as checkout, installation, and toolchain
  errors remain fatal. Exports only happen once every requested language has
  provided CSV files.
- Added regression tests for the opt-in, the still-strict default, missing
  outputs, and reset error states.

## 1.5.0

- Arbitrary fork branches and GitHub PR refs selectable via Git fetch,
  including `pull/<number>/head` and `pull/<number>/merge`.
- Default mode `compatible` selects compiler, ebusd emitter, and asset
  emitter together within the version constraints of the respective source
  repository. Adjustments only affect the temporary manifest, not the fork
  or PR.
- Mode `repository` for unchanged manifest/lockfile checks.
- Optional `entrypoint` for targeted `.tsp` tests instead of a
  whole-repository build.
- Exact source commit and toolchain versions are logged and stored in the
  export as `.addon-build-info`.
- Exports are only replaced after all selected languages compiled
  successfully; real compiler errors remain errors.
- Fixed the schema for the language list. No global compiler fallback.
- Added resolver and runner regression tests plus a live test harness.
