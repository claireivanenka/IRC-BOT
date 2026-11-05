# CreamRoad - Intégration avec IRC-BOT

Ce guide explique comment intégrer le dossier **CremRoad - Sep 2026** avec le bot IRC, en stockant les fichiers dans PostgreSQL et en les rendant accessibles via nginx.

## 📁 Structure du dossier CreamRoad

```
CremRoad - Sep 2026/
├── audio/           # Fichiers audio (FLAC, MP3, etc.)
├── covers/          # Pochettes d'album
├── video/           # Fichiers vidéo
├── metadata/        # Métadonnées (JSON, etc.)
│   ├── covers.txt   # Liste des pochettes
│   └── json-clewn-audio.php.json  # Métadonnées des fichiers audio
├── songbook/        # Livret des chansons
├── index.html       # Page d'accueil
└── README.txt       # Documentation
```

## 🚀 Installation rapide

### 1. Prérequis

```bash
# Installer les dépendances
sudo apt update
sudo apt install postgresql postgresql-contrib ffmpeg nginx luarocks

# Installer les modules Lua
luarocks install luasql-postgres
luarocks install lua-json
```

### 2. Configurer PostgreSQL

```bash
# Créer l'utilisateur et la base de données (si ce n'est pas déjà fait)
sudo -u postgres psql -c "CREATE USER irc_user WITH PASSWORD 'irc_password';"
sudo -u postgres psql -c "CREATE DATABASE irc_bot;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE irc_bot TO irc_user;"

# Importer le schéma CreamRoad
sudo -u postgres psql -d irc_bot -f sql/creamroad_schema.sql

# Accorder les permissions
sudo -u postgres psql -d irc_bot -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO irc_user;"
sudo -u postgres psql -d irc_bot -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO irc_user;"
```

### 3. Configurer nginx

#### Option 1: Site dédié (recommandé)

```bash
# Copier la configuration
sudo cp deploy/nginx_creamroad.conf /etc/nginx/sites-available/creamroad

# Créer le lien symbolique
sudo ln -s /etc/nginx/sites-available/creamroad /etc/nginx/sites-enabled/

# Tester et redémarrer nginx
sudo nginx -t
sudo systemctl restart nginx
```

#### Option 2: Intégration avec le site existant

Ajoutez cette configuration à votre fichier nginx existant :

```nginx
location /creamroad/ {
    alias /home/claire/IRC-BOT/CremRoad - Sep 2026/;
    
    location /creamroad/audio/ {
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=31536000, immutable";
        add_header 'Access-Control-Allow-Origin' '*';
    }
    
    location /creamroad/covers/ {
        expires 30d;
        add_header Cache-Control "public, max-age=31536000, immutable";
        add_header 'Access-Control-Allow-Origin' '*';
    }
    
    location /creamroad/video/ {
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=31536000, immutable";
        add_header 'Access-Control-Allow-Origin' '*';
    }
}
```

Puis :
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### 4. Importer les fichiers dans PostgreSQL

```bash
# Utiliser la cible Make
make import-creamroad

# Ou exécuter le script manuellement
lua scripts/import_creamroad.lua
```

### 5. Créer un lien symbolique pour nginx (si nécessaire)

```bash
# Si nginx utilise /var/www/html
sudo mkdir -p /var/www/html/creamroad
sudo ln -sf /home/claire/IRC-BOT/CremRoad - Sep 2026 /var/www/html/creamroad
```

## 📊 Structure de la base de données

### Table principale: `creamroad_files`

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | SERIAL | Identifiant unique |
| `filename` | VARCHAR(512) | Nom du fichier |
| `artist` | VARCHAR(255) | Artiste |
| `album` | VARCHAR(255) | Album |
| `title` | VARCHAR(255) | Titre de la piste |
| `comment` | TEXT | Commentaires |
| `year` | INTEGER | Année de sortie |
| `track` | INTEGER | Numéro de piste |
| `file_type` | VARCHAR(50) | Type: audio, video, cover, other |
| `file_path` | VARCHAR(512) | Chemin relatif dans CreamRoad |
| `file_size` | BIGINT | Taille en octets |
| `hash` | CHAR(64) | Hash SHA-256 du fichier |
| `duration` | INTEGER | Durée en secondes (audio/vidéo) |
| `resolution` | VARCHAR(50) | Résolution (vidéo) |
| `format` | VARCHAR(50) | Format du fichier (mp3, flac, etc.) |
| `license` | VARCHAR(255) | License (CC-BY-NC-SA, etc.) |
| `added_at` | TIMESTAMP | Date d'ajout |
| `updated_at` | TIMESTAMP | Date de mise à jour |

### Table des statistiques: `creamroad_stats`

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | SERIAL | Identifiant unique |
| `stat_name` | VARCHAR(100) | Nom de la statistique |
| `stat_value` | TEXT | Valeur de la statistique |
| `updated_at` | TIMESTAMP | Date de mise à jour |

Statistiques disponibles :
- `total_files`: Nombre total de fichiers
- `total_audio`: Nombre de fichiers audio
- `total_video`: Nombre de fichiers vidéo
- `total_covers`: Nombre de covers
- `last_updated`: Date de dernière mise à jour

