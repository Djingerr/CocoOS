.pragma library

// Copie de docs/design/idle/mock/idle_status.mock.json (données de test des quatre états), en
// module JS : QML ne lit pas un .json local sans QML_XHR_ALLOW_FILE_READ, ce qui gênerait
// l'aperçu et les tests lancés depuis le disque. À régénérer si le mock change.
// TODO(HostCompanion) : remplacé par les vraies données (session, téléchargements, jaquettes).

var data = {
  "$comment": "Données de test de l'écran de veille. Un objet par état. Les horodatages relatifs (secondsAgo) sont convertis en absolu au chargement par le mock. coverUrl pointe vers la jaquette de test ; en production elle viendra de Playnite via HostCompanion.",
  "game": {
    "host": {
      "name": "PC-Salon",
      "reachable": true,
      "inGame": true
    },
    "network": {
      "kind": "wifi",
      "latencyMs": 4,
      "quality": "excellent"
    },
    "battery": {
      "percent": 82,
      "charging": false,
      "minutesLeft": 180
    },
    "session": {
      "active": true,
      "connectedSecondsAgo": 5077,
      "game": {
        "title": "Minecraft",
        "publisher": "Mojang Studios",
        "genre": "Bac à sable",
        "coverUrl": "assets/placeholder_cover_600x848.png"
      }
    },
    "download": {
      "active": false
    },
    "lastGame": null
  },
  "gameDownload": {
    "host": {
      "name": "PC-Salon",
      "reachable": true,
      "inGame": true
    },
    "network": {
      "kind": "wifi",
      "latencyMs": 4,
      "quality": "excellent"
    },
    "battery": {
      "percent": 82,
      "charging": false,
      "minutesLeft": 180
    },
    "session": {
      "active": true,
      "connectedSecondsAgo": 5077,
      "game": {
        "title": "Minecraft",
        "publisher": "Mojang Studios",
        "genre": "Bac à sable",
        "coverUrl": "assets/placeholder_cover_600x848.png"
      }
    },
    "download": {
      "active": true,
      "kind": "update",
      "title": "[Autre jeu]",
      "progress": 0.68,
      "bytesPerSec": 1200000000,
      "etaSeconds": 240,
      "simulateProgressPerSecond": 0.0015
    },
    "lastGame": null
  },
  "download": {
    "host": {
      "name": "PC-Salon",
      "reachable": true,
      "inGame": false
    },
    "network": {
      "kind": "wifi",
      "latencyMs": 4,
      "quality": "excellent"
    },
    "battery": {
      "percent": 82,
      "charging": false,
      "minutesLeft": 180
    },
    "session": {
      "active": false
    },
    "download": {
      "active": true,
      "kind": "update",
      "progress": 0.42,
      "bytesPerSec": 1200000000,
      "etaSeconds": 360,
      "simulateProgressPerSecond": 0.0015,
      "game": {
        "title": "Minecraft",
        "publisher": "Mojang Studios",
        "genre": "Bac à sable",
        "coverUrl": "assets/placeholder_cover_600x848.png"
      }
    },
    "lastGame": null
  },
  "rest": {
    "host": {
      "name": "PC-Salon",
      "reachable": true,
      "inGame": false
    },
    "network": {
      "kind": "wifi",
      "latencyMs": 4,
      "quality": "excellent"
    },
    "battery": {
      "percent": 82,
      "charging": false,
      "minutesLeft": 180
    },
    "session": {
      "active": false
    },
    "download": {
      "active": false
    },
    "lastGame": {
      "title": "Minecraft",
      "coverUrl": "assets/placeholder_cover_600x848.png",
      "lastPlayedSecondsAgo": 7200
    }
  },
  "latencyJitterSequenceMs": [
    4,
    4,
    5,
    3,
    4,
    6,
    4,
    5
  ],
  "latencyJitterPeriodMs": 2000
}
