# Thème Plymouth « CocoOS »

L'écran affiché pendant que Linux démarre : le mot-symbole CocoOS sur noir, sans
texte ni barre. Il a le même dessin que l'écran de démarrage de l'interface
(`app/gui/console/BootSplash.qml`), pour que le passage de l'un à l'autre ne se voie pas.

À installer sur la console (Orange Pi), pas sur une machine de développement :

```bash
sudo cp -r cocoos /usr/share/plymouth/themes/
sudo plymouth-set-default-theme -R cocoos      # Debian / Armbian : régénère l'initramfs
```

Ligne de commande du noyau (rien de Linux à l'écran, cf. `CLAUDE.md` §1) :

```
quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=false rd.udev.log_level=3
```

Sur Armbian, l'ajouter à `extraargs=` dans `/boot/armbianEnv.txt`.

Le logo (`cocoos/logo.png`) se régénère avec `./make-logo.py` (Python + Pillow).
