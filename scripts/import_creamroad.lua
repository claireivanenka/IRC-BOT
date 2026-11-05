#!/usr/bin/env lua
-- =====================================================================
-- Script d'import des fichiers CreamRoad dans PostgreSQL
-- Version simplifiée
-- =====================================================================

-- Configuration
local config = {
    creamroad_dir = "CremRoad - Sep 2026",
    
    -- Configuration PostgreSQL
    postgres = {
        host = "127.0.0.1",
        port = 5432,
        database = "irc_bot",
        user = "irc_user",
        password = "irc_password"
    }
}

-- Fonction de logging
local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] [%s] %s", timestamp, level, message))
end

-- Vérifier si un fichier existe
local function file_exists(filepath)
    local f = io.open(filepath, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Obtenir la taille d'un fichier
local function get_file_size(filepath)
    local f = io.open(filepath, "rb")
    if not f then return 0 end
    local size = f:seek("end")
    f:close()
    return size
end

-- Obtenir l'extension d'un fichier
local function get_file_extension(filename)
    return filename:match("%.([^%.]+)$") or ""
end

-- Déterminer le type de fichier
local function get_file_type(extension)
    local audio_exts = {mp3=true, flac=true, ogg=true, wav=true, m4a=true, aac=true, opus=true}
    local video_exts = {mp4=true, mkv=true, avi=true, mov=true, wmv=true, flv=true, webm=true}
    local image_exts = {jpg=true, jpeg=true, png=true, gif=true, bmp=true, webp=true}
    
    extension = extension:lower()
    if audio_exts[extension] then
        return "audio"
    elseif video_exts[extension] then
        return "video"
    elseif image_exts[extension] then
        return "cover"
    else
        return "other"
    end
end

-- Charger luasql-postgres
local luasql_status, luasql = pcall(require, "luasql.postgres")
if not luasql_status then
    log("Erreur: luasql.postgres non trouvé. Installez-le avec: luarocks install luasql-postgres", "ERROR")
    return
end

-- Connexion à PostgreSQL
local function connect_db()
    local env = luasql.postgres()
    local conn_str = string.format("dbname=%s host=%s port=%s user=%s password=%s",
        config.postgres.database,
        config.postgres.host,
        config.postgres.port,
        config.postgres.user,
        config.postgres.password)
    
    local conn = env:connect(conn_str)
    if not conn then
        log("Impossible de se connecter à PostgreSQL", "ERROR")
        return nil, env
    end
    return conn, env
end

-- Fonction principale
local function main()
    log("Début de l'import CreamRoad...")
    
    -- Se connecter à PostgreSQL
    local conn, env = connect_db()
    if not conn then
        return
    end
    
    log("Connexion à PostgreSQL établie")
    
    -- Chemin absolu du dossier CreamRoad
    local creamroad_path = "/home/claire/IRC-BOT/CremRoad - Sep 2026"
    
    -- Vérifier que le dossier existe
    if not file_exists(creamroad_path) then
        log("Dossier CreamRoad non trouvé: " .. creamroad_path, "ERROR")
        conn:close()
        env:close()
        return
    end
    
    log("Dossier CreamRoad trouvé: " .. creamroad_path)
    
    -- Compter les fichiers par type
    local counts = {audio = 0, video = 0, cover = 0, other = 0}
    
    -- Fonction pour importer un répertoire
    local function import_dir(subdir, db_file_type)
        local dir_path = creamroad_path .. "/" .. subdir
        if not file_exists(dir_path) then
            log("Dossier non trouvé: " .. dir_path, "WARNING")
            return 0
        end
        
        -- Lister les fichiers avec un chemin absolu
        local handle = io.popen('find "' .. dir_path .. '" -type f -name "*.*" 2>/dev/null')
        if not handle then
            log("Impossible de lister les fichiers dans " .. dir_path, "ERROR")
            return 0
        end
        
        local count = 0
        for line in handle:lines() do
            local filepath = line:gsub("^%s*", ""):gsub("%s*$", "")
            if filepath ~= "" then
                -- Extraire le nom de fichier du chemin complet
                local filename = filepath:match("([^/]+)$") or filepath
                local ext = get_file_extension(filename)
                local actual_type = get_file_type(ext)
                
                -- Pour les fichiers audio, essayer d'extraire les métadonnées
                local artist = ""
                local album = ""
                local title = ""
                local year = 0
                local track = 0
                local license = "Unknown"
                local comment = ""
                
                -- Si c'est un fichier audio, essayer d'extraire le titre du nom
                if actual_type == "audio" then
                    -- Enlever l'extension
                    title = filename:gsub("%." .. ext .. "$", "")
                    -- Enlever les numéros de piste (ex: 01-, 02_, etc.)
                    title = title:gsub("^%d+[-_%.]%s*", "")
                    -- Enlever les noms d'artiste au début
                    title = title:gsub("^[A-Za-z0-9%-]+[-_%.]%s*", "")
                    -- Nettoyer les caractères spéciaux
                    title = title:gsub("^[%s%-_]+", ""):gsub("[%s%-_]+$", "")
                    
                    artist = "CreamRoad"
                    album = "Collection"
                end
                
                -- Calculer le hash (simplifié - utiliser sha256 si disponible)
                local hash = ""
                
                -- Insérer dans la base de données
                local relative_path = subdir .. "/" .. filename
                local query = string.format(
                    "INSERT INTO creamroad_files (filename, artist, album, title, comment, year, track, file_type, file_path, file_size, hash, format, license) " ..
                    "VALUES ('%s', '%s', '%s', '%s', '%s', %d, %d, '%s', '%s', %d, '%s', '%s', '%s') " ..
                    "ON CONFLICT (filename) DO UPDATE SET " ..
                    "artist = EXCLUDED.artist, album = EXCLUDED.album, title = EXCLUDED.title, comment = EXCLUDED.comment, " ..
                    "year = EXCLUDED.year, track = EXCLUDED.track, file_type = EXCLUDED.file_type, " ..
                    "file_path = EXCLUDED.file_path, file_size = EXCLUDED.file_size, hash = EXCLUDED.hash, " ..
                    "format = EXCLUDED.format, license = EXCLUDED.license, updated_at = CURRENT_TIMESTAMP",
                    filename:gsub("'", "''"),
                    artist:gsub("'", "''"),
                    album:gsub("'", "''"),
                    title:gsub("'", "''"),
                    comment:gsub("'", "''"),
                    year,
                    track,
                    actual_type,
                    relative_path:gsub("'", "''"),
                    get_file_size(filepath),
                    hash,
                    ext,
                    license
                )
                
                local cursor, err = conn:execute(query)
                
                if cursor or not err then
                    count = count + 1
                    counts[actual_type] = counts[actual_type] + 1
                else
                    log("Erreur insertion " .. relative_path .. ": " .. tostring(err), "ERROR")
                end
                
                -- Fermer le cursor s'il existe et que c'est un vrai cursor (pas un nombre)
                if cursor and type(cursor) == "userdata" then
                    pcall(function() cursor:close() end)
                end
            end
        end
        handle:close()
        
        return count
    end
    
    -- Importer chaque répertoire
    log("Importation des fichiers audio...")
    local audio_count = import_dir("audio", "audio")
    log("  " .. audio_count .. " fichiers audio importés")
    
    log("Importation des fichiers video...")
    local video_count = import_dir("video", "video")
    log("  " .. video_count .. " fichiers video importés")
    
    log("Importation des covers...")
    local cover_count = import_dir("covers", "cover")
    log("  " .. cover_count .. " covers importées")
    
    -- Mettre à jour les statistiques
    log("Mise à jour des statistiques...")
    local updates = {
        {"total_files", counts.audio + counts.video + counts.cover + counts.other},
        {"total_audio", counts.audio},
        {"total_video", counts.video},
        {"total_covers", counts.cover},
        {"last_updated", os.date("%Y-%m-%d %H:%M:%S")}
    }
    
    for _, update in ipairs(updates) do
        local query = string.format(
            "INSERT INTO creamroad_stats (stat_name, stat_value) VALUES ('%s', '%s') ON CONFLICT (stat_name) DO UPDATE SET stat_value = EXCLUDED.stat_value, updated_at = CURRENT_TIMESTAMP",
            update[1],
            type(update[2]) == "string" and update[2] or tostring(update[2])
        )
        pcall(function() conn:execute(query) end)
    end
    
    -- Fermer la connexion
    conn:close()
    env:close()
    
    log("Import CreamRoad terminé avec succès!")
    log("Total: " .. (audio_count + video_count + cover_count) .. " fichiers")
    log("  Audio: " .. audio_count)
    log("  Video: " .. video_count)
    log("  Covers: " .. cover_count)
end

-- Exécuter
main()
