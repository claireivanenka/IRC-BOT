#!/usr/bin/env lua
-- Music API Server pour le player web
-- Serveur HTTP simple pour servir les données musicales depuis PostgreSQL

local luasql = require "luasql.postgres"
local json = require "json"
local socket = require "socket"
local ltn12 = require "ltn12"
local http = require "socket.http"

-- Configuration
local config = {
    host = "127.0.0.1",
    port = 8080,
    music_dir = "/var/lib/irc_bot/music",
    base_url = "http://localhost:8080/music"
}

-- Charger la configuration depuis config_custom.lua si elle existe
local config_file = io.open("/home/claire/IRC-BOT/config_custom.lua", "r")
if config_file then
    local custom_config = loadstring(config_file:read("*a"))()
    config.host = custom_config.server and custom_config.server.host or config.host
    config.port = custom_config.server and custom_config.server.port or config.port
    config.music_dir = custom_config.music and custom_config.music.music_dir or config.music_dir
    config.base_url = custom_config.music and custom_config.music.base_url or config.base_url
    config_file:close()
end

-- Connexion à la base de données PostgreSQL
local function get_db_connection()
    local env = luasql.postgres()
    local conn = env:connect(
        "irc_bot",
        "irc_user",
        "irc_password",
        "localhost",
        "5432"
    )
    if not conn then
        print("Erreur: Impossible de se connecter à PostgreSQL")
        os.exit(1)
    end
    return conn, env
end

-- Exécuter une requête SQL
local function execute_query(conn, query, params)
    local cursor = conn:execute(query, params or {})
    if not cursor then
        return nil, conn:errmsg()
    end
    return cursor
end

-- Récupérer toutes les pistes
local function get_all_tracks()
    local conn, env = get_db_connection()
    if not conn then return nil end
    
    local tracks = {}
    local cursor, err = execute_query(conn, "SELECT * FROM tracks ORDER BY titre ASC")
    if not cursor then
        print("Erreur lors de la récupération des pistes:", err)
        conn:close()
        env:close()
        return nil
    end
    
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
            url_streaming = row.url_streaming or "",
            hash_fichier = row.hash_fichier or "",
            ajoute_par = row.ajoute_par or "",
            date_ajout = row.date_ajout or "",
            nb_lectures = tonumber(row.nb_lectures) or 0,
            geoip = row.geoip or "",
            ip_address = row.ip_address or ""
        }
        row = cursor:fetch({}, "a")
    end
    
    cursor:close()
    conn:close()
    env:close()
    return tracks
end

-- Récupérer une piste par ID
local function get_track_by_id(id)
    local conn, env = get_db_connection()
    if not conn then return nil end
    
    local cursor, err = execute_query(conn, 
        "SELECT * FROM tracks WHERE id = $1", {id})
    if not cursor then
        print("Erreur lors de la récupération de la piste:", err)
        conn:close()
        env:close()
        return nil
    end
    
    local row = cursor:fetch({}, "a")
    cursor:close()
    conn:close()
    env:close()
    
    if not row then return nil end
    
    return {
        id = tonumber(row.id),
        titre = row.titre or "",
        artiste = row.artiste or "",
        album = row.album or "",
        annee = tonumber(row.annee) or 0,
        genre = row.genre or "",
        duree = tonumber(row.duree) or 0,
        chemin_fichier = row.chemin_fichier or "",
        url_streaming = row.url_streaming or "",
        hash_fichier = row.hash_fichier or "",
        ajoute_par = row.ajoute_par or "",
        date_ajout = row.date_ajout or "",
        nb_lectures = tonumber(row.nb_lectures) or 0,
        geoip = row.geoip or "",
        ip_address = row.ip_address or ""
    }
end

-- Rechercher des pistes
local function search_tracks(query)
    local conn, env = get_db_connection()
    if not conn then return nil end
    
    local search_pattern = "%" .. query .. "%"
    local tracks = {}
    local cursor, err = execute_query(conn, 
        "SELECT * FROM tracks WHERE titre ILIKE $1 OR artiste ILIKE $1 OR album ILIKE $1 OR genre ILIKE $1 ORDER BY titre ASC",
        {search_pattern})
    if not cursor then
        print("Erreur lors de la recherche:", err)
        conn:close()
        env:close()
        return nil
    end
    
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
            url_streaming = row.url_streaming or "",
            hash_fichier = row.hash_fichier or "",
            ajoute_par = row.ajoute_par or "",
            date_ajout = row.date_ajout or "",
            nb_lectures = tonumber(row.nb_lectures) or 0,
            geoip = row.geoip or "",
            ip_address = row.ip_address or ""
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
    
    local success, err = conn:execute("UPDATE tracks SET nb_lectures = nb_lectures + 1 WHERE id = $1", {id})
    conn:close()
    env:close()
    
    return success ~= nil
