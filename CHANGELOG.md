# Änderungen

## 1.6.0

- Neue Option `ignore_compile_errors`, standardmäßig `false`: Mit `true` können
  trotz Compilerfehlern erzeugte CSV-Dateien exportiert werden, etwa bei
  `ebus/duplicate-id` in `src/tem/15.tsp`.
- Compilerdiagnosen bleiben sichtbar; ignorierte Fehler werden pro Sprache in
  `.addon-build-info` und als ausdrückliche Warnung im Abschluss protokolliert.
- Unterstützt Gesamtrepo-Builds und den direkten `entrypoint`-Modus.
- Fehlende/leere Ausgaben sowie Checkout-, Installations- und
  Toolchain-Fehler bleiben fatal. Exporte erfolgen erst, wenn jede angeforderte
  Sprache CSV-Dateien bereitgestellt hat.
- Regressionstests für Opt-in, strikt bleibenden Standard, fehlende Ausgaben
  und zurückgesetzte Fehlerzustände ergänzt.

## 1.5.0

- Beliebige Fork-Branches und GitHub-PR-Refs über Git-Fetch auswählbar, inklusive
  `pull/<Nummer>/head` und `pull/<Nummer>/merge`.
- Standardmodus `compatible` wählt Compiler, ebusd-Emitter und Asset-Emitter
  gemeinsam innerhalb der Versionsvorgaben des jeweiligen Quell-Repositories.
  Anpassungen betreffen nur das temporäre Manifest, nicht den Fork oder PR.
- Modus `repository` für unveränderte Manifest-/Lockfile-Prüfungen.
- Optionaler `entrypoint` für gezielte `.tsp`-Tests statt eines Gesamtrepo-Builds.
- Exakter Quell-Commit und Toolchain-Versionen werden protokolliert und im
  Export als `.addon-build-info` festgehalten.
- Exporte werden erst nach erfolgreicher Kompilierung aller gewählten Sprachen
  ersetzt; echte Compilerfehler bleiben Fehler.
- Schema für die Liste der Sprachen korrigiert. Kein globaler Compiler-Fallback.
- Resolver- und Runner-Regressionstests sowie Live-Test-Harness hinzugefügt.
