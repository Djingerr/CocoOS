# Qualité : preuves et limites

## Contrat des scripts

Depuis la racine du worktree ; `--help` fonctionne aussi hors dépôt, sans créer de log,
configurer Git, lancer de processus Qt ou accéder au réseau.

| Commande | Preuve / log complet |
|---|---|
| `scripts/dev/check.sh` | Syntaxe shell et régressions outillage ; `.dev/last-check.log`, `.dev/last-tooling-test.log` |
| `scripts/dev/check.sh --qml [fichier.qml ...]` | Qt6 qmllint ciblé (défaut : console) ; `.dev/last-qmllint.{log,json}` |
| `scripts/dev/build.sh embedded` | qmake racine **et app**, puis make release ; `.dev/last-build.{log,status}` |
| `scripts/dev/build.sh vanilla` | Même chaîne sans CONSOLE_UI ; même log (archiver avant le mode suivant) |
| `scripts/dev/test.sh [filtre-littéral]` | Suites QML offscreen, configuration vierge par suite ; `.dev/tests/*.log` |
| `scripts/dev/smoke.sh 8` | Binaire embedded vivant jusqu'au timeout, marqueurs console, réseau isolé ; `.dev/last-smoke.log` |
| `scripts/dev/i18n.sh --check` | Extraction dans une copie temporaire, TS à jour et aucune chaîne unfinished ; `.dev/last-i18n.log` |

`PASS/OK` signifie que le contrôle annoncé a effectivement tourné. `FAIL` signifie un
défaut constaté. `BLOCKED` (code 2 pour prérequis manquant) signifie **non vérifié** :
outil/sous-module absent, aucune suite sélectionnée, isolation réseau indisponible, etc.
Les étapes externes build/i18n conservent leur code d'échec original (donc ne pas
interpréter le code seul sans le verdict). Usage invalide : 64. Aucun pipeline ne doit
masquer qmake/lupdate/lrelease/distclean. Les sorties sont résumées ; le log conserve
la sortie complète et le contexte de l'étape en échec.
Les temporaires utilisent un `TMPDIR` existant et accessible en écriture/traversée,
sinon `/tmp/opencode` s'il existe et est accessible, sinon le temporaire système
(`/tmp` pour les scripts shell, sélection standard `tempfile` pour Python).
Aucun répertoire global n'est créé pour cela ; un TMPDIR invalide ne bloque pas les hooks.

### Build et smoke

Les builds sont in-source, incrémentaux ; `--clean` est explicite et contrôlé. Chaque
passage régénère les Makefiles racine et app, même si CONSOLE_UI est déjà présent.
Objets, MOC, RCC et UI de l'app sont isolés sous `.dev/build/<mode>/` : make ne suit
pas les changements de defines et réutiliser les mêmes objets entre modes est faux.
Les bibliothèques communes restent partagées. Un changement de mode doit aussi
relier le binaire commun (le QRC est touché à chaque passage).
Le passage embedded → vanilla → embedded est couvert par fixtures sans SDK.
Ne pas lancer deux builds simultanément dans le même worktree. Après un build vanilla,
recompiler embedded avant smoke ; smoke refuse un processus sans marqueurs console.
Un arrêt spontané, même code 0, ne prouve pas la stabilité. Aucune relance connectée
n'est permise si `unshare -rn` échoue. Le smoke ne valide ni décodage matériel,
manette, hôte réel, ni le parcours Companion E2E.

### QML : ciblage honnête

Utiliser `qmllint-qt6`, jamais le qmllint Qt5 par accident. Exemple autonome :

```bash
scripts/dev/check.sh --qml app/gui/console/ButtonGlyph.qml app/gui/console/CheckMark.qml app/gui/console/ElasticIndicator.qml
```

Les diagnostics structurels (syntaxe, doublons, cycles…) bloquent même si un import
est absent. Les défauts sémantiques sélectionnés (propriété manquante, type incompatible,
lecture seule…) sont des FAIL lorsque les imports sont résolus. Un import absent
(notamment ComputerModel/CompanionClient enregistrés en C++) donne BLOCKED pour
l'analyse sémantique ; ses erreurs dérivées ne sont pas une preuve de bug métier.
Les avis de style restent dans le JSON, sans faire échouer le contrôle. Ce contrôle
n'est **pas** une validation sémantique exhaustive : conserver les tests runtime et le
build. Aucun stub synthétique ne prétend reproduire l'API C++ réelle.
Le parseur accepte uniquement les sorties normales de qmllint Qt6 : code `0` et
code `255` (retour `-1` de qmllint en présence de diagnostics), observés avec Qt 6.10.3.
Tout autre code, notamment crash/signal (`134`, `139`, `143`), donne BLOCKED même si
un JSON valide avec seulement des avis est disponible. Le JSON ne prouve pas à lui
seul que l'analyse s'est terminée.

### Traductions

`i18n.sh --check` n'écrit ni TS, ni QM, ni QRC ; seules `.dev` et la copie temporaire
sont écrites. La comparaison XML ignore uniquement les emplacements source et la
mise en forme structurelle. Sans option, `i18n.sh` met à jour le TS ; `--release`
met aussi à jour le QM et touche QRC **seulement après succès**. Revoir leurs diffs.

## Setup et Git worktrees

