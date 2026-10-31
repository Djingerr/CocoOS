# Audit de mise en service — 2026-10-31

Légende : PASS = exécuté et réussi dans la portée indiquée ; FAIL = échec constaté ;
BLOCKED = prérequis manquant ; NOT TESTED = aucune preuve d'exécution.

## Installation et sécurité

| Élément | État | Preuve / portée |
|---|---|---|
| Git 2.56.0, tmux 3.7c | PASS | exécutables et versions vérifiés |
| Node 16.20.2, npm 8.19.4 | PASS présence | Node ancien/EOL ; mise à niveau recommandée, non réalisée ; présence ≠ compatibilité de tous les plugins |
| OpenCode 2.2.4, `agy` 1.4.12 | PASS | chemins et aides réels, aucun alias `antigravity` présumé |
| Configurations OpenCode de projet | PASS | six rôles/commandes, 11 skills CocoOS / 12 HostCompanion détectés par serveur réel |
| Permissions OpenCode | PASS | 19 évaluations CocoOS, 20 HostCompanion ; aucune opération dangereuse exécutée |
| Connexions de modèles | PASS inventaire / NOT TESTED inférence | OpenAI et Claude Agent « stored » ; catalogue `agy models` disponible ; aucun prompt fournisseur soumis |
| Statistiques natives | PASS | `opencode stats --days 0 --json` retourne des agrégats ; pas de conversation exportée |
| Plugin status-line 1.2.0 | PASS installation / NOT TESTED chiffres live | paquet V2 et catalogue natif ; TUI en pseudo-terminal sans prompt vivant, aucune signature d'erreur détectée |
| Plugin subagent-statusline 2.1.0 | FAIL installation / BLOCKED service | `opencode plugin add ...@2.1.0` échoue « unable to resolve dependency tree » ; pas de contournement de dépendances |
| Confidentialité | PASS portée audit | aucun fichier auth/credential ouvert, aucune conversation privée synchronisée, pas de fournisseur payant ajouté |

Le plugin sous-agents était seulement déclaré dans cli.json, absent du catalogue/cache
observés. Après accord, tentative d'installation native épinglée puis retrait de la
déclaration CLI non résolue. Sauvegarde : `~/.config/opencode/cli.json.backup-20261031`.
Autres préférences, modèle/permissions et plugin de statistiques conservés. Pas de
restart forcé du serveur, pas de `--force` ou `legacy-peer-deps`. Compatibilité de ce
plugin à résoudre séparément ; le cockpit/statistiques natives restent indépendants.

## Cockpit réellement mis en service

PASS : `console-diy` installé ; source unique extension de `fleet.py` dans CocoOS.
Ancien lanceur sauvegardé : `~/.local/bin/console-diy.backup-20261031`.
Session existante `console-diy` adoptée : cinq fenêtres préservées, ajout du cockpit
manquant ; les panneaux d'intégration existants et l'autre session `0` restent intacts.
Deux réouvertures réelles : six fenêtres, mêmes identifiants, aucun agent lancé.
`--help` et appel sans terminal ne créent rien ; `--create-only` fonctionne sans TTY.

PASS : 13 tests cockpit avec vrais Git/tmux sur sockets privés : préflight,
idempotence, concurrence, mauvais dépôt/base/session, état sale préservé, attachement
et détachement d'un vrai pseudo-terminal. Seuls les serveurs tmux jetables des tests
sont arrêtés ; aucune session utilisateur n'a été fermée.

PASS : `console-diy --verify` sur les worktrees déployés, et diagnostic `--check`
exécuté réellement (code 2 attendu : plugin sous-agents et SDK WindowsDesktop BLOCKED) :
59 régressions CocoOS, 39 HostCompanion ; 22 tests mémoire par dépôt ; 8 tests flotte
par dépôt ; suite finale cockpit 13/13. Les fichiers non suivis/index sont préservés par les
scénarios temporaires. Vérifications Git propres et hooks actifs sur les quatre lanes.
Reprise dans une session IA indépendante à contexte réduit : PASS simulation sur
les deux projets, uniquement depuis les fichiers persistants. Deux défauts de
préflight/reprise setup trouvés, corrigés et couverts par les deux tests ajoutés.
Ce n'est pas un test d'un autre fournisseur ; aucun prompt CLI fournisseur soumis.
Contre-revue en lecture seule : les deux défauts confirmés résolus ; les tests sont
attribués à leur session d'exécution, pas présentés comme réexécutés par le reviewer.

