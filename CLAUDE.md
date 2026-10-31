@AGENTS.md

# Spécifique à Claude Code

Tout le contexte du projet est dans `AGENTS.md` (importé ci-dessus), commun à toutes les IA.
Ce qui suit ne concerne que Claude Code :

- **Skills** : source canonique `.agents/skills`, via le lien `.claude/skills` sur ce worktree Linux.
  Si le lien n'est pas matérialisé dans un clone Windows, lire explicitement le skill canonique.
  Commandes manuelles : `/next [tâche]`, `/upstream-sync`.
- **Sous-agents** (`.claude/agents/`, enveloppes des skills du même nom) : `upstream-explorer` (Haiku,
  skill `upstream-explore`), `qml-reviewer` (Sonnet, skill `qml-review`), `verifier` (Haiku, skill `verify`).
  Les préférer pour toute exploration ou vérification volumineuse : seul le résumé revient ici.
- **Hooks** (`.claude/settings.json`) : `upstream-guard.sh` applique `scripts/dev/upstream-policy.sh` *avant*
  chaque édition (refus / demande de confirmation) ; `session-start.sh` fournit la reprise commune
  en lecture seule ; setup reste explicite. `qml-check.sh` renvoie les erreurs de qmllint après édition QML.
- Reprise manuelle : `python3 scripts/dev/memory.py resume` ; passation : `/session-memory`
  ou lecture explicite du skill canonique. Vérifier le chargement de `@AGENTS.md` via `/context`.
- Barre d'état : `.claude/statusline.sh` (worktree@branche · contexte · dernier build). `/compact Garde : …`
  vers 60 % de contexte ; `/clear` entre deux tâches sans lien ; `/effort` selon la difficulté.
