# ebusd TypeSpec Compiler

Dieses Add-on testet TypeSpec-Konfigurationen aus Git-Repositories und exportiert
erfolgreich kompilierte CSV-Dateien für ebusd. Forks, normale Branches und GitHub-
Pull-Request-Refs können ausgewählt werden; ein Wechsel auf einen bestimmten
Fork ist nicht erforderlich.

## Konfiguration

| Option | Standard | Bedeutung |
|--------|----------|-----------|
| `repo_url` | `https://github.com/john30/ebusd-configuration` | Repository mit den zu prüfenden Quellen |
| `branch` | `master` | Branch, Tag, erreichbare Commit-ID oder Git-Ref |
| `dependency_mode` | `compatible` | Passende Toolchain innerhalb der Repository-Versionsvorgaben auswählen; `repository` übernimmt Manifest und Lockfile unverändert |
| `ignore_compile_errors` | `false` | Bei `true` trotz fehlgeschlagenem Compile bereits erzeugte CSVs exportieren; Warnungen und Fehlerstatus bleiben sichtbar |
| `entrypoint` | `""` | Leer: vollständiger Build über die Repository-Skripte. Sonst relativer Pfad zu einer einzelnen `.tsp`-Einstiegsdatei |
| `languages` | `[de, en]` | Zu kompilierende Sprachen |
| `output_path` | `/config/ebusd-configuration` | Basisverzeichnis für die Unterordner `de` und `en` |

`output_path` muss in einem eingebundenen Verzeichnis liegen, beispielsweise
unter `/config` oder `/share`. Das Add-on startet nicht automatisch beim
Home-Assistant-Start und beendet sich nach seinem Durchlauf.

### Einen Pull Request bei john30 prüfen

```yaml
repo_url: https://github.com/john30/ebusd-configuration
branch: pull/123/head
dependency_mode: compatible
languages:
  - en
output_path: /share/ebusd/pr-test
```

`123` ist ein Platzhalter für die PR-Nummer. `pull/123/head` lädt den
Quell-Commit des Pull Requests direkt aus dem Ziel-Repository, auch wenn der
PR aus einem Fork stammt; alternativ ist `refs/pull/123/head` möglich.
Das GitHub-Format dieser Refs ist in der
[GitHub-Dokumentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/checking-out-pull-requests-locally)
beschrieben.

`pull/123/merge` prüft stattdessen GitHubs Test-Merge mit dem Zielbranch.
Diese Ref ist nicht immer verfügbar, etwa bei Merge-Konflikten. Für einen
normalen Fork werden dessen `repo_url` und Branch-Name eingetragen.

## Abhängigkeiten und reproduzierbare Prüfungen

- **`compatible`:** Ermittelt veröffentlichte Compiler-, ebusd-Emitter- und
  Asset-Emitter-Versionen über npm. Ausgewählt wird die neueste kompatible
  Kombination innerhalb der im Quell-Repository deklarierten Compiler- und
  Emitter-Bereiche und passend zur vorhandenen Node-Version. Die entsprechenden
  Pins und Overrides werden ausschließlich im temporären Checkout gesetzt.
  Dessen Lockfiles werden für diese Auflösung entfernt, die `.tsp`-Dateien und
  npm-Skripte bleiben unverändert.
- **`repository`:** Verändert keine Abhängigkeitsvorgaben. Mit vorhandenem
  `package-lock.json` oder `npm-shrinkwrap.json` wird `npm ci` ausgeführt,
  andernfalls `npm install`. Dieser Modus eignet sich für die exakte Prüfung
  des Repository-Manifests; vorhandene Peer-Konflikte führen zum Fehler.

Der Unterschied ist absichtlich sichtbar: Ein erfolgreicher `compatible`-
Durchlauf bestätigt die Quellen mit der protokollierten Toolchain, nicht die
Fehlerfreiheit des unveränderten Abhängigkeitsmanifests oder des CI-Builds.
Eine mit `repository` gefundene Abhängigkeitsstörung ist weiterhin ein
berichtenswerter Befund zum Pull Request.

Es werden keine Versionsgrenzen ungefragt erweitert. Wenn ein PR unvereinbare
exakte Pins enthält, schlägt die Prüfung weiterhin fehl. Fehlerhafter TypeSpec-
Code führt standardmäßig ebenfalls zum Abbruch; ab Version 1.6.0 kann für den
Export vorhandener CSVs ausdrücklich `ignore_compile_errors: true` gesetzt
werden. Dieser Export ist kein erfolgreicher Compile-Test.
Git-/Datei-Abhängigkeiten statt npm-Semver-Bereichen sind im Kompatibilitätsmodus
nicht unterstützt; dafür steht `repository` bereit.

