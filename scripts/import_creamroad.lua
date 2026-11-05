#!/usr/bin/env lua
-- =====================================================================
-- Script d'import des fichiers CreamRoad dans PostgreSQL
-- =====================================================================

-- Configuration
local config = {
    creamroad_dir = "CremRoad - Sep 2026",
    metadata_dir = "metadata",
    audio_dir = "audio",
    covers_dir = "covers",
    video_dir = "video",
    base_url = "/creamroad",
    
    -- Configuration PostgreSQL (héritée de config.lua)
    postgres = {
        host = "localhost",
        port = 5432,
        database = "irc_bot",
        user = "irc_user",
        password = "irc_password"
    }
}

-- Charger la configuration depuis config.lua si elle existe
local config_file = io.open("config.lua", "r")
if config_file then
    local custom_config = loadfile("config.lua")
    if custom_config then
        local custom = custom_config()
        if custom.postgres then
            for k, v in pairs(custom.postgres) do
                config.postgres[k] = v
            end
        end
        if custom.creamroad_dir then
            config.creamroad_dir = custom.creamroad_dir
        end
        if custom.creamroad_base_url then
            config.base_url = custom.creamroad_base_url
        end
    end
end

-- Fonctions utilitaires
local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] [%s] %s", timestamp, level, message))
end

local function get_file_size(filepath)
    local file = io.open(filepath, "rb")
    if not file then return 0 end
    local size = file:seek("end")
    file:close()
    return size
end

local function get_file_extension(filename)
    return filename:match("%.([^%.]+)$") or ""
end

local function get_file_type(extension)
    local audio_exts = {mp3=true, flac=true, ogg=true, wav=true, m4a=true, aac=true, opus=true}
    local video_exts = {mp4=true, mkv=true, avi=true, mov=true, wmv=true, flv=true, webm=true}
    local image_exts = {jpg=true, jpeg=true, png=true, gif=true, bmp=true, webp=true}
    
    if audio_exts[extension:lower()] then
        return "audio"
    elseif video_exts[extension:lower()] then
        return "video"
    elseif image_exts[extension:lower()] then
        return "cover"
    else
        return "other"
    end
end

local function calculate_sha256(filepath)
    -- Implémentation simplifiée, utilise sha256.lua si disponible
    local sha256 = pcall(require, "sha256")
    if sha256 then
        local f = io.open(filepath, "rb")
        if f then
            local content = f:read("*a")
            f:close()
            return sha256.sha256(content)
        end
    end
    return nil
end

-- Charger luasql-postgres
local luasql = pcall(require, "luasql.postgres")
if not luasql then
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
        log("Impossible de se connecter à PostgreSQL: " .. tostring(conn_str), "ERROR")
        return nil, env
    end
    return conn, env
end

-- Créer les tables si elles n'existent pas
local function create_tables(conn)
    local sql_file = io.open("sql/creamroad_schema.sql", "r")
    if not sql_file then
        log("Fichier sql/creamroad_schema.sql non trouvé", "ERROR")
        return false
    end
    
    local sql = sql_file:read("*a")
    sql_file:close()
    
    -- Exécuter chaque instruction SQL séparément
    for statement in sql:gmatch("[^;]+;[^%z]*") do
        statement = statement:match("^%s*(.-)%s*$")
        if statement and #statement > 0 and not statement:match("^%--") then
            local ok, err = pcall(function()
                conn:execute(statement)
            end)
            if not ok then
                log("Erreur lors de l'exécution: " .. tostring(err), "ERROR")
                return false
            end
        end
    end
    
    log("Tables CreamRoad créées avec succès")
    return true
end

