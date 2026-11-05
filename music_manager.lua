-- =====================================================================
-- Music Manager - Gestion des fichiers audio pour le bot IRC
-- =====================================================================

local M = {}
local config = nil
local db = nil
local creamroad_manager = nil

-- =====================================================================
-- Initialisation
-- =====================================================================

function M.init(user_config)
    config = user_config
    
    if not config.music or not config.music.enabled then
        print("⚠️  Module musique désactivé")
        return false
    end
    
    -- Vérifier que PostgreSQL est activé
    if not config.database or not config.database.enabled then
        print("⚠️  Module musique nécessite PostgreSQL activé")
        return false
    end
    
    -- Charger le module database
    local db_module = require("database")
    if not db_module then
        print("⚠️  Impossible de charger le module database")
        return false
    end
    
    -- Initialiser la connexion à la base de données
    db = db_module.connect(config.database)
    if not db then
        print("⚠️  Impossible de se connecter à PostgreSQL pour la musique")
        return false
    end
    
    -- Vérifier les tables musique
    if not M.check_tables() then
        print("⚠️  Tables musique non trouvées")
        return false
    end
    
    -- Si CreamRoad est activé, l'utiliser
    local creamroad_ok, creamroad_module = pcall(require, "creamroad_manager")
    if creamroad_ok and creamroad_module and config.creamroad and config.creamroad.enabled then
        creamroad_manager = creamroad_module
        -- Ne pas réinitialiser CreamRoad, juste vérifier s'il est déjà activé
        if creamroad_manager.is_enabled and creamroad_manager:is_enabled() then
            print("✓ Module musique intégré avec CreamRoad")
        else
            -- Si pas encore initialisé, l'initialiser
            if creamroad_manager.init(config) then
                print("✓ Module musique intégré avec CreamRoad")
            else
                print("⚠️  CreamRoad non disponible, utilisation du système local")
            end
        end
    else
        print("⚠️  CreamRoad non disponible, utilisation du système local")
    end
    
    -- Créer la table des musiques si elle n'existe pas
    M.create_tables()
    
    print("✓ Module musique activé")
    return true
end

-- =====================================================================
-- Vérification et création des tables
-- =====================================================================

function M.check_tables()
    if not db then return false end
    
    -- Vérifier la table tracks
    local query = "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'tracks')"
    local result = db:execute(query)
    
    if result and result[1] and (result[1].exists or result[1][1]) then
        return true
    end
    
    return false
end

