# Sélection des skills Qt — audit du 2026-10-30

Source officielle : https://github.com/TheQtCompanyRnD/agent-skills
Révision examinée : `6845f02d41171a6df8b6e6fe225b7f5d1a6f4adf`.
README, licence et entrées `qt-qml`, `qt-qml-test`, `qt-qml-profiler` lus ;
clone d'audit dans `/tmp/opencode/qt-skills-audit-20261030`, aucun script exécuté.

| Skill | Décision et raison |
|---|---|
| `qt-qml-test` | Référence retenue pour l'écriture de tests : TestCase, SignalSpy, parent visuel, focus et attentes asynchrones. Compatible Qt Quick/qmake car la génération ne dépend pas du système de build. Quelques critères génériques (ne pas tester currentIndex) ne conviennent pas à notre navigation : nos critères d'acceptation priment. |
| `qt-qml`, `qt-qml-review` | Références pour bindings, Loader, images, focus/performance. Le skill local `qml-review` reste la procédure : pas de duplication de grandes listes ni de refonte d'UI guidée par des règles génériques. |
| `qt-cpp-review` | Utile sur un futur diff C++ ciblé (ownership, thread safety), pas installé en bloc avec ses agents/linters. Revue locale puis build réel ; aucun audit de tout upstream pour une tâche d'outillage. |
| `qt-qml-profiler` | À réserver à une investigation de performance demandée : qmlprofiler disponible et binaire instrumenté à vérifier d'abord. Une trace UI ne mesure pas la latence réseau/décodage du streaming. Aucun port de debug ouvert automatiquement. |
| `qt-qml-test-run`, `qt-cmake-project` | Non retenus : infrastructure CMake, alors que ce projet conserve qmake et son runner existant. |
| Canvas2D, Figma, docs générées, preview MCP | Non retenus : hors besoin ; preview/Canvas2D Qt 6.12+ ne correspondent pas au Qt 6.10.3 installé. Aucun MCP/SDK ajouté. |

**Installation effective : aucune copie du pack, aucun plugin, MCP ou script Qt
tiers.** Les principes utiles sont adaptés dans le skill local `qml-review` et
les scripts existants exécutent les contrôles. Les références amont restent
consultables à la révision ci-dessus, sans charger leur corps à chaque tour :

- https://github.com/TheQtCompanyRnD/agent-skills/blob/6845f02d41171a6df8b6e6fe225b7f5d1a6f4adf/skills/qt-qml-test/SKILL.md
- https://github.com/TheQtCompanyRnD/agent-skills/blob/6845f02d41171a6df8b6e6fe225b7f5d1a6f4adf/skills/qt-qml/SKILL.md

## Vérification pratique

`scripts/dev/check.sh`, `scripts/dev/test.sh <filtre>` puis tests complets selon
le diff. Ajouter le test dans le harnais existant ou `idle/tests/`, pas dans une
nouvelle arborescence CMake. `qmllint` n'a pas les types C++ enregistrés au runtime :
un import absent doit être distingué d'une erreur de syntaxe et déclaré BLOCKED,
pas silencieusement ignoré ni considéré comme un succès de validation complète.

Pour le streaming, noter sur le matériel réel : commit, build embedded/vanilla,
Qt/FFmpeg/pilote, codec, résolution/fps/débit, hôte, réseau, scénario, durée et
mesures disponibles (décodage, frames perdues, RTT/gigue, fps UI). Comparer un
scénario reproductible avant/après ; ne pas activer `netem` ou modifier le réseau
sans accord. Navigation manette réelle, focus, sortie/retour, traductions et E2E
Companion restent des validations distinctes, jamais déduites d'un test offscreen.