-- Extraire les informations du fichier JSON
local function load_metadata()
    local json_file = io.open(config.creamroad_dir .. "/" .. config.metadata_dir .. "/json-clewn-audio.php.json", "r")
    if not json_file then
        log("Fichier metadata/json-clewn-audio.php.json non trouvé", "WARNING")
        return {}
    end
    
    local content = json_file:read("*a")
    json_file:close()
    
    -- Parser JSON simplement (sans dépendance)
    local metadata = {}
    
    -- Trouver le tableau data
    local data_start = content:find('"data":[%s*\[')
    if not data_start then
        log("Format JSON non reconnu", "WARNING")
        return {}
    end
    
    -- Extraire chaque entrée
    local i = 1
    while true do
        local entry_start = content:find('{%s*"file":', i)
        if not entry_start then break end
        
        local entry_end = content:find('}[^}]*}', entry_start)
        if not entry_end then break end
        
        local entry = content:sub(entry_start, entry_end)
        
        -- Extraire les champs
        local filename = entry:match('"file":%s*"([^"]+)"') or ""
        local artist = entry:match('"artist":%s*"([^"]+)"') or ""
        local album = entry:match('"album":%s*"([^"]+)"') or ""
        local comment = entry:match('"comment":%s*"([^"]+)"') or ""
        local year = entry:match('"year":%s*"?(%d+)') or ""
        local track = entry:match('"track":%s*"?(%d+)') or "0"
        
        -- Extraire la license du commentaire
        local license = comment:match("http://creativecommons%.org/licenses/([^"]+)") or "Unknown"
        
        metadata[filename] = {
            artist = artist,
            album = album,
            title = "", -- À extraire du nom de fichier
            comment = comment,
            year = tonumber(year) or 0,
            track = tonumber(track) or 0,
            license = license
        }
        
        i = entry_end + 1
    end
    
    log("Métadonnées chargées: " .. #metadata .. " entrées")
    return metadata
end

-- Scanner un répertoire et importer les fichiers
local function import_directory(conn, dir_path, file_type)
    local files = {}
    
    -- Lister les fichiers
    local handle = io.popen('ls -1 "' .. dir_path .. '" 2>/dev/null')
    if not handle then return 0 end
    
    for filename in handle:lines() do
        if filename ~= "" and not filename:match("^%.") then
            table.insert(files, filename)
        end
    end
    handle:close()
    
    -- Insérer dans la base de données
    local count = 0
    for _, filename in ipairs(files) do
        local filepath = dir_path .. "/" .. filename
        local file_info = {
            filename = filename,
            file_type = file_type,
            file_path = config.creamroad_dir .. "/" .. filepath:match(".-"(..)):gsub("^%.", ""),
            file_size = get_file_size(filepath),
            extension = get_file_extension(filename),
            format = get_file_extension(filename),
            file_type = get_file_type(get_file_extension(filename))
        }
        
        -- Vérifier si c'est de l'audio et récupérer les métadonnées
        if file_type == "audio" and metadata[filename] then
            local meta = metadata[filename]
            file_info.artist = meta.artist
            file_info.album = meta.album
            file_info.comment = meta.comment
            file_info.year = meta.year
            file_info.track = meta.track
            file_info.license = meta.license
            
            -- Extraire le titre du nom de fichier
            local title = filename:gsub("%.flac", ""):gsub("%.mp3", ""):gsub("%.wav", "")
            -- Supprimer les numéros de piste
            title = title:gsub("^%d+[-_]", "")
            -- Supprimer les noms d'artiste
            for artist in title:gmatch("([^%-]+)-[^%-]+") do
                title = title:gsub("^" .. artist .. "-", ""):gsub("^%s*")
            end
            file_info.title = title:gsub("^[%s%-]+", ""):gsub("[%s%-]+$", "")
        end
        
        -- Calculer le hash
        file_info.hash = calculate_sha256(filepath)
        
        -- Insérer dans la base de données
        local query = string.format(
            "INSERT INTO creamroad_files (filename, artist, album, title, comment, year, track, file_type, file_path, file_size, hash, format, license) " ..
            "VALUES ('%s', '%s', '%s', '%s', '%s', %s, %s, '%s', '%s', %d, '%s', '%s', '%s') " ..
            "ON CONFLICT (filename) DO UPDATE SET " ..
            "artist = EXCLUDED.artist, album = EXCLUDED.album, title = EXCLUDED.title, comment = EXCLUDED.comment, " ..
            "year = EXCLUDED.year, track = EXCLUDED.track, file_type = EXCLUDED.file_type, " ..
            "file_path = EXCLUDED.file_path, file_size = EXCLUDED.file_size, hash = EXCLUDED.hash, " ..
            "format = EXCLUDED.format, license = EXCLUDED.license, updated_at = CURRENT_TIMESTAMP",
            file_info.filename:gsub("'", "''"),
            (file_info.artist or ""):gsub("'", "''"),
            (file_info.album or ""):gsub("'", "''"),
            (file_info.title or ""):gsub("'", "''"),
            (file_info.comment or ""):gsub("'", "''"),
            file_info.year or 0,
            file_info.track or 0,
            file_info.file_type or "other",
            file_info.file_path:gsub("'", "''"),
            file_info.file_size or 0,
            file_info.hash or "",
            file_info.format or "",
            file_info.license or "Unknown"
        )
        
        local ok, err = pcall(function()
            conn:execute(query)
        end)
        
        if ok then
            count = count + 1
        else
            log("Erreur insertion " .. filename .. ": " .. tostring(err), "ERROR")
        end
    end
    
    return count
end

-- Mettre à jour les statistiques
local function update_stats(conn, audio_count, video_count, cover_count)
    local total = audio_count + video_count + cover_count
    
    local updates = {
        {"total_files", total},
        {"total_audio", audio_count},
        {"total_video", video_count},
        {"total_covers", cover_count},
        {"last_updated", "CURRENT_TIMESTAMP"}
    }
    
    for _, update in ipairs(updates) do
        local query = string.format(
            "INSERT INTO creamroad_stats (stat_name, stat_value) VALUES ('%s', '%s') ON CONFLICT (stat_name) DO UPDATE SET stat_value = EXCLUDED.stat_value, updated_at = CURRENT_TIMESTAMP",
            update[1],
            type(update[2]) == "string" and update[2] or tostring(update[2])
        )
        pcall(function() conn:execute(query) end)
    end
end

-- Fonction principale
local function main()
    log("Début de l'import CreamRoad...")
    
    -- Charger les métadonnées
    metadata = load_metadata()
    
    -- Se connecter à PostgreSQL
    local conn, env = connect_db()
    if not conn then
        return
    end
    
    -- Créer les tables
    if not create_tables(conn) then
        conn:close()
        env:close()
        return
    end
    
    -- Chemin absolu du dossier CreamRoad
    local creamroad_path = config.creamroad_dir
    if not creamroad_path:match("/") then
        creamroad_path = "./" .. creamroad_path
    end
    
    -- Importer les fichiers
    log("Importation des fichiers audio...")
    local audio_dir = creamroad_path .. "/" .. config.audio_dir
    local audio_count = import_directory(conn, audio_dir, "audio")
    log("  " .. audio_count .. " fichiers audio importés")
    
    log("Importation des fichiers video...")
    local video_dir = creamroad_path .. "/" .. config.video_dir
    local video_count = import_directory(conn, video_dir, "video")
    log("  " .. video_count .. " fichiers video importés")
    
    log("Importation des covers...")
    local covers_dir = creamroad_path .. "/" .. config.covers_dir
    local cover_count = import_directory(conn, covers_dir, "cover")
    log("  " .. cover_count .. " covers importées")
    
    -- Mettre à jour les statistiques
    update_stats(conn, audio_count, video_count, cover_count)
    
    -- Fermer la connexion
    conn:close()
    env:close()
    
    log("Import CreamRoad terminé avec succès!")
    log("Total: " .. (audio_count + video_count + cover_count) .. " fichiers")
end

-- Exécuter
main()