Im Log stehen Repository, gewählte Ref, exakter Quell-Commit und Toolchain.
Jeder Sprachordner enthält zusätzlich `.addon-build-info` mit Commit und
Compiler-/Emitter-Versionen. Der Build-Helper benötigt Node.js ab Version 22.

## Ablauf und Export

Das Repository muss `maintsp` und je gewünschter Sprache `compile-de` oder
`compile-en` in `package.json` definieren und die lokale TypeSpec-/ebusd-
Toolchain deklarieren. Installations-Lifecycle-Skripte werden deaktiviert,
die expliziten `maintsp`-/`compile-*`-Skripte jedoch ausgeführt.

Alle ausgewählten Sprachen werden zunächst temporär kompiliert. Standardmäßig
werden die Sprachordner unter `output_path` erst ersetzt, wenn alle Sprachen
erfolgreich sind und CSV-Dateien erzeugt haben. Ein Compilerfehler lässt
vorherige Exporte unverändert. Mit `ignore_compile_errors: true` genügt pro
Sprache eine vorhandene, nicht leere CSV-Ausgabe, auch bei Compiler-Exitcode
ungleich null. Der Inhalt der CSVs wird dabei nicht als fehlerfrei validiert.

Für produktives ebusd beispielsweise `--configpath /config/ebusd-configuration/en`
verwenden. Zum Prüfen von PRs besser einen eigenen Test-Ausgabepfad wählen.

### CSVs trotz Compilerfehlern exportieren

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

Diese Option ist beispielsweise für einen Durchlauf mit `ebus/duplicate-id`-
Diagnosen gedacht, bei dem der Emitter dennoch CSVs schreibt. Sie repariert
weder doppelte IDs noch andere TypeSpec-Fehler und entfernt keine betroffenen
Definitionen aus den Dateien. Die CSVs können unvollständig oder für ebusd
mehrdeutig/ungültig sein. Vor produktiver Nutzung prüfen.

Die Diagnosen bleiben im Log sichtbar. Pro Sprache enthält `.addon-build-info`
zusätzlich `ignore_compile_errors`, `compile_exit_code` und
`compile_errors_ignored`. Bei übernommenen Compilerfehlern endet das Add-on
nach dem Export regulär mit Exitcode 0, aber mit einer ausdrücklichen Warnung,
dass dies kein erfolgreicher Compile-Test ist.

Die Option übergeht ausschließlich einen Fehlerstatus des Compile-Kommandos,
nicht Fehler beim Git-Checkout, der Toolchain-Auflösung, Installation oder
Erzeugung von `src/main.tsp`. Fehlende, leere oder mehrdeutige Ausgabeverzeichnisse
führen weiterhin zum Abbruch. Fehlt für eine angeforderte Sprache die
CSV-Ausgabe, werden auch die bereits vorbereiteten anderen Sprachen nicht
exportiert; bestehende Exporte bleiben unverändert.

### Einzelne Konfiguration statt Gesamtrepository testen

Bei `entrypoint: src/vaillant/08.hmu.tsp` wird diese Datei samt ihren Imports
direkt mit dem lokalen ebusd-Emitter kompiliert. `maintsp` und die `compile-*`-
Skripte werden dafür nicht aufgerufen; Deutsch verwendet `src/de.yaml`.
So können PR-Änderungen gezielt geprüft werden, auch wenn andere, nicht
importierte Konfigurationen im Gesamtrepository fehlerhaft sind.

Dieser gezielte Test ist kein erfolgreicher Gesamtrepository-Build. Das Log
und `.addon-build-info` halten den gewählten Einstiegspunkt ausdrücklich fest.
Leer lassen, um weiterhin das gesamte Repository zu prüfen.

## Sicherheit und Grenzen

PRs und Forks können beliebige npm-Skripte enthalten. Nur vertrauenswürdige
Quellen ausführen: Das Add-on hat Schreibzugriff auf `/config` und `/share`;
es ist keine Sandbox für fremden Code. Insbesondere dürfen unkontrollierte
PRs nicht allein wegen des deaktivierten Installations-Hooks als sicher gelten.

Ein echter Home-Assistant-Container-Build prüft zusätzlich APK-Pakete,
Bashio und s6-Integration. Die automatisierten Tests im Repository prüfen
Toolchain-Auswahl und Runner-Verhalten, ersetzen aber diese Integration nicht.

## Entwicklung und Tests

```sh
npm ci --prefix rootfs/opt/ebusd-typespec-compiler
npm test --prefix rootfs/opt/ebusd-typespec-compiler
bash tests/runner.test.sh
```

`tests/live-runner.sh <repo_url> <ref> <sprachen> [entrypoint]` führt die echte
Fetch-/Installations-/Compile-/Export-Pipeline ohne Home Assistant aus.
Nur das Herunterfahren und Bashio-Konfigurationsaufrufe werden ersetzt.