function M.create_tables()
    if not db then return false end
    
    -- Créer la table tracks si elle n'existe pas
    local query = [[
        CREATE TABLE IF NOT EXISTS tracks (
            id SERIAL PRIMARY KEY,
            titre VARCHAR(500) NOT NULL,
            artiste VARCHAR(500),
            album VARCHAR(500),
            annee INTEGER,
            genre VARCHAR(255),
            duree INTEGER, -- en secondes
            bitrate INTEGER,
            sample_rate INTEGER,
            channels INTEGER,
            chemin_fichier VARCHAR(1000) NOT NULL,
            url_streaming VARCHAR(1000),
            hash_fichier VARCHAR(64) UNIQUE, -- SHA-256
            ajoute_par VARCHAR(100) DEFAULT 'system',
            date_ajout TIMESTAMP DEFAULT NOW(),
            nb_lectures INTEGER DEFAULT 0,
            date_derniere_lecture TIMESTAMP,
            track_number INTEGER,
            total_tracks INTEGER,
            disc_number INTEGER,
            total_discs INTEGER,
            commentaire TEXT,
            cover_path VARCHAR(1000),
            UNIQUE (hash_fichier)
        )
    ]]
    
    local result = db:execute(query)
    
    -- Créer un index sur les champs de recherche
    local index_query = [[
        CREATE INDEX IF NOT EXISTS tracks_titre_idx ON tracks (titre);
        CREATE INDEX IF NOT EXISTS tracks_artiste_idx ON tracks (artiste);
        CREATE INDEX IF NOT EXISTS tracks_album_idx ON tracks (album);
        CREATE INDEX IF NOT EXISTS tracks_genre_idx ON tracks (genre);
        CREATE INDEX IF NOT EXISTS tracks_annee_idx ON tracks (annee);
        CREATE INDEX IF NOT EXISTS tracks_hash_idx ON tracks (hash_fichier);
        CREATE INDEX IF NOT EXISTS tracks_ajoute_par_idx ON tracks (ajoute_par);
    ]]
    
    db:execute(index_query)
    
    -- Créer la table playlists
    local playlist_query = [[
        CREATE TABLE IF NOT EXISTS music_playlists (
            id SERIAL PRIMARY KEY,
            nom VARCHAR(255) NOT NULL UNIQUE,
            createur VARCHAR(100) DEFAULT 'system',
            date_creation TIMESTAMP DEFAULT NOW()
        )
    ]]
    
    db:execute(playlist_query)
    
    -- Créer la table playlist_entries
    local playlist_entries_query = [[
        CREATE TABLE IF NOT EXISTS music_playlist_entries (
            id SERIAL PRIMARY KEY,
            playlist_id INTEGER REFERENCES music_playlists(id) ON DELETE CASCADE,
            track_id INTEGER REFERENCES tracks(id) ON DELETE CASCADE,
            position INTEGER DEFAULT 0
        )
    ]]
    
    db:execute(playlist_entries_query)
    
    return true
end

-- =====================================================================
-- Extraction des métadonnées (fallback simple)
-- =====================================================================

function M.extract_metadata_from_filename(filepath)
    -- Extraction basique basée sur le nom de fichier
    -- Format attendu: Artiste - Album - Titre.ext
    local filename = filepath:match("[^/\\]+$")
    if not filename then filename = filepath end
    
    local name = filename:gsub("%.%a+$", "")  -- Supprimer l'extension
    
    -- Essayer de parser : Artiste - Album - Titre
    local artiste, album, titre = name:match("^(.-) - (.-) - (.+)$")
    
    if artiste and album and titre then
        return {
            titre = titre:gsub("^%s+", ""):gsub("%s+$", ""),
            artiste = artiste:gsub("^%s+", ""):gsub("%s+$", ""),
            album = album:gsub("^%s+", ""):gsub("%s+$", ""),
            duree = 0,
            bitrate = 0,
            sample_rate = 44100,
            channels = 2,
        }
    end
    
    -- Essayer : Artiste - Titre
    artiste, titre = name:match("^(.-) - (.+)$")
    if artiste and titre then
        return {
            titre = titre:gsub("^%s+", ""):gsub("%s+$", ""),
            artiste = artiste:gsub("^%s+", ""):gsub("%s+$", ""),
            album = "Inconnu",
            duree = 0,
            bitrate = 0,
            sample_rate = 44100,
            channels = 2,
        }
    end
    
    -- Par défaut
    return {
        titre = name,
        artiste = "Inconnu",
        album = "Inconnu",
        duree = 0,
        bitrate = 0,
        sample_rate = 44100,
        channels = 2,
    }
end

-- =====================================================================
-- Calcul du hash SHA-256 (implémentation simple)
-- =====================================================================

function M.calculate_sha256(filepath)
    -- Utiliser sha256sum si disponible
    local handle = io.popen('sha256sum "' .. filepath .. '" 2>/dev/null')
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            return result:match("^[a-f0-9]+")
        end
    end
    
    -- Fallback : générer un hash basé sur le chemin
    local simple_hash = "unknown_" .. tostring(filepath:gsub("[^%w]", "_"))
    return simple_hash:sub(1, 64)
end

-- =====================================================================
-- CRUD pour les tracks
-- =====================================================================

