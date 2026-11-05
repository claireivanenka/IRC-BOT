# 📜 Changelog du Bot IRC

Toutes les modifications apportées au projet sont documentées dans ce fichier.

---

## 📌 Format des versions

Nous utilisons le [Semantic Versioning](https://semver.org/) :
- **MAJOR** : Changements incompatibles
- **MINOR** : Ajouts de fonctionnalités rétrocompatibles
- **PATCH** : Corrections de bugs rétrocompatibles

---

## 🎵 [1.3.0] - 2026-11-05

### ✅ Module Musique pleinement fonctionnel

#### Ajouté
- **Module musique complet** : Gestion de bibliothèque musicale avec PostgreSQL
- **Extraction des tags** : Lecture des métadonnées audio (ID3, Vorbis, FLAC, etc.) via ffprobe
- **Commandes IRC musique** :
  - `!music help` - Affiche l'aide complète du module
  - `!music add <fichier>` - Ajoute une piste avec extraction automatique des tags
  - `!music search <texte>` - Recherche dans la bibliothèque (titre, artiste, album, genre)
  - `!music info <id>` - Affiche toutes les informations d'une piste
  - `!music stats` - Statistiques (total pistes, total lectures, top 10)
  - `!music dl <id>` - Génère un lien de téléchargement
  - `!music play <id>` - Génère un lien de streaming
- **Base de données PostgreSQL** : Table `tracks` avec index pour recherche optimisée
- **Détection des doublons** : Utilisation du hash SHA-256 pour éviter les doublons
- **Player web** : Interface HTML5 pour écouter les pistes en streaming
- **API HTTP** : Endpoints REST pour interagir avec la bibliothèque

#### Corrigé
- **music_db.lua** : Correction des erreurs de syntaxe (appels `log_message` remplacés par `print`)
- **music_db.lua** : Correction des chaînes avec apostrophes mal échappées
- **music_db.lua** : Ajout du paramètre `config` optionnel à `music_db.init()`
- **music_db.lua** : Implémentation de `get_track_by_hash()`
- **music_manager.lua** : Correction du système de matching des commandes (tri par longueur décroissante)
- **music_manager.lua** : Utilisation correcte de `tags.file_exists()` et `tags.get_file_size()`
- **Intégration complète** dans irc_bot.lua avec affichage dans `!help`

#### Modifié
- **config.lua** : Activation du module musique par défaut (`enabled = true`)
- **config.lua** : Répertoire par défaut changé en `./music`

#### Documentation
- Documentation complète dans [docs/music.md](docs/music.md)
- Mise à jour du README.md avec les commandes musique
- Mise à jour de USAGE.md avec les nouvelles commandes

#### Fichiers ajoutés/modifiés
- `music_db.lua` - Module de gestion de la base de données musicale
- `music_manager.lua` - Gestionnaire des commandes musique
- `tags.lua` - Extraction des tags audio
- `sql/music_schema.sql` - Schéma de la base de données
- `deploy/nginx.conf` - Configuration nginx pour le streaming
- `deploy/player/index.html` - Player web
- `deploy/player/player.js` - Logique du player
- `deploy/music_api.lua` - API HTTP pour le module musique

---

## 🚀 [1.0.0] - 2024-11-02

### ✨ Première version stable

#### Ajouté
- **Fonctionnalité de nettoyage YouTube** : Suppression automatique des paramètres de tracking (`feature`, `utm_*`, `fbclid`, etc.)
- **Menu interactif** : Affiche une liste de boissons et nourritures avec prix
- **Tâche horaire** : Exécute `/exec -o date` chaque heure ronde (00:00, 01:00, etc.)
- **Commande d'aide** : `!help` affiche toutes les commandes disponibles

#### Commandes disponibles
| Commande | Description |
|----------|-------------|
| `!clean <url>` | Nettoie une URL YouTube |
| `!menu [boire\|manger]` | Affiche le menu (boissons, nourriture ou complet) |
| `!help` | Affiche l'aide |

#### Fichiers créés
- `irc_bot.lua` : Script principal du bot
- `config.lua` : Configuration par défaut
- `start_bot.sh` : Script de lancement
- `Makefile` : Automatisation (install, run, test)
- `test_functions.lua` : 44 tests unitaires
- `README.md` : Documentation générale

#### Dépendances
- Lua 5.4+
- lua-socket (paquet Debian : `lua-socket`)
- lua-sec (optionnel, pour SSL)

#### Serveurs IRC supportés
- Libera.Chat (recommandé)
- OFTC
- Freenode
- Undernet

---

## 🚀 [1.1.0] - 2024-11-03

### ✨ Menus personnalisés et sauvegarde PostgreSQL

#### Ajouté
- **Menus personnalisés** : Les utilisateurs peuvent créer des menus personnalisés avec `!addmenu <nom> <texte>`
- **Gestion complète des menus** : `!listmenus`, `!showmenu <nom>`, `!delmenu <nom>`
- **Horodatage automatique** : Chaque menu personnalisé est daté lors de sa création
- **Sauvegarde PostgreSQL** : Option de sauvegarde des menus dans une base PostgreSQL
- **Fallback automatique** : Si PostgreSQL n'est pas disponible, le bot utilise la sauvegarde par fichier
- **Documentation PostgreSQL** : Guide complet pour configurer et utiliser PostgreSQL

#### Commandes ajoutées
| Commande | Description |
|----------|-------------|
| `!addmenu <nom> <texte>` | Crée un nouveau menu personnalisé avec horodatage |
| `!listmenus` | Liste tous les menus personnalisés créés |
| `!showmenu <nom>` | Affiche un menu personnalisé spécifique |
| `!delmenu <nom>` | Supprime un menu personnalisé |

#### Configuration PostgreSQL
Nouvelle section dans `config.lua` :
```lua
database = {
    enabled = true,          -- Activer PostgreSQL
    host = "localhost",      -- Hôte PostgreSQL
    port = 5432,             -- Port PostgreSQL
    database = "irc_bot",    -- Nom de la base
    user = "irc_user",       -- Utilisateur
    password = "password",   -- Mot de passe
    menus_table = "custom_menus", -- Table pour les menus
}
```

#### Dépendances supplémentaires
- luasql-postgres (optionnel, pour PostgreSQL)
- PostgreSQL (optionnel, serveur de base de données)

#### Schéma de la base de données
Voir [docs/database_schema.sql](docs/database_schema.sql)

---

## 🚀 [1.2.0] - 2024-11-03

### ✨ Tri des menus personnalisés

#### Ajouté
- **Tri des menus par horodatage** : La commande `!listmenus` accepte maintenant des options de tri
- **Options de tri multiples** : Tri par date (du plus récent au plus ancien), par nom (alphabétique), ou par créateur
- **Affichage compact** : Les menus sont maintenant affichés sur une seule ligne avec séparateurs "|"

#### Commandes améliorées
| Commande | Description |
|----------|-------------|
| `!listmenus` | Liste les menus dans l'ordre d'insertion |
| `!listmenus date` | Liste les menus du plus récent au plus ancien |
| `!listmenus name` | Liste les menus par ordre alphabétique |
| `!listmenus creator` | Liste les menus par créateur (A-Z) |

#### Exemple d'utilisation
```irc
!listmenus date      # Affiche les menus les plus récents en premier
!listmenus name      # Affiche les menus dans l'ordre alphabétique
!listmenu creator    # Alias de !listmenus creator
```

---

## 🚀 [2.0.0] - 2026-11-04

### 🎵 Module Musique - Gestion complète de bibliothèque musicale

#### ⚡ Nouvelle fonctionnalité majeure
Le bot dispose maintenant d'un module musique complet avec gestion de bibliothèque, streaming et player web.

#### Ajouté
- **Schéma PostgreSQL** : Nouvelle table `tracks` pour stocker les pistes musicales
- **Module music_db.lua** : Fonctions CRUD pour gérer les pistes
- **Module tags.lua** : Lecture des métadonnées audio (ID3, Vorbis, FLAC)
  - Support natif du parsing binaire
  - Fallback sur ffprobe/exiftool
- **Commandes IRC musique** :
  - `!music add <chemin|URL>` : Ajoute une piste avec extraction automatique des tags
  - `!music search <requête>` : Recherche dans la bibliothèque
  - `!music info <id>` : Affiche les informations complètes d'une piste
  - `!music stats` : Affiche les statistiques de la bibliothèque
  - `!music dl <id>` : Génère un lien de téléchargement
  - `!music play <id>` : Envoie l'URL de streaming au channel

#### Player Web
- Interface web responsive en HTML5/CSS/JS
- Lecture en streaming avec support du seeking
- Recherche instantanée
- Filtrage (Tous, Récents, Populaires)
- Raccourcis clavier (Espace, ←, →, ↑, ↓)
- Contrôle du volume

#### Infrastructure
- **Configuration nginx** : Streaming via `/music/stream/<hash>`, téléchargement via `/music/dl/<hash>`
- **API HTTP** : Serveur Lua (`music_api.lua`) pour servir les données musicales
- **Configuration complète** : Voir `deploy/nginx.conf` et `docs/music.md`

#### Documentation
- Guide complet dans [docs/music.md](docs/music.md)
- Schéma de base de données dans [sql/music_schema.sql](sql/music_schema.sql)

#### Dépendances
- **luasql-postgres** : Connexion PostgreSQL
- **lua-json** ou **dkjson** : Encodage/décodage JSON
- **luasocket** : Serveur HTTP
- **luafilesystem** : Gestion des fichiers
- **ffmpeg** (ffprobe) : Lecture des tags audio
- **exiftool** (optionnel) : Support de plus de formats

#### Exemple d'utilisation
```irc
!music add /home/user/Musique/Queen/Bohemian_Rhapsody.mp3
!music search queen
!music info 1
!music play 1
!music stats
```

---

## 🚀 [1.4.0] - 2026-11-03

### 🌍 Nettoyage d'URLs avec GeoIP et DNS

#### Ajouté
- **Base de données des URLs nettoyées** : Table `cleaned_urls` avec IP et localisation GeoIP
- **Résolution DNS automatique** : Extraction de l'IP pour chaque URL nettoyée
- **Commandes améliorées** :
  - `!clean <url>` : Nettoie n'importe quelle URL (YouTube, Temu, etc.) et extrait l'IP
  - `!urls` : Affiche toutes les URLs nettoyées avec IP
  - `!lasturls` : Affiche les dernières URLs nettoyées
  - `!listurls` : Affiche toutes les URLs avec détails complets
- **Support multi-sites** : Nettoyage des URLs Temu, YouTube, et autres
- **Affichage compact** :Affichage sur une seule ligne pour les listes

#### Fonctionnalités GeoIP
- Détection automatique du pays à partir de l'IP
- Stockage de la localisation dans la base de données
- Affichage dans les listes d'URLs

#### Améliorations
- Algorithme de nettoyage amélioré (suppression complète des paramètres de tracking)
- Gestion des URLs longues (affichage tronqué dans les listes)
- Support des caractères spéciaux dans les URLs

---

## 🚀 [1.3.0] - 2026-11-03

### ⏰ Commandes temporelles et améliorations

#### Ajouté
- **Commande !date** : Affiche la date et l'heure actuelles
- **Exécution horaire automatique** : `/exec -o date` chaque heure ronde
- **Commande !clean améliorée** : Support de toutes les URLs (pas seulement YouTube)

#### Améliorations
- Détection automatique des heures rondes
- Gestion des erreurs pour les commandes invalides
- Affichage amélioré des messages système

---

## 🚀 [1.2.0] - 2026-11-03

### ✨ Tri des menus personnalisés

#### Ajouté
- **Tri des menus par horodatage** : La commande `!listmenus` accepte maintenant des options de tri
- **Options de tri multiples** : Tri par date (du plus récent au plus ancien), par nom (alphabétique), ou par créateur
- **Affichage compact** : Les menus sont maintenant affichés sur une seule ligne avec séparateurs "|"

#### Commandes améliorées
| Commande | Description |
|----------|-------------|
| `!listmenus` | Liste les menus dans l'ordre d'insertion |
| `!listmenus date` | Liste les menus du plus récent au plus ancien |
| `!listmenus name` | Liste les menus par ordre alphabétique |
| `!listmenus creator` | Liste les menus par créateur (A-Z) |

#### Exemple d'utilisation
```irc
!listmenus date      # Affiche les menus les plus récents en premier
!listmenus name      # Affiche les menus dans l'ordre alphabétique
!listmenu creator    # Alias de !listmenus creator
```

---

## 🔄 [Non sorti]

### À venir (Roadmap)

#### Fonctionnalités prévues
- **Système de plugins** : Charger des fonctionnalités dynamiquement
- **Base de données** : Stocker les préférences des utilisateurs (SQLite)
- **Interface Web** : Contrôler le bot via une interface web
- **Support multi-canaux** : Gérer plusieurs canaux simultanément
- **Commandes personnalisées** : Permettre aux utilisateurs de créer leurs propres commandes
- **Système de permissions** : Niveaux d'accès (admin, modérateur, utilisateur)
- **Statistiques** : Suivre l'utilisation du bot
- **Modération automatique** : Détection de spam, flood, etc.
- **Support de plus de services** : Nettoyage des URLs Twitter, Vimeo, etc.

#### Améliorations prévues
- Meilleure gestion des erreurs
- Interface de configuration plus intuitive
- Documentation plus complète
- Localisation (traduction en plusieurs langues)
- Support de IPv6

---

## 📝 Comment contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les règles de contribution.

---

## 🎯 Comparaison des versions

| Version | Date | Fonctionnalités | Statut |
|---------|------|------------------|--------|
| 1.3.0 | 2026-11-05 | Module Musique complet, Extraction tags, Player web, API HTTP | ✅ Stable |
| 1.2.0 | 2024-11-03 | Menus personnalisés, URL cleaning amélioré, DNS queries, PostgreSQL | ✅ Stable |
| 1.1.0 | 2024-11-02 | Logging, Géolocalisation IP, Améliorations divers | ✅ Stable |
| 1.0.0 | 2024-11-02 | Nettoyage YouTube, Menu, Date horaire | ✅ Stable |
| 0.1.0 | 2024-11-01 | Version initiale (non publiée) | ❌ Déprécié |

---

## 📚 Documentation des versions

Chaque version a sa propre documentation :
- **1.0.0** : Voir [README.md](README.md) et [docs/](docs/)

---

## 🔍 Historique des commits

Pour voir l'historique complet des commits :
```bash
git log --oneline --graph --all
```

Ou sur GitHub :
[https://github.com/claireivanenka/IRC-BOT/commits/main](https://github.com/claireivanenka/IRC-BOT/commits/main)

---

## 📧 Signaler un bug

Si tu trouves un bug, ouvre une **Issue** sur GitHub :
[https://github.com/claireivanenka/IRC-BOT/issues/new](https://github.com/claireivanenka/IRC-BOT/issues/new)

Inclus :
- La version du bot
- La version de Lua
- La version de lua-socket
- Le message d'erreur exact
- Les étapes pour reproduire

---

**Fin du Changelog**