`scripts/dev/setup.sh` est hors ligne par défaut : aucun fetch, aucune initialisation
de sous-module, aucune installation SDK. Opt-in réseau séparé : `--fetch-upstream`
(sans `--depth`) et `--submodules` (init récursif sans shallow). Le remote upstream
n'est créé que sur demande de fetch. Les échecs réseau sont BLOCKED et journalisés
dans `.dev/last-setup.log`.

`core.hooksPath` local au clone est partagé : ne jamais le remplacer pour installer
un worktree. Setup examine `core.bare` et `core.worktree` de la configuration commune
et valide les booléens Git de `core.bare`/`extensions.worktreeConfig` (valeur ambiguë,
invalide ou erreur de lecture = BLOCKED). Si `core.bare` est absent/false et
`core.worktree` absent, et qu'aucun `config.worktree` dormant n'existe dans le gitdir
commun **ni** ses `worktrees/*/`, il peut activer
`extensions.worktreeConfig`, puis écrit **uniquement** `git config --worktree
core.hooksPath <chemin-absolu>`. Le hooksPath commun reste inchangé. Si les paramètres
sont sensibles, ou Git trop ancien, installation BLOCKED : demander une décision et
une migration revue par l'utilisateur ; aucun fallback partagé automatique.
Lorsque l'extension est déjà active, setup ne réécrit pas la configuration commune
et ne change que le hooksPath du worktree courant ; les configs voisines restent intactes.
`info/exclude` reste partagé par conception Git et ne reçoit que des artefacts locaux.
Chaque motif requis est assuré individuellement, dont `.dev/` et `.worktrees/` : un
ancien marqueur `cocoos-dev-exclude` n'empêche pas la migration ; aucune duplication.
`status.sh` résout les hooksPath absolus/relatifs et recommande explicitement
`setup.sh --submodules` pour une initialisation réseau.

`.claude/skills` est toujours préservé : ni suppression/copie forcée, ni modification
de skip-worktree. Sur Windows sans liens symboliques, demander avant un fallback.

## Hook et politique upstream

`.agents/seams.txt` reste l'unique liste de coutures : aucun ajout par le hook.
Le hook refuse master, politique absente/non exécutable/échouée, classe inconnue,
upstream/forbidden modifié **ou supprimé**. Les renommages sont analysés comme
suppression + ajout pour ne pas perdre la source. Sans upstream/master, les fichiers
présents dans HEAD restent présumés upstream, même après suppression de l'index.

Une couture doit être additive et un fichier régulier indexé : suppression,
remplacement, binaire ou changement de type sont refusés, ainsi qu'un symlink
nouvellement ajouté (`A`, mode `120000`), y compris si les lignes supprimées étaient déjà CocoOS. Le hook
ne prouve pas l'encapsulation CONSOLE_UI/embedded : revue humaine obligatoire.
Une garde modifiée est signalée (décision de Coco) ; suppression/renommage/changement
de type sont refusés. Les nouveaux fichiers hors zones sont signalés pour revue.
Il n'existe aucun flag de contournement dans cet outillage.
`.githooks/pre-commit` et `scripts/dev/upstream-policy.sh` doivent être indexés avec
le mode `100755`, même si leur copie de travail est encore exécutable. Ainsi,
`git update-index --chmod=-x` ne peut pas préparer une désactivation silencieuse.
`opencode.json`, `opencode.jsonc` et `.opencode/*` sont des `guard`, même sans remote
upstream ; modification signalée et suppression/type sensible refusés comme les autres gardes.

Limite Git : un hook supprimé physiquement/désactivé n'est plus invoqué par Git ; aucun
hook local ne peut empêcher son propre retrait du disque. Le contrôle détecte sa
suppression **stagée si le hook existe encore**. La CI et la revue des garde-fous
restent nécessaires ; ne jamais prendre le hook pour une frontière de sécurité.

## Régressions et CI

`scripts/dev/tooling-test.sh` utilise Python standard et Git dans des dépôts jetables
dans un répertoire temporaire disponible (priorité décrite plus haut), avec espaces dans les chemins, configuration globale
Git désactivée et identité factice. Les commits des fixtures déclenchent le vrai hook ;
aucun commit, push, config globale ou secret du projet n'est utilisé. Les cas couvrent
suppression/renommage upstream et forbidden, coutures, guards, master, politique
manquante/invalide, fichier nouveau, setup offline et isolation entre worktrees,
codes d'échec des étapes, modes incrémentaux, aide sans effet, tests absents,
unshare interdit, i18n lecture seule et classification des résultats qmllint.
Les régressions incluent les bits exécutables indexés, symlinks de coutures ajoutées,
configs worktree dormantes (principale/voisine), booléens invalides, migration d'un ancien
exclude, absence des temporaires préférés et crash qmllint avec JSON pourtant valide.

`.github/workflows/tooling.yml` lance ces contrôles sans SDK/submodules sur les seuls
chemins d'outillage concernés. Elle ne modifie ni ne remplace la CI upstream de build.
Elle ne prétend pas prouver la compilation Qt, le harnais ou le hardware.
Les changements `opencode.json`/`opencode.jsonc`/`.opencode/**` la déclenchent aussi.
Elle parse `opencode.json` avec `json` de Python standard, sans schéma réseau ni
installation OpenCode. Elle exige `command -v tmux` avant `python3 scripts/dev/fleet-test.py` ;
aucun sudo/install runner. Une suite ignorée/skipped n'est pas un exercice réel de flotte.
