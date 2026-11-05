-- =====================================================================
-- CreamRoad Manager - Gestion des fichiers multimédias CreamRoad
-- =====================================================================

local M = {}
local config = nil
local db = nil
local enabled = false
local log_callback = nil

-- Fonction pour définir un callback de logging (appelé depuis irc_bot.lua)
function M.set_log_callback(callback)
    log_callback = callback
end

-- Fonction de logging interne
local function log_message(level, message)
    if log_callback then
        -- log_callback dans irc_bot.lua attend: log_message(level, source, message)
        log_callback(level, "CREAMROAD", message)
    end
end

-- =====================================================================
-- Initialisation
-- =====================================================================

function M.init(user_config)
    config = user_config
    
    -- Vérifier si creamroad existe dans la config, sinon utiliser des valeurs par défaut
    if not config.creamroad then
        config.creamroad = {
            enabled = false,
            root_path = "/home/claire/IRC-BOT/CreamRoad",
            base_path = "/home/claire/IRC-BOT/CreamRoad - Sep 2026",
            scan_depth = 3,
            auto_index = true,
            db_table = "creamroad_files",
            web_url = "http://localhost/creamroad",
            nginx = {
                server_name = "localhost",
                port = 80,
                root = "/home/claire/IRC-BOT/CreamRoad",
            },
            tables = {
                files = "creamroad_files",
                stats = "creamroad_stats",
                tags = "creamroad_tags",
                playlists = "creamroad_playlists",
            }
        }
    end
    
    if not config.creamroad.enabled then
        print("⚠️  Module CreamRoad désactivé")
        enabled = false
        return false
    end
    
    -- Vérifier que PostgreSQL est activé
    if not config.database or not config.database.enabled then
        print("⚠️  CreamRoad nécessite PostgreSQL activé")
        enabled = false
        return false
    end
    
    -- Charger le module database
    local db_module = require("database")
    if not db_module then
        print("⚠️  Impossible de charger le module database")
        enabled = false
        return false
    end
    
    -- Initialiser la connexion à la base de données
    db = db_module.connect(config.database)
    if not db then
        print("⚠️  Impossible de se connecter à PostgreSQL pour CreamRoad")
        enabled = false
        return false
    end
    
    -- Vérifier que les tables existent
    if not M.check_tables() then
        print("⚠️  Tables CreamRoad non trouvées")
        enabled = false
        return false
    end
    
    enabled = true
    log_message("INFO", "Module CreamRoad activé avec succès")
    print("✓ Module CreamRoad activé")
    return true
end

-- =====================================================================
-- Vérification des tables
-- =====================================================================

function M.check_tables()
    if not db then return false end
    
    local tables = {
        "creamroad_files",
        "creamroad_stats", 
        "creamroad_tags",
        "creamroad_playlists"
    }
    
    for _, table_name in ipairs(tables) do
        local query = string.format("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '%s')", db:escape(table_name))
        local result = db:execute(query)
        if not result or not result[1] or not (result[1].exists or result[1][1]) then
            print(string.format("⚠️  Table %s non trouvée", table_name))
            return false
        end
    end
    
    return true
end

-- =====================================================================
-- Indexation des fichiers
-- =====================================================================