function M.add_track(filepath, added_by)
    if not db then return nil, "Base de données non connectée" end
    
    -- Vérifier que le fichier existe
    local file = io.open(filepath, "rb")
    if not file then
        return nil, "Fichier non trouvé"
    end
    file:close()
    
    -- Calculer le hash
    local hash = M.calculate_sha256(filepath)
    if not hash then
        return nil, "Impossible de calculer le hash"
    end
    
    -- Extraire les métadonnées
    local metadata = M.extract_metadata_from_filename(filepath)
    
    -- Calculer la taille
    local file_size = 0
    local size_file = io.open(filepath, "rb")
    if size_file then
        file_size = size_file:seek("end")
        size_file:close()
    end
    
    -- Générer l'URL de streaming
    local streaming_url
    if creamroad_manager then
        streaming_url = creamroad_manager.get_web_url(filepath)
    else
        streaming_url = config.music.base_url .. "/stream/" .. hash
    end
    
    -- Préparer la requête d'insertion
    local query = string.format(
        "INSERT INTO tracks (titre, artiste, album, annee, genre, duree, bitrate, sample_rate, " ..
        "channels, chemin_fichier, url_streaming, hash_fichier, ajoute_par) " ..
        "VALUES ('%s', '%s', '%s', %d, '%s', %d, %d, %d, %d, '%s', '%s', '%s', '%s') " ..
        "ON CONFLICT (hash_fichier) DO UPDATE SET " ..
        "titre = EXCLUDED.titre, artiste = EXCLUDED.artiste, album = EXCLUDED.album, " ..
        "ajoute_par = EXCLUDED.ajoute_par, date_ajout = NOW() " ..
        "RETURNING id",
        db:escape(metadata.titre or "Inconnu"),
        db:escape(metadata.artiste or "Inconnu"),
        db:escape(metadata.album or "Inconnu"),
        0, -- annee
        db:escape(metadata.genre or "Inconnu"),
        metadata.duree or 0,
        metadata.bitrate or 0,
        metadata.sample_rate or 0,
        metadata.channels or 2,
        db:escape(filepath),
        db:escape(streaming_url or ""),
        db:escape(hash),
        db:escape(added_by or "system")
    )
    
    local result = db:execute(query)
    
    if result and result[1] then
        return result[1].id, nil
    end
    
    return nil, "Impossible d'ajouter la piste"
end

function M.get_track_by_id(track_id)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format("SELECT * FROM tracks WHERE id = %d", tonumber(track_id))
    local result = db:execute(query)
    
    return result and result[1] or nil, nil
end

function M.get_track_by_hash(hash)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format("SELECT * FROM tracks WHERE hash_fichier = '%s'", db:escape(hash))
    local result = db:execute(query)
    
    return result and result[1] or nil, nil
end

function M.search_tracks(query, limit, offset)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    local offset_clause = offset and offset > 0 and "OFFSET " .. offset or ""
    
    local search_query = string.format(
        "SELECT * FROM tracks WHERE titre ILIKE '%%" .. db:escape(query) .. "%%' " ..
        "OR artiste ILIKE '%%" .. db:escape(query) .. "%%' " ..
        "OR album ILIKE '%%" .. db:escape(query) .. "%%' " ..
        "ORDER BY titre " .. limit_clause .. " " .. offset_clause
    )
    
    local result = db:execute(search_query)
    return result, nil
end