end

-- Récupérer les statistiques
local function get_stats()
    local conn, env = get_db_connection()
    if not conn then return nil end
    
    local stats = {}
    
    -- Top 10 des pistes les plus écoutées
    local cursor, err = execute_query(conn, 
        "SELECT * FROM tracks ORDER BY nb_lectures DESC LIMIT 10")
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
    
    -- Nombre total de pistes
    cursor, err = execute_query(conn, "SELECT COUNT(*) as count FROM tracks")
    if cursor then
        local row = cursor:fetch({}, "a")
        stats.total_tracks = tonumber(row.count) or 0
        cursor:close()
    end
    
    -- Nombre total de lectures
    cursor, err = execute_query(conn, "SELECT SUM(nb_lectures) as total FROM tracks")
    if cursor then
        local row = cursor:fetch({}, "a")
        stats.total_plays = tonumber(row.total) or 0
        cursor:close()
    end
    
    conn:close()
    env:close()
    return stats
end

-- Générer l'URL de streaming pour une piste
local function get_stream_url(track)
    if track.url_streaming and track.url_streaming ~= "" then
        return track.url_streaming
    end
    
    -- Utiliser le hash comme nom de fichier
    if track.hash_fichier and track.hash_fichier ~= "" then
        return config.base_url .. "/stream/" .. track.hash_fichier .. "?file=" .. track.titre
    end
    
    -- Utiliser le chemin fichier
    if track.chemin_fichier and track.chemin_fichier ~= "" then
        return config.base_url .. "/stream/" .. track.hash_fichier
    end
    
    return ""
end

-- Traitement des requêtes HTTP
local function handle_request(method, path, headers, body)
    local response = {}
    
    -- CORS
    response.headers = {
        ["Content-Type"] = "application/json",
        ["Access-Control-Allow-Origin"] = "*",
        ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
        ["Access-Control-Allow-Headers"] = "Content-Type"
    }
    
    -- Préflight
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
            
            -- Add stream URLs
            for i, track in ipairs(tracks or {}) do
                tracks[i].url_streaming = get_stream_url(track)
            end
            
            response.status = 200
            response.body = json.encode(tracks or {})
        elseif method == "POST" then
            -- Add a new track (not implemented in this API)
            response.status = 501
            response.body = json.encode({ error = "Not implemented" })
        end
    elseif path:match("/music/api/tracks/(%d+)/play") or path:match("/api/tracks/(%d+)/play") then
        local track_id = path:match("/music/api/tracks/(%d+)/play") or path:match("/api/tracks/(%d+)/play")
        if track_id and method == "POST" then
            local success = increment_play_count(tonumber(track_id))
            response.status = success and 200 or 500
            response.body = json.encode({ success = success })
        end
    elseif path == "/music/api/stats" or path == "/api/stats" then
        if method == "GET" then
            local stats = get_stats()
            response.status = 200
            response.body = json.encode(stats or {})
        end
    else
        response.status = 404
        response.body = json.encode({ error = "Not found" })
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
    
    while true do
        local client = server:accept()
        if client then
            client:settimeout(5)
            
            -- Lire la requête
            local request_line = client:receive()
            if not request_line then
                client:close()
                
            end
            
            local method, path, version = request_line:match("^(%S+) (%S+) HTTP/(%d%.%d)")
            if not method or not path then
                client:send("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
                client:close()
                
            end
            
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
            client:send("HTTP/1.1 " .. response.status .. " " .. 

-- Fonction pour obtenir le message de status
local function get_status_message(status)
    local messages = {[200]="OK", [400]="Bad Request", [404]="Not Found", [500]="Internal Server Error", [501]="Not Implemented"}
    return messages[status] or "Unknown"
end
                get_status_message(response.status) .. "\r\n")
            
            for key, value in pairs(response.headers or {}) do
                client:send(key .. ": " .. value .. "\r\n")
            end
            
            client:send("Content-Length: " .. #response.body .. "\r\n")
            client:send("\r\n")
            client:send(response.body)
            
            client:close()
        end
        
        -- continue
    end
end

-- Vérifier les dépendances
local function check_dependencies()
    local required = {
        {"luasql.postgres", "luasql-postgres"},
        {"json", "Lua JSON"},
        {"socket", "LuaSocket"}
    }
    
    for i, dep in ipairs(required) do
        local module = dep[1]
        local name = dep[2]
        local ok, err = pcall(require, module)
        if not ok then
            print("Erreur: " .. name .. " est requis. Installez-le avec:")
            print("  luarocks install " .. module)
            os.exit(1)
        end
    end
end

-- Point d'entrée
check_dependencies()
start_server()
