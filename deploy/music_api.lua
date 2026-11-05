#!/usr/bin/env lua
-- Music API Server simplifié pour le player web

local luasql = require "luasql.postgres"
local to_json = require "json_utils"
-- local json = require "dkjson"
local socket = require "socket"

-- Configuration
local config = {
    host = "127.0.0.1",
    port = 8081,
    music_dir = "/var/lib/irc_bot/music",
    base_url = "http://localhost:8080/music"
}

-- Configuration PostgreSQL (valeurs par défaut, surchargées par ../config.lua si présent)
local db_config = {
    host = "localhost",
    port = 5432,
    database = "irc_bot",
    user = "irc_user",
    password = "irc_password"
}

do
    local script_dir = arg and arg[0] and arg[0]:match("^(.*)/") or "."
    local chunk, load_err = loadfile(script_dir .. "/../config.lua")
    if chunk then
        local ok, user_config = pcall(chunk)
        if ok and type(user_config) == "table" and type(user_config.database) == "table" then
            local db = user_config.database
            db_config.host = db.host or db_config.host
            db_config.port = db.port or db_config.port
            db_config.database = db.database or db.dbname or db_config.database
            db_config.user = db.user or db_config.user
            db_config.password = db.password or db_config.password
        end
    end
end

-- Fonction pour obtenir le message de status HTTP
local function get_status_message(status)
    local messages = {
        [200] = "OK",
        [400] = "Bad Request",
        [404] = "Not Found",
        [500] = "Internal Server Error",
        [501] = "Not Implemented"
    }
    return messages[status] or "Unknown"
end

-- Connexion à PostgreSQL
local function get_db_connection()
    local env = luasql.postgres()
    -- Même forme que irc_bot.lua : chaîne de connexion unique
    local conn_str = string.format("host=%s port=%d dbname=%s user=%s password=%s",
        db_config.host,
        db_config.port,
        db_config.database,
        db_config.user,
        db_config.password)
    local conn, err = env:connect(conn_str)
    if not conn then
        print("Erreur: Impossible de se connecter à PostgreSQL: " .. tostring(err))
        print("   Chaîne utilisée: host=" .. db_config.host .. " port=" .. db_config.port
            .. " dbname=" .. db_config.database .. " user=" .. db_config.user)
        env:close()
        return nil, nil
    end
    return conn, env
end

-- Échapper une valeur littérale pour PostgreSQL (luasql ne supporte pas les requêtes paramétrées)
local function sql_literal(value)
    if type(value) == "number" then
        return tostring(value)
    end
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

-- Exécuter une requête SQL
local function execute_query(query)
    local conn, env = get_db_connection()
    if not conn then return nil, "Connexion échouée" end
    
    local cursor, err = conn:execute(query)
    if not cursor then
        print("Erreur SQL: " .. tostring(err))
        conn:close()
        env:close()
        return nil, tostring(err)
    end
    
    return cursor, conn, env
end

-- Récupérer toutes les pistes
local function get_all_tracks()
    local cursor, conn, env = execute_query("SELECT * FROM tracks ORDER BY titre ASC")
    if not cursor then
        return nil
    end
    
    local tracks = {}
    local row = cursor:fetch({}, "a")
    while row do
        tracks[#tracks + 1] = {
            id = tonumber(row.id),
            titre = row.titre or "",
            artiste = row.artiste or "",
            album = row.album or "",
            annee = tonumber(row.annee) or 0,
            genre = row.genre or "",
            duree = tonumber(row.duree) or 0,
            chemin_fichier = row.chemin_fichier or "",
            url_streaming = (row.url_streaming and row.url_streaming ~= "" and row.url_streaming)
                or (config.base_url .. "/stream/" .. (row.hash_fichier or "")),
            hash_fichier = row.hash_fichier or "",
            ajoute_par = row.ajoute_par or "",
            date_ajout = row.date_ajout or "",
            nb_lectures = tonumber(row.nb_lectures) or 0
        }
        row = cursor:fetch({}, "a")
    end
    
    cursor:close()
    conn:close()
    env:close()
    return tracks
end

-- Rechercher des pistes
local function search_tracks(query)
    local search_pattern = sql_literal("%" .. query .. "%")
    local cursor, conn, env = execute_query(
        "SELECT * FROM tracks WHERE titre ILIKE " .. search_pattern
        .. " OR artiste ILIKE " .. search_pattern
        .. " OR album ILIKE " .. search_pattern
        .. " OR genre ILIKE " .. search_pattern
        .. " ORDER BY titre ASC")
    if not cursor then
        return nil
    end
    
    local tracks = {}
    local row = cursor:fetch({}, "a")
    while row do
        tracks[#tracks + 1] = {
            id = tonumber(row.id),
            titre = row.titre or "",
            artiste = row.artiste or "",
            album = row.album or "",
            annee = tonumber(row.annee) or 0,
            genre = row.genre or "",
            duree = tonumber(row.duree) or 0,
            chemin_fichier = row.chemin_fichier or "",
            url_streaming = (row.url_streaming and row.url_streaming ~= "" and row.url_streaming)
                or (config.base_url .. "/stream/" .. (row.hash_fichier or "")),
            hash_fichier = row.hash_fichier or "",
            ajoute_par = row.ajoute_par or "",
            date_ajout = row.date_ajout or "",
            nb_lectures = tonumber(row.nb_lectures) or 0
        }
        row = cursor:fetch({}, "a")
    end
    
    cursor:close()
    conn:close()
    env:close()
    return tracks
end