function M.delete_track(track_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format("DELETE FROM tracks WHERE id = %d", tonumber(track_id))
    local result = db:execute(query)
    
    return result and true or false, nil
end

-- =====================================================================
-- Statistiques
-- =====================================================================

function M.increment_play_count(track_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "UPDATE tracks SET nb_lectures = nb_lectures + 1, date_derniere_lecture = NOW() WHERE id = %d",
        tonumber(track_id)
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.get_most_played(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = "SELECT * FROM tracks ORDER BY nb_lectures DESC, date_derniere_lecture DESC " .. limit_clause
    local result = db:execute(query)
    
    return result, nil
end

function M.get_recently_played(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = "SELECT * FROM tracks WHERE date_derniere_lecture IS NOT NULL ORDER BY date_derniere_lecture DESC " .. limit_clause
    local result = db:execute(query)
    
    return result, nil
end

function M.get_recently_added(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or "LIMIT 10"
    
    local query = "SELECT * FROM tracks ORDER BY date_ajout DESC " .. limit_clause
    local result = db:execute(query)
    
    return result, nil
end

-- =====================================================================
-- Playlists
-- =====================================================================

function M.create_playlist(name, creator)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "INSERT INTO music_playlists (nom, createur) VALUES ('%s', '%s') RETURNING id",
        db:escape(name), db:escape(creator or "system")
    )
    
    local result = db:execute(query)
    return result and result[1] and result[1].id or nil, nil
end

function M.delete_playlist(playlist_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format("DELETE FROM music_playlists WHERE id = %d", tonumber(playlist_id))
    local result = db:execute(query)
    
    return result and true or false, nil
end

function M.add_track_to_playlist(playlist_id, track_id, position)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "INSERT INTO music_playlist_entries (playlist_id, track_id, position) VALUES (%d, %d, %d)",
        tonumber(playlist_id), tonumber(track_id), position or 0
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.remove_track_from_playlist(playlist_id, track_id)
    if not db then return false, "Base de données non connectée" end
    
    local query = string.format(
        "DELETE FROM music_playlist_entries WHERE playlist_id = %d AND track_id = %d",
        tonumber(playlist_id), tonumber(track_id)
    )
    
    local result = db:execute(query)
    return result and true or false, nil
end

function M.get_playlist_tracks(playlist_id)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format(
        "SELECT t.* FROM tracks t " ..
        "JOIN music_playlist_entries p ON t.id = p.track_id " ..
        "WHERE p.playlist_id = %d ORDER BY p.position",
        tonumber(playlist_id)
    )
    
    local result = db:execute(query)
    return result, nil
end

function M.get_all_playlists(limit)
    if not db then return nil, "Base de données non connectée" end
    
    local limit_clause = limit and limit > 0 and "LIMIT " .. limit or ""
    
    local query = "SELECT * FROM music_playlists ORDER BY nom " .. limit_clause
    local result = db:execute(query)
    
    return result, nil
end

function M.get_playlist_by_name(name)
    if not db then return nil, "Base de données non connectée" end
    
    local query = string.format("SELECT * FROM music_playlists WHERE nom = '%s'", db:escape(name))
    local result = db:execute(query)
    
    return result and result[1] or nil, nil
end

-- =====================================================================
-- Utilitaires
-- =====================================================================

function M.format_track_info(track)
    if not track then return "Piste non trouvée" end
    
    local duration = track.duree and string.format("%02d:%02d", math.floor(track.duree / 60), track.duree % 60) or "N/A"
    
    local info = string.format(
        "%s - %s | Album: %s | %s | %d kbps | %d Hz | %s | Joué %d fois",
        track.titre or "Inconnu",
        track.artiste or "Inconnu",
        track.album or "Inconnu",
        duration,
        track.bitrate or 0,
        track.sample_rate or 0,
        track.channels or "N/A",
        track.nb_lectures or 0
    )
    
    if track.url_streaming and track.url_streaming ~= "" then
        info = info .. " | URL: " .. track.url_streaming
    end
    
    return info
end

function M.format_track_list(tracks, limit_display)
    if not tracks or #tracks == 0 then return "Aucune piste trouvée" end
    
    local limit = limit_display or 5
    local count = math.min(#tracks, limit)
    local lines = {}
    
    for i = 1, count do
        local track = tracks[i]
        local duration = track.duree and string.format("%02d:%02d", math.floor(track.duree / 60), track.duree % 60) or "N/A"
        local line = string.format(
            "%d. %s - %s [%s] (%s, %d kbps)",
            i,
            track.titre or "Inconnu",
            track.artiste or "Inconnu",
            track.album or "Inconnu",
            duration,
            track.bitrate or 0
        )
        table.insert(lines, line)
    end
    
    local more = #tracks > limit and (" | +" .. (#tracks - limit) .. " autres") or ""
    
    return table.concat(lines, " | ") .. more
end

-- =====================================================================
-- Gestion des fichiers
-- =====================================================================

function M.scan_directory(directory)
    -- Simple scan pour trouver les fichiers audio
    -- Retourne une liste de fichiers
    local files = {}
    
    -- Vérifier que le dossier existe
    local handle = io.popen('find "' .. directory .. '" -type f 2>/dev/null')
    if handle then
        for file in handle:lines() do
            -- Filtrer par extensions autorisées
            local allowed = config.music.allowed_extensions or {"mp3", "flac", "ogg", "m4a", "wav"}
            local ext = file:match("%.([^%.]+)$")
            if ext then
                ext = ext:lower()
                for _, allowed_ext in ipairs(allowed) do
                    if ext == allowed_ext:lower() then
                        table.insert(files, file)
                        break
                    end
                end
            end
        end
        handle:close()
    end
    
    return files
end

function M.add_directory(directory, added_by)
    if not db then return 0, "Base de données non connectée" end
    
    local files = M.scan_directory(directory)
    local count = 0
    
    for _, filepath in ipairs(files) do
        local track_id, err = M.add_track(filepath, added_by)
        if track_id then
            count = count + 1
        else
            print(string.format("⚠️  Impossible d'ajouter %s: %s", filepath, err or "erreur inconnue"))
        end
    end
    
    return count, nil
end

-- =====================================================================
-- Fermeture
-- =====================================================================

-- =====================================================================
-- Gestionnaire de commandes IRC
-- =====================================================================

function M.handle_command(nick, target, message)
    local cmd = message:lower()
    local responses = {}
    
    -- !music add <chemin|URL>
    if cmd:match("^!music add") then
        local filepath = cmd:match("^!music add (.+)")
        if filepath then
            -- Vérifier si c'est une URL ou un chemin local
            if filepath:match("^https?://") then
                table.insert(responses, nick .. ": ❌ L'ajout par URL n'est pas encore implémenté. Utilisez un chemin local.")
            else
                -- Ajouter le track
                local track_id, err = M.add_track(filepath, nick)
                if track_id then
                    local track = M.get_track_by_id(track_id)
                    if track then
                        table.insert(responses, nick .. ": ✅ Piste ajoutée: " .. M.format_track_info(track))
                    else
                        table.insert(responses, nick .. ": ✅ Piste ajoutée (ID: " .. track_id .. ")")
                    end
                else
                    table.insert(responses, nick .. ": ❌ Erreur: " .. (err or "Inconnu"))
                end
            end
        else
            table.insert(responses, nick .. ": ❌ Utilisation: !music add <chemin>")
        end
        
    -- !music search <requête>
    elseif cmd:match("^!music search") then
        local query = cmd:match("^!music search (.+)")
        if query then
            local tracks, err = M.search_tracks(query, 5)
            if tracks and #tracks > 0 then
                table.insert(responses, "🔍 **Résultats**: " .. M.format_track_list(tracks, 5))
            else
                table.insert(responses, nick .. ": ❌ Aucune piste trouvée pour " .. query)
            end
        else
            table.insert(responses, nick .. ": ❌ Utilisation: !music search <requête>")
        end
        
    -- !music info <id>
    elseif cmd:match("^!music info") then
        local query = cmd:match("^!music info (%S+)")
        if query then
            local track_id = tonumber(query)
            local track
            if track_id then
                track = M.get_track_by_id(track_id)
            else
                -- Essayer de trouver par nom
                local tracks = M.search_tracks(query, 1)
                track = tracks and tracks[1]
            end
            
            if track then
                table.insert(responses, "ℹ️ **Info Piste**: " .. M.format_track_info(track))
            else
                table.insert(responses, nick .. ": ❌ Piste non trouvée: " .. query)
            end
        else
            table.insert(responses, nick .. ": ❌ Utilisation: !music info <ID|nom>")
        end
        
    -- !music play <id>
    elseif cmd:match("^!music play") then
        local query = cmd:match("^!music play (%S+)")
        if query then
            local track_id = tonumber(query)
            local track
            if track_id then
                track = M.get_track_by_id(track_id)
            else
                local tracks = M.search_tracks(query, 1)
                track = tracks and tracks[1]
            end
            
            if track then
                -- Incrémenter le compteur
                M.increment_play_count(track.id)
                
                -- Formater la réponse
                local info = string.format(
                    "▶️ **Joue**: %s - %s [%s] (%d kbps)",
                    track.titre or "Inconnu",
                    track.artiste or "Inconnu",
                    track.album or "Inconnu",
                    track.bitrate or 0
                )
                
                if track.url_streaming and track.url_streaming ~= "" then
                    info = info .. " | " .. track.url_streaming
                end
                
                table.insert(responses, info)
            else
                table.insert(responses, nick .. ": ❌ Piste non trouvée: " .. query)
            end
        else
            table.insert(responses, nick .. ": ❌ Utilisation: !music play <ID|nom>")
        end
        
    -- !music stats
    elseif cmd:match("^!music stats") then
        local tracks, err = M.get_most_played(10)
        if tracks and #tracks > 0 then
            table.insert(responses, "🏆 **Top 10 des pistes les plus écoutées**:")
            for i, track in ipairs(tracks) do
                local duration = track.duree and string.format("%02d:%02d", math.floor(track.duree / 60), track.duree % 60) or "N/A"
                local line = string.format("%d. %s - %s (%d lectures)", i, track.titre or "Inconnu", track.artiste or "Inconnu", track.nb_lectures or 0)
                table.insert(responses, line)
            end
        else
            table.insert(responses, nick .. ": ❌ Aucune statistique disponible")
        end
        
    -- !music recent
    elseif cmd:match("^!music recent") then
        local limit = tonumber(cmd:match("^!music recent (%d+)")) or 5
        local tracks, err = M.get_recently_added(limit)
        if tracks and #tracks > 0 then
            table.insert(responses, "🆕 **Pistes récentes**: " .. M.format_track_list(tracks, limit))
        else
            table.insert(responses, nick .. ": ❌ Aucune piste récente")
        end
        
    -- !music dl <id>
    elseif cmd:match("^!music dl") then
        local query = cmd:match("^!music dl (%S+)")
        if query then
            local track_id = tonumber(query)
            local track
            if track_id then
                track = M.get_track_by_id(track_id)
            else
                local tracks = M.search_tracks(query, 1)
                track = tracks and tracks[1]
            end
            
            if track and track.url_streaming and track.url_streaming ~= "" then
                table.insert(responses, nick .. ": 📥 Lien de téléchargement: " .. track.url_streaming)
            else
                table.insert(responses, nick .. ": ❌ Piste non trouvée ou pas de lien de téléchargement")
            end
        else
            table.insert(responses, nick .. ": ❌ Utilisation: !music dl <ID|nom>")
        end
        
    -- !music
    elseif cmd:match("^!music$") then
        table.insert(responses, "❓ **Aide Musique**: !music add <chemin> | !music search <terme> | !music info <ID> | !music play <ID> | !music stats | !music recent | !music dl <ID>")
        
    -- Commande inconnue
    else
        table.insert(responses, nick .. ": ❌ Commande musique inconnue. Tapez !music pour l'aide.")
    end
    
    return responses
end

function M.shutdown()
    if db then
        db:close()
        db = nil
    end
    
    if creamroad_manager then
        creamroad_manager.shutdown()
        creamroad_manager = nil
    end
end

return M