### Table des tags: `creamroad_tags`

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | SERIAL | Identifiant unique |
| `file_id` | INTEGER | Référence à creamroad_files |
| `tag` | VARCHAR(100) | Tag ou catégorie |

### Tables des playlists

- `creamroad_playlists`: Liste des playlists
- `creamroad_playlist_items`: Éléments des playlists avec position

## 🎯 Utilisation du script d'import

### Script: `scripts/import_creamroad.lua`

Le script effectue les opérations suivantes :

1. **Charge les métadonnées** depuis `metadata/json-clewn-audio.php.json`
2. **Scanne les répertoires** `audio/`, `video/`, `covers/`
3. **Extrait les informations** pour chaque fichier :
   - Nom du fichier
   - Type (audio, video, cover)
   - Taille du fichier
   - Hash SHA-256
   - Métadonnées (artiste, album, titre, etc.)
   - License
4. **Insère dans PostgreSQL** avec gestion des conflits (mise à jour si le fichier existe déjà)
5. **Met à jour les statistiques** globales

### Personnalisation du script

Éditez `scripts/import_creamroad.lua` pour modifier :

```lua
local config = {
    creamroad_dir = "CremRoad - Sep 2026",
    metadata_dir = "metadata",
    audio_dir = "audio",
    covers_dir = "covers",
    video_dir = "video",
    base_url = "/creamroad",
    
    postgres = {
        host = "localhost",
        port = 5432,
        database = "irc_bot",
        user = "irc_user",
        password = "irc_password"
    }
}
```

### Exécution du script

```bash
# Exécution normale
lua scripts/import_creamroad.lua

# Avec logging détaillé
LUA_DEBUG=1 lua scripts/import_creamroad.lua

# Vérifier la connexion PostgreSQL d'abord
psql -U irc_user -d irc_bot -c "SELECT count(*) FROM creamroad_files;"
```

## 🎵 Commandes IRC pour CreamRoad

Vous pouvez étendre le bot IRC pour ajouter des commandes spécifiques à CreamRoad. Voici un exemple :

### Commandes possibles à ajouter dans `irc_bot.lua`

```lua
-- Rechercher dans CreamRoad
if message:match("^!creamroad search") then
    local query = message:match("^!creamroad search (.+)")
    -- Requête PostgreSQL pour rechercher
    local result = db_conn:execute(string.format(
        "SELECT id, artist, album, title FROM creamroad_files WHERE artist ILIKE '%%%s%%' OR album ILIKE '%%%s%%' OR title ILIKE '%%%s%%' LIMIT 10",
        query, query, query
    ))
    -- Formater et envoyer les résultats
end

-- Obtenir des statistiques
if message:match("^!creamroad stats") then
    local result = db_conn:execute("SELECT stat_name, stat_value FROM creamroad_stats")
    local stats = {}
    local row = result:fetch({}, "a")
    while row do
        stats[row.stat_name] = row.stat_value
        row = result:fetch(row, "a")
    end
    send_irc_message(target, string.format("📊 CreamRoad Stats: %s fichiers audio, %s fichiers video, %s covers",
        stats.total_audio or 0, stats.total_video or 0, stats.total_covers or 0))
end

-- Jouer un fichier (génère un lien de streaming)
if message:match("^!creamroad play") then
    local id = message:match("^!creamroad play (%d+)")
    local result = db_conn:execute(string.format(
        "SELECT file_path, artist, title FROM creamroad_files WHERE id = %d", id
    ))
    local row = result:fetch({}, "a")
    if row then
        send_irc_message(target, string.format("🎵 Lecture: %s - %s | http://votre-domaine.com/creamroad/%s", 
            row.artist, row.title, row.file_path))
    end
end
```

## 🔍 Requêtes PostgreSQL utiles

### Compter les fichiers par type
```sql
SELECT file_type, COUNT(*) as count 
FROM creamroad_files 
GROUP BY file_type 
ORDER BY count DESC;
```

### Trouver les albums les plus représentés
```sql
SELECT album, COUNT(*) as count 
FROM creamroad_files 
WHERE album IS NOT NULL 
GROUP BY album 
ORDER BY count DESC 
LIMIT 10;
```

### Trouver les artistes les plus représentés
```sql
SELECT artist, COUNT(*) as count 
FROM creamroad_files 
WHERE artist IS NOT NULL 
GROUP BY artist 
ORDER BY count DESC 
LIMIT 10;
```

### Rechercher par année
```sql
SELECT year, COUNT(*) as count 
FROM creamroad_files 
WHERE year > 0 
GROUP BY year 
ORDER BY year DESC;
```

### Obtenir les fichiers récemment ajoutés
```sql
SELECT id, artist, album, title, file_path 
FROM creamroad_files 
ORDER BY added_at DESC 
LIMIT 20;
```

## 🎨 Accès via nginx

Une fois configuré, les fichiers CreamRoad seront accessibles à :

