# Intégration OpenCode

La configuration versionnée unique est `../opencode.json` (depuis cette
arborescence : fichier à la racine du dépôt). Elle contient agents, commandes et
permissions V2 ; ne pas créer une deuxième configuration qui la masque.

Les skills sont détectés nativement dans `../.agents/skills/`, sans duplication.
Les règles restent dans `../AGENTS.md`, les procédures d'usage dans
`../docs/ai/OPENCODE.md`. Aucun hook Claude Code n'est supposé chargé par Claude Agent.