Déploiement **explicitement autorisé** : seuls `ai/coco-opencode`, `ai/coco-antigravity`,
`ai/host-opencode`, `ai/host-antigravity` sont avancés par `merge --ff-only`, après
contrôle de tout le lot (branche exacte, propreté, ancêtre). Aucun merge des clones
principaux, changement de branche, reset ou push. Commits de code : CocoOS `c9335cb3`,
HostCompanion `de4a4ee` ; dernier complément de documentation/moniteur : voir Git.

## Builds et qualité

| Contrôle | État | Résultat réel |
|---|---|---|
| Qt/qmake | PASS | Qt 6.10.3, build embedded sans clean sur `CocoOS-tooling` initialisé (10 s) ; code métier identique à cette branche |
| Smoke | PASS | `scripts/dev/smoke.sh 3`, isolé hors réseau, même worktree |
| QML | PASS dernière passe | 17/17 suites, dont ConsoleHome 48/48 ; aucun code métier corrigé |
| Premier passage QML | FAIL puis interruption | assertion `test_9o_bootLogoLandsOnTheTopBarLogo`, ligne 758 ; suite interrompue par timeout externe 120 s ; instabilité à surveiller, pas effacée par la nouvelle passe verte |
| qmllint ciblé | PASS | `idle/components/KeyHint.qml`, zéro avis |
| qmllint complet ConsoleHome | BLOCKED historique | imports C++ runtime ; pas prétendu validé par l'analyse ciblée |
| Build vanilla | NOT TESTED cette mission | aucune couture modifiée ; ancien résultat reste dans TOOLING-REPORT |
| .NET SDK | PASS présence | SDK Fedora 8.0.132 |
| Tests Shared | PASS | 125/125, TRX frais ; script testé avec CONSOLE_DIY_OFFLINE=1 |
| Restore NuGet local | PASS | helper restore-offline, source locale vide + cache ; références Windows 8.0.32 téléchargées séparément après accord (4 447 564 octets) |
| Build solution .NET | BLOCKED | MSB4019 : targets Microsoft.NET.Sdk.WindowsDesktop manquantes dans le SDK Fedora ; code dotnet 1 conservé dans log |
| Style solution .NET | BLOCKED | workspace partiellement chargé malgré code dotnet 0 ; faux PASS corrigé et régression ajoutée |
| Windows / DPAPI / tray / installeur / E2E | NOT TESTED | Linux ne les valide pas ; aucune installation sur « djing » |

Les nouveaux worktrees n'ont pas automatiquement les sous-modules/builds du clone
initialisé. `console-diy --verify` ne fait ni build ni téléchargement. Le moniteur
étiquette les anciens statuts comme historiques, jamais comme un test frais.

## Téléphone

PASS : disponibilité réelle de `opencode pair` (Web natif) et `agy --remote-control`.
PASS : OpenCode écoute sur 127.0.0.1:49374, daemon agy distant inactif, Tailscale
1.104.4 connecté. BLOCKED accès SSH : sshd arrêté. NOT TESTED : téléphone/appairage.
Aucun tunnel, paire, accès public ou service distant activé. Parcours sécurisé et
actions humaines exactes : `COCKPIT.md`. Ne pas utiliser `opencode pair --remote`
sans nouvel accord, il expose le serveur à Internet.

## Actions restantes

1. Résoudre la compatibilité du plugin sous-agents sans forcer les dépendances.
2. Décider d'un SDK .NET Microsoft complet ou d'une validation Windows ; aucun gros
   téléchargement ni installation système automatique.
3. Configurer clés/ACL/pare-feu SSH limité à Tailscale puis tester le téléphone.
4. Initialiser explicitement les dépendances Qt des worktrees devant compiler.
5. Vérifier les inférences/quota et statistiques live seulement après demande
   explicite ; une configuration authentifiée n'est pas une preuve de disponibilité.

Guide quotidien : `COCKPIT.md`. Reprise/handoff : `MEMORY.md`. Historique des tests
antérieurs conservé dans `TOOLING-REPORT.md` et `MEMORY-REPORT.md`.
