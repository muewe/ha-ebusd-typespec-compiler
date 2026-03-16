# ebusd TypeSpec Compiler

This add-on clones a GitHub repository containing ebusd configuration files in
TypeSpec (`.tsp`) format, compiles them for **all supported languages** using the
official [@ebusd/ebus-typespec](https://github.com/john30/ebus-typespec) emitter,
and exports the generated CSV files into language-specific subdirectories.

## How it works

1. The configured Git repository is cloned into a temporary directory (`--depth=1` for efficiency)
2. Repo-specific npm dependencies are installed (`npm install`)
3. `src/main.tsp` is generated from all `.tsp` source files (`npm run maintsp`)
4. The TypeSpec compiler runs for **each language** (`compile-de`, `compile-en`)
5. Each language output is exported to its own subdirectory (`output_path/de/`, `output_path/en/`)
6. The add-on shuts down the container cleanly after completion

> `@typespec/compiler` and `@ebusd/ebus-typespec` are baked into the image at
> build time, so no heavy downloads occur at runtime.

## Output structure

```
output_path/
├── de/       ← German CSV files  (use with: --configpath /your/path/de)
└── en/       ← English CSV files (use with: --configpath /your/path/en)
```

## Configuration

| Option        | Type   | Default                                          | Description                                                              |
|---------------|--------|--------------------------------------------------|--------------------------------------------------------------------------|
| `repo_url`    | string | `https://github.com/john30/ebusd-configuration` | URL of the Git repository containing the TSP configuration files         |
| `branch`      | string | `master`                                         | Git branch to clone (e.g. `master`, `dev`, a feature branch)            |
| `output_path` | string | `/config/ebusd-configuration`                    | Base path — language subdirectories are created automatically            |

## Example configuration

```yaml
repo_url: "https://github.com/john30/ebusd-configuration"
branch: "master"
output_path: "/config/ebusd-configuration"
```

## Pointing ebusd to the output

Use the language subdirectory as your ebusd `--configpath`:

```
--configpath /config/ebusd-configuration/de
```

## Usage

1. Install the add-on from your local add-on store
2. Configure the options above
3. Start the add-on — it will compile all languages and shut down automatically
4. Check the add-on log to see how many CSV files were exported per language
5. To re-run, simply start the add-on again

## Notes

- `boot: manual` is set — the add-on will **never start automatically** on HA boot
- The `output_path` must be inside `/config` as only that directory is mapped
- Any fork of `john30/ebusd-configuration` that provides `maintsp`, `compile-de`
  and `compile-en` scripts in its `package.json` is compatible

## Requirements

The cloned repository must provide the following npm scripts in its `package.json`:

| Script       | Purpose                                     |
|--------------|---------------------------------------------|
| `maintsp`    | Generates `src/main.tsp` from all TSP files |
| `compile-de` | Compiles `main.tsp` to CSV (German)         |
| `compile-en` | Compiles `main.tsp` to CSV (English)        |

This matches the structure of [john30/ebusd-configuration](https://github.com/john30/ebusd-configuration) and compatible forks.