-- Incrémenter le compteur de lectures
local function increment_play_count(id)
    local conn, env = get_db_connection()
    if not conn then return false end
    
    local success = conn:execute("UPDATE tracks SET nb_lectures = nb_lectures + 1 WHERE id = " .. id)
    conn:close()
    env:close()
    
    return success ~= nil
end

-- Récupérer les statistiques
local function get_stats()
    local stats = {}
    
    -- Top 10 des pistes les plus écoutées
    local cursor, conn, env = execute_query("SELECT * FROM tracks ORDER BY nb_lectures DESC LIMIT 10")
    if cursor then
        stats.top_tracks = {}
        local row = cursor:fetch({}, "a")
        while row do
            stats.top_tracks[#stats.top_tracks + 1] = {
                id = tonumber(row.id),
                titre = row.titre or "",
                artiste = row.artiste or "",
                nb_lectures = tonumber(row.nb_lectures) or 0
            }
            row = cursor:fetch({}, "a")
        end
        cursor:close()
    end
    if conn then conn:close() end
    if env then env:close() end
    conn, env = nil, nil
    
    -- Nombre total de pistes
    cursor, conn, env = execute_query("SELECT COUNT(*) as count FROM tracks")
    if cursor then
        local row = cursor:fetch({}, "a")
        stats.total_tracks = tonumber(row.count) or 0
        cursor:close()
    end
    if conn then conn:close() end
    if env then env:close() end
    conn, env = nil, nil
    
    -- Nombre total de lectures
    cursor, conn, env = execute_query("SELECT SUM(nb_lectures) as total FROM tracks")
    if cursor then
        local row = cursor:fetch({}, "a")
        stats.total_plays = tonumber(row.total) or 0
        cursor:close()
    end
    
    if conn then conn:close() end
    if env then env:close() end
    
    return stats
end

-- Traiter une requête HTTP
local function handle_request(method, path, headers, body)
    local response = {
        status = 404,
        headers = {
            ["Content-Type"] = "application/json",
            ["Access-Control-Allow-Origin"] = "*",
            ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
            ["Access-Control-Allow-Headers"] = "Content-Type"
        },
        body = to_json({ error = "Not found" })
    }
    
    -- CORS Préflight
    if method == "OPTIONS" then
        response.status = 200
        response.body = ""
        return response
    end
    
    -- Routes
    if path == "/music/api/tracks" or path == "/api/tracks" then
        if method == "GET" then
            -- Parse query parameters
            local query = {}
            for k, v in path:gmatch("([^&=?]+)=([^&]+)") do
                query[k] = v
            end
            
            -- Get all tracks or search
            local tracks
            if query.search and query.search ~= "" then
                tracks = search_tracks(query.search)
            else
                tracks = get_all_tracks()
            end
            
            response.status = 200
            response.body = to_json(tracks or {})
        end
    elseif path:match("/music/api/tracks/(%d+)/play") or path:match("/api/tracks/(%d+)/play") then
        local track_id = path:match("/music/api/tracks/(%d+)/play") or path:match("/api/tracks/(%d+)/play")
        if track_id and method == "POST" then
            local success = increment_play_count(tonumber(track_id))
            response.status = success and 200 or 500
            response.body = to_json({ success = success })
        end
    elseif path == "/music/api/stats" or path == "/api/stats" then
        if method == "GET" then
            local stats = get_stats()
            response.status = 200
            response.body = to_json(stats or {})
        end
    end
    
    return response
end

-- Démarrer le serveur HTTP
local function start_server()
    local server = socket.bind(config.host, config.port)
    if not server then
        print("Erreur: Impossible de démarrer le serveur sur " .. config.host .. ":" .. config.port)
        os.exit(1)
    end
    
    server:settimeout(5)
    
    print("Music API Server démarré sur " .. config.host .. ":" .. config.port)
    print("Points de terminaison:")
    print("  GET  /music/api/tracks - Liste de toutes les pistes")
    print("  GET  /music/api/tracks?search=<query> - Rechercher des pistes")
    print("  POST /music/api/tracks/<id>/play - Incrémenter le compteur de lectures")
    print("  GET  /music/api/stats - Statistiques")
    print("\nAppuyez sur Ctrl+C pour arrêter...")
    
    while true do
        local client = server:accept()
        if client then
            client:settimeout(5)
            
            -- Lire la requête
            local request_line = client:receive()
            if not request_line then
                client:close()
            else
            
            local method, path, version = request_line:match("^(%S+) (%S+) HTTP/(%d%.%d)")
            if not method or not path then
                client:send("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
                client:close()
            else
            
            -- Lire les headers
            local headers = {}
            while true do
                local line = client:receive()
                if not line or line == "" then break end
                local key, value = line:match("^(%S+):%s*(.+)")
                if key then
                    headers[key:lower()] = value
                end
            end
            
            -- Lire le body si nécessaire
            local body = ""
            if headers["content-length"] then
                local length = tonumber(headers["content-length"])
                if length > 0 then
                    body = client:receive(length)
                end
            end
            
            -- Traiter la requête
            local response = handle_request(method, path, headers, body)
            
            -- Envoyer la réponse
            client:send("HTTP/1.1 " .. response.status .. " " .. get_status_message(response.status) .. "\r\n")
            
            for key, value in pairs(response.headers or {}) do
                client:send(key .. ": " .. value .. "\r\n")
            end
            
            client:send("Content-Length: " .. #response.body .. "\r\n")
            client:send("\r\n")
            client:send(response.body)
            
            client:close()
            end
            end
        end
        
        -- continue
    end
end

-- Démarrer
start_server()