-- Fonction pour extraire les métadonnées d'un fichier audio
function M.extract_metadata(filepath)
    local metadata = {
        title = "",
        artist = "",
        album = "",
        genre = "",
        year = nil,
        track_number = nil,
        duration = 0,
        bitrate = 0,
        file_type = filepath:match("%.([^%.]+)$") or "unknown"
    }
    
    -- Pour l'instant, on extrait juste le nom du fichier
    -- Une implémentation complète utiliserait ffprobe ou un parser ID3
    local filename = filepath:match("([^/]+)$") or filepath
    
    -- Extraire le chemin relatif à base_path
    local base_path = config.creamroad.base_path
    local relative_path = filepath
    if filepath:sub(1, #base_path + 1) == base_path .. "/" then
        relative_path = filepath:sub(#base_path + 2)
    elseif filepath:sub(1, #base_path) == base_path then
        relative_path = filepath:sub(#base_path + 1)
    end
    
    -- Parser le chemin relatif pour obtenir les dossiers
    -- Format: audio/Artist/Album/01-Title.flac OU audio/Artist - Title.flac
    local path_dirs = {}
    for part in relative_path:gmatch("([^/]+)/") do
        table.insert(path_dirs, part)
    end
    
    -- Extraire artiste et album des dossiers
    -- Les fichiers sont dans audio/, donc on ignore le premier dossier
    -- Format: audio/Artist/Album/
    if #path_dirs > 1 then
        -- path_dirs[1] = "audio", path_dirs[2] = Artist, path_dirs[3] = Album (si présent)
        metadata.artist = path_dirs[2] or metadata.artist
        metadata.album = path_dirs[3] or metadata.album
    end
    
    -- Essayer de parser le nom de fichier si artiste/album pas trouvés
    -- Format: Artist-Album-01-Title.flac ou Artist - Title.flac ou 01-Title.flac
    if not metadata.artist or metadata.artist == "" then
        -- Essayer de trouver le premier " - " (espace-tiret-espace)
        local dash_pos = filename:find(" - ")
        if dash_pos then
            metadata.artist = filename:sub(1, dash_pos - 1)
            local rest = filename:sub(dash_pos + 3)
            metadata.title = rest:match("(.-)%.%w+$") or rest
        else
            -- Sinon, prendre la première partie avant le premier tiret
            local first_dash = filename:find("-")
            if first_dash then
                metadata.artist = filename:sub(1, first_dash - 1)
                local rest = filename:sub(first_dash + 1)
                -- Le titre est tout après le premier tiret
                metadata.title = rest:match("(.-)%.%w+$") or rest
            else
                metadata.title = filename:match("(.-)%.%w+$") or filename
            end
        end
    end
    
    if not metadata.title or metadata.title == "" then
        metadata.title = filename:match("(.-)%.%w+$") or filename
    end
    
    -- Nettoyer les noms (enlever les numéros de début comme 01-, 02-, etc.)
    metadata.artist = metadata.artist:gsub("^[0-9]+-%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")
    metadata.album = metadata.album:gsub("^[0-9]+-%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")
    metadata.title = metadata.title:gsub("^[0-9]+-%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")
    
    return metadata
end

-- Fonction pour calculer la durée (simplifiée - à améliorer avec ffprobe)
function M.get_duration(filepath)
    -- Pour l'instant, on retourne une durée par défaut
    -- Une implémentation complète utiliserait ffprobe
    return 0
end

-- Fonction pour indexer un fichier
function M.index_file(filepath, added_by)
    if not db then return false, "Base de données non connectée" end
    if not enabled then return false, "Module CreamRoad non activé" end
    
    local filename = filepath:match("([^/]+)$") or filepath
    local relative_path = filepath:gsub(config.creamroad.base_path .. "/", "")
    
    -- Vérifier si le fichier existe déjà
    local existing = M.get_file_by_name(filename)
    if existing then
        return false, "Fichier déjà indexé"
    end
    
    -- Extraire les métadonnées
    local metadata = M.extract_metadata(filepath)
    
    -- Obtenir la taille du fichier (en bytes)
    local file_size = 0
    local f = io.open(filepath, "rb")
    if f then
        file_size = f:seek("end")
        f:close()
    end
    
    -- Calculer le hash
    local hash = M.calculate_hash(filepath)
    
    -- Insérer dans la base de données (utiliser les colonnes existantes)
    local query = string.format(
        "INSERT INTO creamroad_files (file_path, filename, file_size, file_type, title, artist, album, comment, year, track, duration, resolution, format, license, hash) " ..
        "VALUES ('%s', '%s', %d, '%s', '%s', '%s', '%s', '%s', %s, %s, %d, '%s', '%s', '%s', '%s') RETURNING id",
        db:escape(filepath),
        db:escape(filename),
        file_size or 0,
        db:escape(metadata.file_type),
        db:escape(metadata.title),
        db:escape(metadata.artist),
        db:escape(metadata.album),
        db:escape(metadata.genre or ""),  -- comment = genre
        metadata.year or "NULL",
        metadata.track_number or "NULL",
        metadata.duration or 0,
        db:escape("unknown"),  -- resolution
        db:escape("unknown"),  -- format
        db:escape(added_by or "system")  -- license = added_by
    )
    
    local result = db:execute(query)
    
    if result and result[1] and result[1].id then
        return true, result[1].id
    end
    
    return false, "Erreur lors de l'insertion"
end

-- Fonction pour calculer un hash simple (à remplacer par SHA-256 si disponible)
function M.calculate_hash(filepath)
    -- Simple hash based on path and modification time
    local mtime = 0
    local f = io.open(filepath, "rb")
    if f then
        local stat = f:seek("end")
        f:close()
        -- Nous ne pouvons pas obtenir mtime facilement en pur Lua, donc on utilise le chemin
        mtime = stat
    end
    return string.format("%s_%d", filepath:gsub("[^%w]", "_"):lower(), mtime)
end

-- Fonction pour indexer récursivement un dossier
function M.index_directory(base_path, added_by)
    if not db then return false, "Base de données non connectée" end
    if not enabled then return false, "Module CreamRoad non activé" end
    
    local base_path = base_path or config.creamroad.base_path
    local added_by = added_by or "system"
    local count = 0
    local errors = {}
    
    log_message("INFO", string.format("Début de l'indexation du dossier: %s", base_path))
    print(string.format("📁 Indexation du dossier: %s", base_path))
    
    -- Vérifier que le dossier existe
    local extensions = {"mp3", "flac", "ogg", "m4a", "wav"}
    local files = {}
    
    for _, ext in ipairs(extensions) do
        local handle = io.popen(string.format("find '%s' -type f -iname '*.%s' 2>/dev/null", base_path, ext))
        if handle then
            for filepath in handle:lines() do
                table.insert(files, filepath)
            end
            handle:close()
        end
    end
    
    -- Trier les fichiers pour un ordre déterministe
    table.sort(files)
    
    for _, filepath in ipairs(files) do
        local success, result = M.index_file(filepath, added_by)
        if success then
            count = count + 1
            print(string.format("  ✅ %s", filepath))
        else
            table.insert(errors, {file = filepath, error = result})
            log_message("ERROR", string.format("Erreur indexation: %s - %s", filepath, result))
            print(string.format("  ❌ %s: %s", filepath, result))
        end
    end
    
    log_message("INFO", string.format("Indexation terminée: %d fichiers indexés, %d erreurs", count, #errors))
    print(string.format("✅ Indexation terminée: %d fichiers indexés, %d erreurs", count, #errors))
    
    return true, count
end

-- =====================================================================
-- Fonctions de recherche
-- =====================================================================

function M.search_files(search_term, limit, offset)
    if not db then 
        log_message("ERROR", "Recherche CreamRoad: Base de données non connectée")
        return nil, "Base de données non connectée" 
    end
    
    log_message("INFO", string.format("Recherche CreamRoad: terme='%s', limit=%d, offset=%d", search_term, limit or 0, offset or 0))
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or ""
    local offset_clause = offset and offset > 0 and "OFFSET " .. offset or ""
    
    local query = string.format(
        "SELECT id, filename, file_type, file_size, duration, bitrate, sample_rate, channels, " ..
        "path, added_by, added_date, last_played, play_count " ..
        "FROM creamroad_files WHERE filename ILIKE '%%" .. db:escape(search_term) .. "%%' " ..
        "OR path ILIKE '%%" .. db:escape(search_term) .. "%%' " ..
        "ORDER BY filename " .. limit_clause .. " " .. offset_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_file_by_id(file_id)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE id = %d",
        tonumber(file_id)
    )
    
    local result = db:execute(query)
    return result and result[1] or nil, nil
end

function M.get_file_by_name(filename)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE filename = '%s'",
        db:escape(filename)
    )
    
    local result = db:execute(query)
    return result and result[1] or nil, nil
end

function M.get_random_files(count)
    if not db then 
        log_message("ERROR", "get_random_files: Base de données non connectée")
        return nil, "Base de données non connectée" 
    end
    
    log_message("INFO", string.format("Récupération de %d fichiers aléatoires CreamRoad", count or 10))
    local query = string.format(
        "SELECT * FROM creamroad_files ORDER BY RANDOM() LIMIT %d",
        count or 10
    )
    
    local result = db:execute(query)
    log_message("INFO", string.format("get_random_files: %d fichiers retournés", result and #result or 0))
    return result, nil
end

function M.get_files_by_type(file_type, limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 50"
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE file_type = '%s' ORDER BY filename " .. limit_clause,
        db:escape(file_type)
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_files_by_tag(tag_name, limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 50"
    
    local query = string.format(
        "SELECT f.* FROM creamroad_files f " ..
        "JOIN creamroad_tags t ON f.id = t.file_id " ..
        "JOIN creamroad_tag_names tn ON t.tag_id = tn.id " ..
        "WHERE tn.name = '%s' ORDER BY f.filename " .. limit_clause,
        db:escape(tag_name)
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_files_by_artist(artist_name, limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 50"
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE artist ILIKE '%%" .. db:escape(artist_name) .. "%%' " ..
        "ORDER BY filename " .. limit_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_files_by_album(album_name, limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 50"
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE album ILIKE '%%" .. db:escape(album_name) .. "%%' " ..
        "ORDER BY track_number, filename " .. limit_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

-- =====================================================================
-- Statistiques
-- =====================================================================

function M.get_most_played(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = string.format(
        "SELECT * FROM creamroad_files ORDER BY play_count DESC, last_played DESC " .. limit_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_recently_played(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = string.format(
        "SELECT * FROM creamroad_files WHERE last_played IS NOT NULL ORDER BY last_played DESC " .. limit_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_recently_added(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = string.format(
        "SELECT * FROM creamroad_files ORDER BY added_date DESC " .. limit_clause
    )
    
    local result = db:execute(query)
    return result, nil
end

-- =====================================================================
-- Mise à jour des statistiques
-- =====================================================================

function M.increment_play_count(file_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "UPDATE creamroad_files SET play_count = play_count + 1, last_played = NOW() WHERE id = %d",
        tonumber(file_id)
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

-- =====================================================================
-- Tags
-- =====================================================================

function M.add_tag_to_file(file_id, tag_name)
    if not db then return false, "Base de données non connectée" end
    
    -- Vérifier si le tag existe
    local query = string.format(
        "SELECT id FROM creamroad_tag_names WHERE name = '%s'",
        db:escape(tag_name)
    )
    
    local result = db:execute(query)
    local tag_id
    
    if result and result[1] then
        tag_id = result[1].id
    else
        -- Créer le tag
        local insert_query = string.format(
            "INSERT INTO creamroad_tag_names (name) VALUES ('%s') RETURNING id",
            db:escape(tag_name)
        )
        local insert_result = db:execute(insert_query)
        if insert_result and insert_result[1] then
            tag_id = insert_result[1].id
        else
            return false, "Impossible de créer le tag"
        end
    end
    
    -- Vérifier si le fichier a déjà ce tag
    local check_query = string.format(
        "SELECT 1 FROM creamroad_tags WHERE file_id = %d AND tag_id = %d",
        tonumber(file_id), tonumber(tag_id)
    )
    
    local check_result = db:execute(check_query)
    if check_result and check_result[1] then
        return false, "Tag déjà attribué à ce fichier"
    end
    
    -- Ajouter le tag
    local insert_tag_query = string.format(
        "INSERT INTO creamroad_tags (file_id, tag_id) VALUES (%d, %d)",
        tonumber(file_id), tonumber(tag_id)
    )
    
    local tag_result = db:execute(insert_tag_query)
    return tag_result and true or false, nil
end

function M.remove_tag_from_file(file_id, tag_name)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "DELETE FROM creamroad_tags WHERE file_id = %d AND tag_id = " ..
        "(SELECT id FROM creamroad_tag_names WHERE name = '%s')",
        tonumber(file_id), db:escape(tag_name)
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.get_file_tags(file_id)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT tn.name FROM creamroad_tags t " ..
        "JOIN creamroad_tag_names tn ON t.tag_id = tn.id " ..
        "WHERE t.file_id = %d",
        tonumber(file_id)
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_all_tags()
    if not db then return nil, "Base de données non connectée" end
    
    local query = "SELECT name FROM creamroad_tag_names ORDER BY name"
    
    local result = db:execute(query)
    return result, nil
end

-- =====================================================================
-- Playlists
-- =====================================================================

function M.create_playlist(name, creator)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "INSERT INTO creamroad_playlists (name, creator, created_date) VALUES ('%s', '%s', NOW()) RETURNING id",
        db:escape(name), db:escape(creator or "")
    )
    
    local result = db:execute(query)
    return result and result[1] and result[1].id or nil, nil
end

function M.delete_playlist(playlist_id)
    if not db then return false, "Base de données non connectée" end
    
    -- Supprimer les entrées de la playlist
    local delete_entries_query = string.format(
        "DELETE FROM creamroad_playlist_entries WHERE playlist_id = %d",
        tonumber(playlist_id)
    )
    db:execute(delete_entries_query)
    
    -- Supprimer la playlist
    local delete_query = string.format(
        "DELETE FROM creamroad_playlists WHERE id = %d",
        tonumber(playlist_id)
    )
    
    local result = db:execute(delete_query)
    return result and true or false, nil
end

function M.add_file_to_playlist(playlist_id, file_id, position)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "INSERT INTO creamroad_playlist_entries (playlist_id, file_id, position, added_date) " ..
        "VALUES (%d, %d, %d, NOW())",
        tonumber(playlist_id), tonumber(file_id), position or 0
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.remove_file_from_playlist(playlist_id, file_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "DELETE FROM creamroad_playlist_entries WHERE playlist_id = %d AND file_id = %d",
        tonumber(playlist_id), tonumber(file_id)
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.get_playlist_files(playlist_id)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT f.* FROM creamroad_files f " ..
        "JOIN creamroad_playlist_entries p ON f.id = p.file_id " ..
        "WHERE p.playlist_id = %d ORDER BY p.position, p.added_date",
        tonumber(playlist_id)
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_all_playlists(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or ""
    
    local query = "SELECT * FROM creamroad_playlists ORDER BY name " .. limit_clause
    
    local result = db:execute(query)
    return result, nil
end

function M.get_playlist_by_name(name)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT * FROM creamroad_playlists WHERE name = '%s'",
        db:escape(name)
    )
    
    local result = db:execute(query)
    return result and result[1] or nil, nil
end

-- =====================================================================
-- Infos système
-- =====================================================================

function M.get_stats()
    if not db then return nil, "Base de données non connectée" end
    
    local stats = {}
    
    -- Compter les fichiers par type
    local query = "SELECT file_type, COUNT(*) as count FROM creamroad_files GROUP BY file_type"
    local result = db:execute(query)
    stats.by_type = {}
    for _, row in ipairs(result or {}) do
        stats.by_type[row.file_type] = row.count
    end
    
    -- Compter les fichiers totaux
    local total_query = "SELECT COUNT(*) as total FROM creamroad_files"
    local total_result = db:execute(total_query)
    stats.total_files = total_result and total_result[1] and total_result[1].total or 0
    
    -- Taille totale
    local size_query = "SELECT SUM(file_size) as total_size FROM creamroad_files"
    local size_result = db:execute(size_query)
    stats.total_size = size_result and size_result[1] and size_result[1].total_size or 0
    
    -- Nombre de playlists
    local playlist_query = "SELECT COUNT(*) as count FROM creamroad_playlists"
    local playlist_result = db:execute(playlist_query)
    stats.total_playlists = playlist_result and playlist_result[1] and playlist_result[1].count or 0
    
    -- Nombre de tags
    local tag_query = "SELECT COUNT(*) as count FROM creamroad_tag_names"
    local tag_result = db:execute(tag_query)
    stats.total_tags = tag_result and tag_result[1] and tag_result[1].count or 0
    
    -- Fichiers les plus joués
    stats.most_played = M.get_most_played(5)
    
    return stats, nil
end

-- =====================================================================
-- Utilitaires
-- =====================================================================

function M.get_web_url(file_path)
    if not config or not config.creamroad then return nil end
    
    -- Remplacer le base_path par le web_url
    local web_url = config.creamroad.web_url or ""
    local base_path = config.creamroad.base_path or ""
    
    if web_url == "" or base_path == "" then return nil end
    
    -- Nettoyer le chemin
    local clean_path = file_path:gsub("^" .. base_path, ""):gsub("^/+", "")
    
    -- Combiner avec l'URL web
    return web_url .. "/" .. clean_path:gsub("^/+", "")
end

function M.format_file_info(file)
    if not file then return "Fichier non trouvé" end
    
    local lines = {}
    
    -- Ligne 1: Informations principales
    local info1 = string.format("ID: %d | %s", file.id or 0, file.filename or "N/A")
    
    -- Ligne 2: Artiste et album
    local info2 = string.format("Artiste: %s | Album: %s", file.artist or "Inconnu", file.album or "Inconnu")
    
    -- Ligne 3: Durée et qualité audio
    local duration = file.duration and string.format("%02d:%02d", math.floor(file.duration / 60), file.duration % 60) or "N/A"
    local info3 = string.format("Durée: %s | %d kbps | %d Hz | %s", duration, file.bitrate or 0, file.sample_rate or 0, file.channels or "N/A")
    
    -- Ligne 4: Métadonnées supplémentaires
    local info4 = string.format("Genre: %s | Année: %s", file.genre or "N/A", file.year or "N/A")
    
    -- Ligne 5: Statistiques
    local info5 = string.format("Joué %d fois | Ajouté: %s", file.play_count or 0, file.added_date or "N/A")
    
    table.insert(lines, info1)
    table.insert(lines, info2)
    table.insert(lines, info3)
    table.insert(lines, info4)
    table.insert(lines, info5)
    
    -- URL web si disponible
    if file.path then
        local web_url = M.get_web_url(file.path)
        if web_url then
            table.insert(lines, "URL: " .. web_url)
        end
    end
    
    return table.concat(lines, " | ")
end

function M.format_file_list(files, limit_display)
    if not files or #files == 0 then return "Aucun fichier trouvé" end
    
    local limit = limit_display or 5
    local count = math.min(#files, limit)
    local lines = {}
    
    for i = 1, count do
        local file = files[i]
        local line = string.format(
            "%d. %s - %s [%s] (%d kbps, %s)",
            i,
            file.filename or "N/A",
            file.artist or "Inconnu",
            file.album or "Inconnu",
            file.bitrate or 0,
            file.file_type or "N/A"
        )
        table.insert(lines, line)
    end
    
    local more = #files > limit and (" | +" .. (#files - limit) .. " autres") or ""
    
    return table.concat(lines, " | ") .. more
end

-- =====================================================================
-- Fermeture
-- =====================================================================

function M.shutdown()
    if db then
        db:close()
        db = nil
    end
end

-- Ajouter un accesseur pour l'état enabled
function M.is_enabled()
    return enabled
end

return M
