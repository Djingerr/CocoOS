# CocoOS — écran de veille, dossier de passation pour Claude Code

1. Copie ce dossier dans le dépôt CocoOS, par exemple sous `docs/design/idle/`.
2. Dans Claude Code, à la racine du dépôt :

   > Lis `docs/design/idle/CLAUDE_BRIEF.md` et exécute-le phase par phase. Arrête-toi à chaque porte de validation non passée.

Le point d'entrée est `CLAUDE_BRIEF.md`. `SPEC.md` décrit chaque écran ; `reference/` contient les rendus cibles et les mesures exactes.

Outils (Python 3) : `pip install pillow numpy playwright && python3 -m playwright install chromium`
(Playwright seulement pour régénérer les références).
