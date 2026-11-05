-- =====================================================================
-- CreamRoad Manager - Gestion des fichiers multimédias CreamRoad
-- =====================================================================

local M = {}
local config = nil
local db = nil
local enabled = false

-- =====================================================================
-- Initialisation
-- =====================================================================

function M.init(user_config)
    config = user_config
    
    if not config.creamroad or not config.creamroad.enabled then
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
-- Fonctions de recherche
-- =====================================================================

function M.search_files(search_term, limit, offset)
    if not db then return nil, "Base de données non connectée" end
    
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
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT * FROM creamroad_files ORDER BY RANDOM() LIMIT %d",
        count or 10
    )
    
    local result = db:execute(query)
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
