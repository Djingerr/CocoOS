---
name: upstream-explore
description: Répondre à « où / comment moonlight-qt fait X ? » (streaming, session, décodeurs, entrées, modèles, backend) en lecture seule, et proposer un point d'accroche depuis app/gui/console sans modifier l'upstream. À utiliser avant toute couture.
---

# Explorer le code upstream de moonlight-qt

Lecture seule. Recherche par nom de symbole / motif d'abord, puis lecture de **plages de lignes ciblées**
(jamais un gros fichier entier). Ne pas explorer les sous-modules (`moonlight-common-c/`, `qmdnsengine/`,
`h264bitstream/`) sauf demande explicite. Si ton outil a des sous-agents, faire cette exploration dans l'un
d'eux : seul le résumé revient dans la conversation principale.

Réponse en **moins de 300 mots** :
1. **Réponse** en 1 à 3 phrases.
2. **Fichiers et symboles** : `chemin:ligne` — fonction/classe — rôle (5 entrées max).
3. **Point d'accroche** : comment CocoOS peut s'y brancher depuis `app/gui/console/` sans toucher
   l'upstream ; sinon la couture minimale (fichier, ~nombre de lignes, sous `#ifdef CONSOLE_UI`) en
   précisant si le fichier figure déjà dans `.agents/seams.txt`.
