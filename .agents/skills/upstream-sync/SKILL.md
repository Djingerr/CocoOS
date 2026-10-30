---
name: upstream-sync
description: Mettre CocoOS à jour avec moonlight-qt officiel (fetch upstream, master en fast-forward, intégration dans console-ui), résoudre les conflits sur les coutures, revérifier build et tests. Sous Claude Code : /upstream-sync ; sinon demander « fais la synchro upstream ».
disable-model-invocation: true
---

# Synchronisation avec moonlight-qt officiel (AGENTS.md §4)

Opération risquée sur l'historique : **montrer chaque étape à Coco avant de l'exécuter** et ne jamais pousser
sans accord explicite.

1. **État propre** : `git status --porcelain` vide, sinon s'arrêter. Noter `git rev-parse console-ui` (point de retour).
2. **Récupérer** : `git fetch upstream` (le remote est ajouté par `scripts/dev/setup.sh` s'il manque).
3. **Résumé** de ce qui arrive : `git log --oneline console-ui..upstream/master | head -30` et
   `git diff --stat console-ui...upstream/master -- $(grep -v '^#' .agents/seams.txt)` →
   indiquer quelles **coutures** sont touchées par upstream (risque de conflit).
4. **master** : `git checkout master && git merge --ff-only upstream/master` (jamais de commit sur master).
5. **Intégrer dans console-ui** — AGENTS.md §4 prescrit `git rebase master` (historique linéaire), mais la
   dernière synchro (`8fe6f1c`) a été faite par **merge**. Demander à Coco laquelle il veut cette fois.
6. **Conflits** : uniquement attendus sur les fichiers de `.agents/seams.txt`. Règle : garder la version
   upstream et **rejouer** nos lignes additives (`#ifdef CONSOLE_UI` / scope `embedded`) par-dessus.
   Un conflit hors coutures = anomalie : s'arrêter et le signaler.
7. **Vérifier** : skill `verify` (embedded), puis `scripts/dev/build.sh vanilla` (le vanilla doit compiler).
8. **Rapport** : commits upstream intégrés, coutures retouchées (diff résumé), résultat des vérifications,
   et la commande de retour arrière (`git reset --hard <sha noté à l'étape 1>`) à garder sous la main.
