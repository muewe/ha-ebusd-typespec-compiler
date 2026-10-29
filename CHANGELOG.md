# Änderungen

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