- **URL de base:** `http://votre-domaine.com/creamroad/` ou `http://localhost/creamroad/`
- **Audio:** `http://votre-domaine.com/creamroad/audio/nom-du-fichier.flac`
- **Covers:** `http://votre-domaine.com/creamroad/covers/nom-de-la-cover.jpg`
- **Vidéo:** `http://votre-domaine.com/creamroad/video/nom-de-la-video.mp4`

### Fonctionnalités nginx activées:

✅ **Streaming audio/vidéo** avec support seeking (reprise)
✅ **Cache optimisé** pour les fichiers statiques (30 jours)
✅ **CORS activé** pour l'accès cross-domain
✅ **Accept-Ranges** pour la lecture partielle
✅ **Compression GZIP** pour les fichiers texte
✅ **Protection** contre l'accès direct aux fichiers sensibles

## 🛠️ Dépannage

### Problème: nginx retourne 403 Forbidden

**Solution:**
```bash
# Vérifier les permissions
sudo chown -R www-data:www-data /home/claire/IRC-BOT/CremRoad - Sep 2026
sudo chmod -R 755 /home/claire/IRC-BOT/CremRoad - Sep 2026

# Vérifier la configuration nginx
sudo nginx -t

# Vérifier les logs nginx
sudo tail -n 50 /var/log/nginx/error.log
```

### Problème: PostgreSQL refuse la connexion

**Solution:**
```bash
# Vérifier que PostgreSQL est en cours d'exécution
sudo systemctl status postgresql

# Vérifier les identifiants
psql -U irc_user -d irc_bot -c "SELECT 1;"

# Vérifier les permissions
sudo -u postgres psql -d irc_bot -c "\dn+"
```

### Problème: Le script d'import ne trouve pas les fichiers

**Solution:**
```bash
# Vérifier que le dossier existe
ls -la "CremRoad - Sep 2026/"

# Vérifier les sous-dossiers
ls -la "CremRoad - Sep 2026/audio/" | head -5
ls -la "CremRoad - Sep 2026/metadata/" | head -5

# Exécuter le script avec le chemin absolu
cd /home/claire/IRC-BOT
CREAMROAD_DIR=/home/claire/IRC-BOT/CremRoad - Sep 2026 lua scripts/import_creamroad.lua
```

### Problème: Les métadonnées ne sont pas importées

**Solution:**
```bash
# Vérifier que le fichier JSON existe
ls -la "CremRoad - Sep 2026/metadata/json-clewn-audio.php.json"

# Vérifier le format du JSON
head -20 "CremRoad - Sep 2026/metadata/json-clewn-audio.php.json"

# Essayer de parser manuellement
python3 -m json.tool "CremRoad - Sep 2026/metadata/json-clewn-audio.php.json" | head -20
```

## 📈 Exemples d'utilisation

### 1. Importer et accéder aux fichiers

```bash
# Importer les fichiers
make import-creamroad

# Vérifier dans PostgreSQL
psql -U irc_user -d irc_bot -c "SELECT count(*) FROM creamroad_files;"

# Accéder via nginx
curl http://localhost/creamroad/audio/MeInTheBath-IntroducingSnakesInIreland-06-Chicken.flac
```

### 2. Créer une playlist

```sql
-- Créer une playlist
INSERT INTO creamroad_playlists (name, description) 
VALUES ('Me In The Bath', 'Les meilleurs titres de Me In The Bath')
RETURNING id;

-- Ajouter des fichiers à la playlist (remplacez ID_PLAYLIST et ID_FILE)
INSERT INTO creamroad_playlist_items (playlist_id, file_id, position) 
VALUES (ID_PLAYLIST, ID_FILE, 1);
```

### 3. Ajouter des tags

```sql
-- Ajouter un tag à un fichier
INSERT INTO creamroad_tags (file_id, tag) 
VALUES (ID_FILE, 'rock');

-- Rechercher par tag
SELECT f.* FROM creamroad_files f 
JOIN creamroad_tags t ON f.id = t.file_id 
WHERE t.tag = 'rock' 
LIMIT 10;
```

## 🎯 Intégration avec le bot IRC

Pour une intégration complète, vous pouvez :

1. **Ajouter des commandes CreamRoad** dans `irc_bot.lua` (voir exemples ci-dessus)
2. **Créer un module dédié** `creamroad_manager.lua` sur le modèle de `music_manager.lua`
3. **Ajouter des commandes de recherche et de lecture**
4. **Générer des liens de streaming** pour les fichiers audio

## 📚 Fichiers créés/modifiés

- `sql/creamroad_schema.sql` - Schéma PostgreSQL pour CreamRoad
- `scripts/import_creamroad.lua` - Script d'import des fichiers
- `deploy/nginx_creamroad.conf` - Configuration nginx pour CreamRoad
- `Makefile` - Nouvelles cibles pour CreamRoad
- `docs/CREAMROAD.md` - Ce guide

## 🔗 Liens utiles

- [Documentation PostgreSQL](https://www.postgresql.org/docs/)
- [Documentation nginx](https://nginx.org/en/docs/)
- [LuaSQL PostgreSQL](https://github.com/leafo/luasql)

## 📝 License

Ce projet fait partie d'IRC-BOT et est sous licence GPL-3.0.

---

**Fin de la documentation CreamRoad**
