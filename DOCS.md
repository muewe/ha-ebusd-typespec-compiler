# ebusd TypeSpec Compiler

This add-on tests TypeSpec configurations from Git repositories and exports
successfully compiled CSV files for ebusd. Forks, regular branches, and GitHub
pull request refs can be selected; switching to a specific fork is not required.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `repo_url` | `https://github.com/john30/ebusd-configuration` | Repository containing the sources to check |
| `branch` | `master` | Branch, tag, reachable commit ID, or Git ref |
| `dependency_mode` | `compatible` | Select a matching toolchain within the repository's version constraints; `repository` uses the manifest and lockfile unchanged |
| `ignore_compile_errors` | `false` | When `true`, export already generated CSVs despite a failed compile; warnings and error status remain visible |
| `entrypoint` | `""` | Empty: full build via the repository scripts. Otherwise a relative path to a single `.tsp` entry file |
| `languages` | `[de, en]` | Languages to compile |
| `output_path` | `/config/ebusd-configuration` | Base directory for the `de` and `en` subfolders |

`output_path` must be inside a mapped directory, for example under `/config`
or `/share`. The add-on does not start automatically when Home Assistant
starts and exits after its run.

### Checking a pull request against john30

```yaml
repo_url: https://github.com/john30/ebusd-configuration
branch: pull/123/head
dependency_mode: compatible
languages:
  - en
output_path: /share/ebusd/pr-test
```

`123` is a placeholder for the PR number. `pull/123/head` fetches the source
commit of the pull request directly from the target repository, even if the
PR originates from a fork; `refs/pull/123/head` works as well. The GitHub
format of these refs is described in the
[GitHub documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/checking-out-pull-requests-locally).

`pull/123/merge` instead checks GitHub's test merge against the target branch.
This ref is not always available, for example on merge conflicts. For a
regular fork, enter that fork's `repo_url` and branch name.

## Dependencies and reproducible checks

- **`compatible`:** Resolves published compiler, ebusd emitter, and asset
  emitter versions via npm. The newest compatible combination is selected
  within the compiler and emitter ranges declared by the source repository
  and matching the installed Node version. The corresponding pins and
  overrides are applied only in the temporary checkout. Its lockfiles are
  removed for this resolution; the `.tsp` files and npm scripts remain
  unchanged.
- **`repository`:** Does not modify any dependency constraints. With an
  existing `package-lock.json` or `npm-shrinkwrap.json`, `npm ci` is run,
  otherwise `npm install`. This mode is suited for exactly checking the
  repository manifest; existing peer conflicts cause the run to fail.

The difference is intentionally visible: a successful `compatible` run
confirms the sources with the logged toolchain, not the correctness of the
unchanged dependency manifest or the CI build. A dependency problem found
with `repository` is still a reportable finding for the pull request.

Version ranges are never widened on their own. If a PR contains incompatible
exact pins, the check still fails. Faulty TypeSpec code also aborts by
default; as of version 1.6.0 `ignore_compile_errors: true` can be set
explicitly to export existing CSVs. This export is not a successful compile
test.
Git/file dependencies instead of npm semver ranges are not supported in
compatibility mode; use `repository` for those.

The log contains repository, selected ref, exact source commit, and toolchain.
Each language folder additionally contains `.addon-build-info` with the commit
and compiler/emitter versions. The build helper requires Node.js version 22
or later.

## Flow and export

The repository must define `maintsp` and, per requested language, `compile-de`
or `compile-en` in `package.json`, and declare the local TypeSpec/ebusd
toolchain. Install lifecycle scripts are disabled, but the explicit
`maintsp`/`compile-*` scripts are executed.

All selected languages are compiled to a temporary location first. By default,
the language folders under `output_path` are only replaced once all languages
succeeded and produced CSV files. A compiler error leaves previous exports
unchanged. With `ignore_compile_errors: true`, one existing, non-empty CSV
output per language is sufficient, even with a compiler exit code other than
zero. The content of the CSVs is not validated as error-free in that case.

For a productive ebusd, for example use `--configpath /config/ebusd-configuration/en`.
For checking PRs, prefer a dedicated test output path.

### Exporting CSVs despite compiler errors

```yaml
repo_url: https://github.com/john30/ebusd-configuration
branch: master
dependency_mode: compatible
ignore_compile_errors: true
entrypoint: ""
languages:
  - en
output_path: /share/ebusd/ebusd-configuration
```

This option is intended, for example, for a run with `ebus/duplicate-id`
diagnostics where the emitter still writes CSVs. It does not repair duplicate
IDs or other TypeSpec errors and does not remove affected definitions from
the files. The CSVs may be incomplete or ambiguous/invalid for ebusd. Review
before productive use.

The diagnostics remain visible in the log. Per language, `.addon-build-info`
additionally contains `ignore_compile_errors`, `compile_exit_code`, and
`compile_errors_ignored`. When compiler errors are accepted, the add-on ends
after the export regularly with exit code 0, but with an explicit warning
that this is not a successful compile test.

The option only bypasses a failure status of the compile command, not errors
during Git checkout, toolchain resolution, installation, or generation of
`src/main.tsp`. Missing, empty, or ambiguous output directories still abort
the run. If a requested language has no CSV output, the other already
prepared languages are not exported either; existing exports remain
unchanged.

### Testing a single configuration instead of the whole repository

With `entrypoint: src/vaillant/08.hmu.tsp`, that file and its imports are
compiled directly with the local ebusd emitter. `maintsp` and the `compile-*`
scripts are not called for this; German uses `src/de.yaml`. This allows
targeted checking of PR changes even if other, non-imported configurations
in the whole repository are faulty.

This targeted test is not a successful whole-repository build. The log and
`.addon-build-info` explicitly record the selected entry point. Leave empty
to keep checking the entire repository.

## Security and limits

PRs and forks can contain arbitrary npm scripts. Only run trusted sources:
the add-on has write access to `/config` and `/share`; it is not a sandbox
for foreign code. In particular, unreviewed PRs must not be considered safe
just because the install hook is disabled.

A real Home Assistant container build additionally verifies APK packages,
Bashio, and s6 integration. The automated tests in this repository check
toolchain selection and runner behavior, but do not replace that integration.

## Development and tests

```sh
npm ci --prefix rootfs/opt/ebusd-typespec-compiler
npm test --prefix rootfs/opt/ebusd-typespec-compiler
bash tests/runner.test.sh
```

`tests/live-runner.sh <repo_url> <ref> <languages> [entrypoint]` runs the real
fetch/install/compile/export pipeline without Home Assistant. Only shutdown
and Bashio configuration calls are replaced.
