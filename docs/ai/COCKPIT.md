# Console DIY — cockpit quotidien

Entrée installée : `console-diy`. Source unique : `scripts/dev/fleet.py cockpit`
et son module `cockpit.py` dans CocoOS. La flotte de tâches existante est conservée,
pas de second orchestrateur. Aucun agent, prompt, tunnel ou serveur n'est démarré.

```bash
console-diy                   # créer ou rejoindre depuis un vrai terminal
console-diy --create-only     # préparer/réparer les fenêtres manquantes sans s'attacher
console-diy --check           # versions, worktrees, mémoire, hooks, état distant ; pas de création
console-diy --check --json    # mêmes diagnostics structurés
console-diy --verify          # tests outillage/mémoire/flotte/cockpit, aucun build ni modèle
console-diy --help            # sans effet de bord, même hors terminal
```

`--check` retourne 2 si un prérequis est bloqué : actuellement SDK WindowsDesktop
et plugin sous-agents. Ce code attendu n'empêche pas d'ouvrir le cockpit ; il évite
de présenter tout l'environnement comme validé. `--verify` n'est pas un build.

Six fenêtres : `cockpit`, `coco-opencode`, `coco-antigravity`, `host-opencode`,
`host-antigravity`, `integration`. Le cockpit affiche un diagnostic toutes les 5 s.
Les quatre agents ont chacun leur branche `ai/<nom>` et leur worktree ; lancer
**manuellement** `opencode` ou `agy` dans la fenêtre choisie, puis reprendre selon
`session-memory`. Deux développeurs et un reviewer actifs maximum selon la politique
existante : quatre fenêtres disponibles ne signifient pas quatre tâches à démarrer.
La limite de flotte existante ne peut pas empêcher un lancement manuel hors flotte.

Tmux : préfixe habituel `Ctrl-b`, puis `w` pour choisir une fenêtre, `d` pour
détacher. Revenir par `console-diy`. Les index ne sont pas supposés commencer à zéro.
Le relancer ne recrée ni branches ni fenêtres. Les sessions, shells, panneaux et
modifications existants sont préservés ; le lanceur n'utilise aucun `send-keys`,
respawn ou kill sur ces panneaux. Seul le moniteur créé par l'audit peut être
rechargé pendant sa mise en service, jamais les shells d'agents préexistants.

Configuration locale par variables : `CONSOLE_DIY_ROOT` (parent des deux clones),
`CONSOLE_DIY_WORKTREES` (parent des quatre worktrees). Flags `--root`, `--worktrees`,
`--base`, `--session`. `--socket` sert aux tests sur serveur tmux privé.
La base vérifiée actuelle est `tooling/environment-finalisation` dans les deux dépôts.
Le préflight vérifie dépôt Git commun, branche, base avec mémoire et chemins, puis
verrouille le même registre `.ai-fleet/lock` que la flotte existante. Un dossier ou
une session étrangère est refusé sans effacement ; un worktree sale est préservé.
Les fenêtres historiques reconnues peuvent être adoptées sans fermer leur shell.

Le lanceur global délègue au worktree `.ai-worktrees/CocoOS-ops` : ne pas supprimer
ce worktree sans réinstaller le lanceur depuis une autre copie vérifiée. Ancien
lanceur sauvegardé dans `~/.local/bin/console-diy.backup-20261031`.
L'intégration est **manuelle et revue** : `git -C <worktree> status`, puis diff ciblé,
tests et accord humain. Le cockpit ne fait aucun merge/cherry-pick/reset/push.

## Builds et limites

`--verify` est volontairement léger : il n'initialise aucun sous-module, ne restaure
aucun paquet et ne lance pas de build. Tests QML : `scripts/dev/test.sh` (~2 min).
Build Qt : `scripts/dev/build.sh embedded`, sans `--clean`, après vérification des
sous-modules. Le build réel audité a utilisé `CocoOS-tooling`, déjà initialisé ;
les nouveaux worktrees n'ont pas automatiquement ses sous-modules ni son binaire.
Ne pas confondre preuve sur un même code métier et build local de chaque worktree.

HostCompanion : `scripts/dev/restore-offline.sh`, puis
`CONSOLE_DIY_OFFLINE=1 scripts/dev/test.sh` ; build/style analogues, sans restore
implicite. Si le SDK WindowsDesktop manque, la compilation complète reste BLOCKED.
Le contrôle de style refuse un workspace partiellement chargé même avec code dotnet 0.
Un ancien `.dev/last-build.status` est étiqueté historique, jamais nouveau PASS.

## Téléphone — configuration préparée, activation humaine uniquement

État audité : Tailscale connecté ; SSH arrêté ; OpenCode sur `127.0.0.1:49374` ;
daemon Antigravity inactif. Aucun de ces réglages n'a été ouvert/modifié.

1. Installer Tailscale sur le téléphone, même réseau privé, et un client SSH.
2. Après accord : configurer une clé SSH, activer SSH sur Fedora et limiter ACL/
   pare-feu au téléphone via Tailscale. **Non effectué ici** ; ne pas exposer le port 22
   ou OpenCode sur Internet. Fedora doit rester allumé.
3. Depuis le téléphone, une fois SSH autorisé :

   ```bash
   ssh -t marco@100.117.169.94 console-diy
   ```

4. Pour le Web OpenCode : tunnel local depuis le téléphone, par exemple
   `ssh -N -L 49374:127.0.0.1:49374 marco@100.117.169.94` (ou fonction Port Forwarding
   du client mobile). Sur Fedora, exécuter **soi-même** `opencode pair`, puis ouvrir
   son lien à usage unique dans le navigateur du téléphone. Le lien est secret et
   expire : ne pas le copier dans la mémoire, les logs partagés ou un chat.
5. Antigravity 1.4.12 : `agy --remote-control` ou `/remote-control` dans une session,
   uniquement après décision explicite. Depuis le téléphone, ouvrir
   `https://antigravity.google.com` avec le même compte Google et choisir la session.
   `agy remote-control start --session` est l'alternative daemon liée à la session
   utilisateur : **ne pas la lancer sans accord**, pas d'activation permanente ici.

Ne pas utiliser `opencode pair --remote` : ce mode active une exposition Internet.
Aucun appairage réel ni accès depuis un téléphone n'a été validé pendant cet audit.
Sources vérifiées : aides locales ; OpenCode V2 `cli/web`, `cli/plugins` ;
Antigravity `docs/remote-control`, `docs/rules`, `docs/skills` (2026-10-31).
