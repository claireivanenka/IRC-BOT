# Module Musique - IRC-BOT

Ce module ajoute une gestion complète de bibliothèque musicale au bot IRC, avec stockage PostgreSQL, lecture des tags audio, commandes IRC et player web.

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation](#installation)
3. [Configuration](#configuration)
   - [PostgreSQL](#postgresql)
   - [nginx](#nginx)
   - [Configuration Lua](#configuration-lua)
4. [Schéma de la base de données](#schéma-de-la-base-de-données)
5. [Commandes IRC](#commandes-irc)
6. [Player Web](#player-web)
7. [API HTTP](#api-http)
8. [Utilisation](#utilisation)
9. [Dépannage](#dépannage)
10. [Exemples](#exemples)

---

## Prérequis

### Système
- Lua 5.1 ou supérieur
- PostgreSQL 12 ou supérieur
- nginx (pour le streaming)
- Paquets Lua requis :
  - `luasql-postgres`
  - `lua-json` (ou `dkjson`)
  - `luasocket`
  - `luafilesystem`

### Pour la lecture des tags
- **ffprobe** (recommandé) - Fait partie de ffmpeg
- **exiftool** (optionnel) - Pour plus de formats

Installez les dépendances Lua avec :
```bash
luarocks install luasql-postgres
luarocks install lua-json  # ou dkjson
luarocks install luasocket
luarocks install luafilesystem
```

Installez les outils système :
```bash
# Sur Debian/Ubuntu
sudo apt-get install postgresql postgresql-contrib ffmpeg nginx
```

---

## Installation

### 1. Créer la base de données PostgreSQL

```bash
# Se connecter à PostgreSQL
sudo -u postgres psql

# Créer l'utilisateur et la base de données
CREATE USER irc_user WITH PASSWORD 'irc_password';
CREATE DATABASE irc_bot;
GRANT ALL PRIVILEGES ON DATABASE irc_bot TO irc_user;
\c irc_bot

# Exécuter le schéma
\i /home/claire/IRC-BOT/sql/music_schema.sql

# Accorder les permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO irc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO irc_user;

\q
```

### 2. Configurer PostgreSQL

Éditez `/etc/postgresql/12/main/pg_hba.conf` (ou la version appropriée) :

```
# Ajouter ou modifier pour permettre la connexion locale
local   irc_bot   irc_user                            md5
host    irc_bot   irc_user    127.0.0.1/32            md5
host    irc_bot   irc_user    ::1/128                 md5
```

Puis redémarrez PostgreSQL :
```bash
sudo systemctl restart postgresql
```

### 3. Créer le répertoire de musique

```bash
sudo mkdir -p /var/lib/irc_bot/music
sudo chown claire:claire /var/lib/irc_bot/music
chmod 755 /var/lib/irc_bot/music
```

### 4. Configurer nginx

Copiez la configuration nginx :
```bash
sudo cp /home/claire/IRC-BOT/deploy/nginx.conf /etc/nginx/sites-available/irc_bot_music
sudo ln -s /etc/nginx/sites-available/irc_bot_music /etc/nginx/sites-enabled/
```

Créez le répertoire pour les fichiers statiques :
```bash
sudo mkdir -p /var/www/irc_bot/music/player
sudo cp -r /home/claire/IRC-BOT/deploy/player/* /var/www/irc_bot/music/player/
```

Activez le site et redémarrez nginx :
```bash
sudo nginx -t  # Tester la configuration
sudo systemctl restart nginx
```

### 5. Configurer le bot IRC

Éditez `config_custom.lua` :
```lua
music = {
    enabled = true,
    music_dir = "/var/lib/irc_bot/music",
    base_url = "http://votre-domaine.tld/music",
    use_ffprobe = true,
    use_exiftool = false,
    max_file_size = 100 * 1024 * 1024,  -- 100 Mo
    allowed_extensions = {".mp3", ".flac", ".ogg", ".m4a", ".wav"}
}
```

---

## Configuration

### PostgreSQL

Le module utilise la même configuration que les autres modules PostgreSQL. Vérifiez que `config.lua` contient :

```lua
postgres = {
    host = "localhost",
    port = 5432,
    database = "irc_bot",
    user = "irc_user",
    password = "irc_password"
}
```

### nginx

La configuration nginx gère :
- Téléchargement direct des fichiers via `/music/dl/<hash>`
- Streaming via `/music/stream/<hash>`
- Player web sur `/music/player/`

Voir `deploy/nginx.conf` pour plus de détails.

### Configuration Lua

Les paramètres de configuration dans `config_custom.lua` :

| Paramètre | Type | Description | Défaut |
|-----------|------|-------------|--------|
| `enabled` | bool | Active/désactive le module musique | `false` |
| `music_dir` | string | Répertoire de stockage des fichiers | `./music` |
| `base_url` | string | URL de base pour le streaming | `http://localhost:8080/music` |
| `use_ffprobe` | bool | Utiliser ffprobe pour lire les tags | `true` |
| `use_exiftool` | bool | Utiliser exiftool comme fallback | `false` |
| `max_file_size` | number | Taille maximale des fichiers (bytes) | 100 Mo |
| `allowed_extensions` | table | Extensions autorisées | `{mp3, flac, ogg, m4a, wav}` |

---

## Schéma de la base de données

Le schéma est défini dans `sql/music_schema.sql` :

```sql
-- Table principale des pistes
CREATE TABLE tracks (
    id SERIAL PRIMARY KEY,
    titre VARCHAR(255) NOT NULL,
    artiste VARCHAR(255),
    album VARCHAR(255),
    annee INTEGER,
    genre VARCHAR(100),
    duree INTEGER NOT NULL DEFAULT 0,  -- en secondes
    chemin_fichier VARCHAR(512),
    url_streaming VARCHAR(512),
    hash_fichier CHAR(64) UNIQUE NOT NULL,  -- SHA-256
    ajoute_par VARCHAR(50),  -- Nick IRC
    date_ajout TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    nb_lectures INTEGER DEFAULT 0
);

-- Index pour la recherche
CREATE INDEX idx_tracks_titre ON tracks(titre);
CREATE INDEX idx_tracks_artiste ON tracks(artiste);
CREATE INDEX idx_tracks_album ON tracks(album);
CREATE INDEX idx_tracks_genre ON tracks(genre);
CREATE INDEX idx_tracks_ajoute_par ON tracks(ajoute_par);
CREATE INDEX idx_tracks_date_ajout ON tracks(date_ajout);
CREATE INDEX idx_tracks_nb_lectures ON tracks(nb_lectures);
```

---

## Commandes IRC

### `!music add <chemin|URL>`

Ajoute une piste à la bibliothèque. Le bot extrait automatiquement les tags ID3.

**Exemples :**
```
!music add /home/user/Musique/queen_bohemian.mp3
!music add https://example.com/music/track.mp3
```

**Réponse :**
```
✅ Piste ajoutée : Bohemian Rhapsody | Queen | A Night at the Opera | 1975 | Rock | 5:54 | 320 kbps
```

### `!music search <requête>`

Recherche des pistes par titre, artiste, album ou genre.

**Exemples :**
```
!music search queen
!music search rock
!music search night opera
```

**Réponse :**
```
🔍 Résultats (3/10) :
1. Bohemian Rhapsody - Queen [A Night at the Opera, 1975, Rock, 5:54]
2. We Will Rock You - Queen [News of the World, 1977, Rock, 3:01]
3. Another One Bites The Dust - Queen [The Game, 1980, Rock, 3:36]
```

### `!music info <id>`

Affiche toutes les informations sur une piste.

**Exemple :**
```
!music info 1
```

**Réponse :**
```
📀 ID: 1
🎵 Titre: Bohemian Rhapsody
🎤 Artiste: Queen
💿 Album: A Night at the Opera
📅 Année: 1975
🎭 Genre: Rock
⏱️ Durée: 5:54
📁 Fichier: /var/lib/irc_bot/music/abc123def456...mp3
🔊 Bitrate: 320 kbps
👤 Ajouté par: claire
📅 Date: 2026-11-04 10:00:00
🎧 Lectures: 42
🔗 Hash: abc123def456...
```

### `!music stats`

Affiche les statistiques de la bibliothèque.

**Réponse :**
```
📊 Statistiques de la bibliothèque :
📁 Total pistes: 156
🎧 Total lectures: 1568
🏆 Top 10 :
1. Bohemian Rhapsody - Queen (42 lectures)
2. Stairway to Heaven - Led Zeppelin (38 lectures)
3. Hotel California - Eagles (35 lectures)
4. Imagine - John Lennon (50 lectures)
5. Smells Like Teen Spirit - Nirvana (45 lectures)
```

### `!music dl <id>`

Génère un lien de téléchargement pour une piste.

**Exemple :**
```
!music dl 1
```

**Réponse :**
```
📥 Télécharger: https://music.domaine.tld/dl/abc123def456?file=Bohemian_Rhapsody.mp3
```

### `!music play <id>`

Joue une piste (envoie l'URL de streaming au channel).

**Exemple :**
```
!music play 1
```

**Réponse :**
```
🎵 Lecture: Bohemian Rhapsody - Queen (5:54) | https://music.domaine.tld/stream/abc123def456
```

---

## Player Web

Le player web est accessible à l'URL configurée dans `base_url` (par défaut : `http://localhost:8080/music/player/`).

### Fonctionnalités
- ✅ Lecture en streaming HTML5
- ✅ Recherche instantanée
- ✅ Filtrage par : Tous, Récents, Populaires
- ✅ Affichage des informations complètes
- ✅ Barre de progression avec seeking
- ✅ Contrôle du volume
- ✅ Navigation entre les pistes
- ✅ Responsive design
- ✅ Raccourcis clavier

### Raccourcis clavier
| Touche | Action |
|--------|--------|
| `Espace` | Lecture/Pause |
| `←` | Reculer de 5 secondes |
| `→` | Avancer de 5 secondes |
| `↑` | Augmenter le volume |
| `↓` | Diminuer le volume |

---

## API HTTP

Le serveur API (`deploy/music_api.lua`) expose les endpoints suivants :

### `GET /music/api/tracks`
Récupère toutes les pistes.

**Réponse :**
```json
[
    {
        "id": 1,
        "titre": "Bohemian Rhapsody",
        "artiste": "Queen",
        "album": "A Night at the Opera",
        "annee": 1975,
        "genre": "Rock",
        "duree": 354,
        "chemin_fichier": "/var/lib/irc_bot/music/abc123.mp3",
        "url_streaming": "https://music.domaine.tld/stream/abc123",
        "hash_fichier": "abc123def456...",
        "ajoute_par": "claire",
        "date_ajout": "2026-11-04T10:00:00Z",
        "nb_lectures": 42,
        "geoip": "FR",
        "ip_address": "1.2.3.4"
    }
]
```

### `GET /music/api/tracks?search=<query>`
Recherche des pistes.

**Exemple :**
```
GET /music/api/tracks?search=queen
```

### `POST /music/api/tracks/<id>/play`
Incrémente le compteur de lectures d'une piste.

### `GET /music/api/stats`
Récupère les statistiques.

**Réponse :**
```json
{
    "top_tracks": [
        {"id": 1, "titre": "Bohemian Rhapsody", "artiste": "Queen", "nb_lectures": 42}
    ],
    "total_tracks": 156,
    "total_plays": 1568
}
```

---

## Utilisation

### Ajouter de la musique

1. Placez vos fichiers audio dans le répertoire configuré (`music_dir`)
2. Utilisez la commande `!music add` pour ajouter chaque fichier

Le bot extrait automatiquement les métadonnées (tags ID3, Vorbis, etc.).

### Gérer la bibliothèque

- Utilisez `!music search` pour trouver des pistes
- Utilisez `!music info` pour voir les détails
- Utilisez `!music dl` pour générer des liens de téléchargement

### Streaming

Le player web permet d'écouter les pistes directement dans le navigateur.
Les pistes sont streamées via nginx avec support du seeking.

---

## Dépannage

### Erreur de connexion PostgreSQL

**Problème :** `Impossible de se connecter à PostgreSQL`

**Solutions :**
- Vérifiez que PostgreSQL est en cours d'exécution : `sudo systemctl status postgresql`
- Vérifiez les identifiants dans `config.lua` ou `config_custom.lua`
- Testez la connexion manuellement : `psql -U irc_user -d irc_bot`
- Vérifiez les permissions : `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO irc_user;`

### Erreur de lecture des tags

**Problème :** Les tags ne sont pas extraits correctement

**Solutions :**
- Installez ffprobe : `sudo apt-get install ffmpeg`
- Activez `use_ffprobe` dans la configuration
- Essayez avec exiftool : `sudo apt-get install libimage-exiftool-perl`

### Erreur de streaming

**Problème :** Le streaming ne fonctionne pas

**Solutions :**
- Vérifiez la configuration nginx : `sudo nginx -t`
- Vérifiez que les fichiers existent dans `music_dir`
- Vérifiez les permissions : `chmod 755 /var/lib/irc_bot/music`
- Vérifiez que nginx a accès aux fichiers

### Player web vide

**Problème :** Le player web ne charge aucune piste

**Solutions :**
- Vérifiez que `music_api.lua` est en cours d'exécution
- Vérifiez l'URL dans la configuration du player
- Ouvrez la console du navigateur (F12) pour voir les erreurs
- Testez l'API directement : `curl http://localhost:8080/music/api/tracks`

---

## Exemples

### Ajouter plusieurs pistes
```
!music add /home/user/Musique/Queen/Bohemian_Rhapsody.mp3
!music add /home/user/Musique/Eagles/Hotel_California.mp3
!music add /home/user/Musique/Led_Zeppelin/Stairway_to_Heaven.flac
```

### Rechercher et jouer
```
!music search rock
!music play 2
```

### Voir les statistiques
```
!music stats
```

### Télécharger une piste
```
!music dl 1
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client IRC (titoune)                      │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     irc_bot.lua                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐    │
│  │ music_db.lua │  │  tags.lua   │  │  Commandes IRC       │    │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬───────────┘    │
└─────────┼─────────────────┼────────────────────┼────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────────┐
│  PostgreSQL     │ │  ffprobe    │ │  Fichiers audio     │
│  (irc_bot DB)   │ │  (tags)     │ │  (music_dir)        │
└─────────────────┘ └─────────────┘ └─────────────────────┘
          │
          ▼
┌─────────────────┐
│  music_api.lua   │──── HTTP API ────┐
└─────────────────┘                  │
                                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     Player Web                               │
│  ┌─────────────────────┐  ┌───────────────────────────────┐ │
│  │    index.html       │  │        player.js              │ │
│  └─────────────────────┘  └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────┐
│    nginx         │──── Streaming ────▶ Client
└─────────────────┘
```

---

## Migration

Pour migrer depuis une version précédente :

1. Exécutez le nouveau schéma :
   ```bash
   psql -U irc_user -d irc_bot -f /home/claire/IRC-BOT/sql/music_schema.sql
   ```

2. Redémarrez le bot IRC

3. Redémarrez le serveur API si nécessaire

---

## License

Ce module fait partie de IRC-BOT et est sous licence GPL-3.0.

## Auteurs

- claireivanenka - Développeur principal
- titoune - Bot IRC

---

## Historique des versions

- **v1.0.0** - Version initiale avec gestion de base des pistes
- **v1.1.0** - Ajout du player web et streaming
- **v1.2.0** - Ajout de l'API HTTP et amélioration des commandes IRC
