# ebusd TypeSpec Compiler

<p align="left">
  <img src="logo.svg" alt="ebusd TypeSpec Compiler logo" width="120">
</p>

A Home Assistant add-on that clones an [ebusd-configuration](https://github.com/john30/ebusd-configuration)
repository (TypeSpec), compiles it for the selected languages, and exports the
generated CSV files to a configurable path — ready to use as the ebusd
configuration source.

## Features

- Compile any fork, branch, or GitHub pull request ref of the TypeSpec-based
  ebusd configuration
- Reproducible toolchain selection: `compatible` (auto-resolved within the
  repository's version constraints) or `repository` (manifest and lockfile
  untouched)
- Multi-language export (`de`, `en`) with atomic replacement only after all
  languages compiled successfully
- Optional single-file `entrypoint` mode for targeted `.tsp` tests
- Optional export of CSVs despite compiler errors (`ignore_compile_errors`)
- Build provenance: exact source commit and toolchain versions are logged and
  stored per language in `.addon-build-info`

## Installation

The add-on is published in my Home Assistant add-on repository:

[![Add repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmuewe%2Fha-addons)

1. Add the repository above to Home Assistant.
2. Open **Settings → Add-ons → Add-on Store**, find **ebusd TypeSpec Compiler** and install it.
3. Configure `repo_url`, `branch`, `languages`, and `output_path`, then start the add-on.

## Quick start

```yaml
repo_url: https://github.com/john30/ebusd-configuration
branch: master
dependency_mode: compatible
languages:
  - de
  - en
output_path: /config/ebusd-configuration
```

Point ebusd at the result, for example
`--configpath /config/ebusd-configuration/en`.

## Continuous Integration

Every push and pull request runs the add-on linter and the offline runner
tests, and builds the image for `aarch64` and `amd64`. On pushes to `main`
(and via manual workflow dispatch), the multi-arch image is published to
[ghcr.io/muewe/ha-ebusd-typespec-compiler](https://github.com/muewe/ha-ebusd-typespec-compiler/pkgs/container/ha-ebusd-typespec-compiler)
— the tag always matches `version` in `config.yaml`, and an already published
tag is never overwritten, so bump the version to publish a new image. The live
pipeline test against the upstream configuration repository can be triggered
manually via workflow dispatch. Action versions are pinned and updated by
Dependabot.

## Documentation

- Full configuration reference, dependency modes, and security notes:
  [DOCS.md](DOCS.md)
- Release notes: [CHANGELOG.md](CHANGELOG.md)

## License

Provided as-is for personal use in your Home Assistant setup.
