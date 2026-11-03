-- =====================================================================
-- IRC Bot en Lua - Nettoyage YouTube, Menu, Date horaire
-- Utilise lua-socket (disponible via apt: lua-socket)
-- =====================================================================

-- =====================================================================
-- CONFIGURATION COMPLÈTE RECOMMANDÉE POUR LIBERA.CHAT
-- =====================================================================
--
-- 📌 POUR UTILISER CE BOT SUR LIBERA.CHAT :
-- 1. Enregistre ton nick avec : /MSG NickServ REGISTER ton@email.com ton_mot_de_passe
-- 2. Vérifie ton email et valide avec : /MSG NickServ VERIFY REGISTER ton_nick code_de_verification
-- 3. Crée ton channel avec : /join #ton-channel
-- 4. Configure config.nick, config.nickserv.password, et config.channel
--
-- =====================================================================

-- Configuration
local config = {
    -- === CONNEXION IRC ===
    server = "irc.libera.chat",     -- Serveur IRC (irc.libera.chat, irc.oftc.net, etc.)
    port = 6667,                     -- Port (6697 pour SSL)
    use_ssl = false,                 -- true pour SSL (port 6697)
    
    -- === IDENTITÉ DU BOT ===
    nick = "titoune",               -- Nom du bot (DOIT être enregistré sur Libera.Chat)
    user = "titoune",               -- Identifiant utilisateur (généralement = nick)
    realname = "Bot YouTube Cleaner et Menu",  -- Nom affiché
    
    -- === CANAUX ===
    channel = "#fauve",             -- Channel principal à rejoindre (DOIT exister)
    
    -- === IDENTIFICATION NICKSERV (NÉCESSAIRE POUR LIBERA.CHAT) ===
    -- ⚠️  SI TON NICK EST ENREGISTRÉ, ACTIVE CECI :
    nickserv = {
        enabled = true,            -- true pour activer l'identification automatique
        password = "JusteVivreHeureuse€2029",  -- Mot de passe NickServ
        wait_time = 5,              -- Temps d'attente avant identification (secondes)
    },
    
    -- === LOGGING (JOURNAUX) ===
    logging = {
        enabled = true,              -- Activer/désactiver le logging
        filename = "irc_bot.log",    -- Nom du fichier de log
        max_size = 10 * 1024 * 1024,  -- Taille max (10 Mo)
        max_files = 5,               -- Nombre max de backups (irc_bot.log.1, .2, etc.)
        log_incoming = true,         -- Logger les messages entrants
        log_outgoing = true,         -- Logger les messages sortants
        log_pings = false,           -- Logger les PING/PONG
        log_errors = true,           -- Logger les erreurs
    },
    
    -- === TÂCHES PLANIFIÉES ===
    hourly_date = true,              -- Exécuter /exec -o date chaque heure ronde
    
    -- === BASE DE DONNÉES (PostgreSQL) ===
    -- Configuration pour sauvegarder les menus dans PostgreSQL
    -- Pour activer : change enabled = true et configure les paramètres
    database = {
        enabled = false,           -- Activer PostgreSQL (true) ou utiliser fichier local (false)
        driver = "postgres",      -- Driver de la base de données
        host = "localhost",       -- Adresse du serveur PostgreSQL
        port = 5432,              -- Port PostgreSQL
        database = "irc_bot",     -- Nom de la base de données
        user = "irc_bot",         -- Nom d'utilisateur PostgreSQL
        password = "",            -- Mot de passe PostgreSQL
        menus_table = "custom_menus" -- Nom de la table pour les menus
    }
}

-- =====================================================================
-- EXEMPLES DE CONFIGURATION POUR AUTRES SERVEURS
-- =====================================================================
--
-- Pour OFTC (pas besoin de NickServ) :
-- config = {
--     server = "irc.oftc.net",
--     port = 6667,
--     nick = "MonBot",
--     channel = "#test",
--     nickserv = {enabled = false},
-- }
--
-- Pour Freenode (avec SSL) :
-- config = {
--     server = "irc.freenode.net",
--     port = 6697,
--     use_ssl = true,
--     nick = "MonBot",
--     nickserv = {enabled = true, password = "mot_de_passe"},
-- }
--
-- =====================================================================

-- =====================================================================
-- Système de Logging
-- =====================================================================

local log_file = nil
local current_log_size = 0

-- Initialiser le logging
function init_logging()
    if not config.logging.enabled then return end
    
    -- Vérifier si on doit faire une rotation
    rotate_logs()
    
    -- Ouvrir le fichier de log en mode append
    log_file = io.open(config.logging.filename, "a")
    if log_file then
        -- Calculer la taille actuelle
        local info = log_file:seek("end")
        current_log_size = info or 0
        log_file:seek("set")
        
        -- Écrire l'en-tête
        log_file:write("\n" .. string.rep("=", 60) .. "\n")
        log_file:write("  DEMARRAGE DU BOT - " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        log_file:write(string.rep("=", 60) .. "\n\n")
        log_file:flush()
        print("✓ Logging activé : " .. config.logging.filename)
    else
        print("⚠️ Impossible d'ouvrir le fichier de log : " .. config.logging.filename)
    end
end

-- Fermer le logging
function close_logging()
    if log_file then
        log_file:write("\n" .. string.rep("-", 60) .. "\n")
        log_file:write("  ARRET DU BOT - " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        log_file:write(string.rep("-", 60) .. "\n")
        log_file:close()
        log_file = nil
    end
end

-- Rotation des logs
function rotate_logs()
    if not config.logging.enabled then return end
    
    -- Vérifier si le fichier existe et sa taille
    local file = io.open(config.logging.filename, "r")
    if file then
        local size = file:seek("end")
        file:close()
        
        -- Si le fichier dépasse la taille max, faire une rotation
        if size > config.logging.max_size then
            -- Fermer le fichier actuel si ouvert
            if log_file then
                log_file:close()
                log_file = nil
            end
            
            -- Renommer les fichiers existants
            for i = config.logging.max_files - 1, 1, -1 do
                local old_name = config.logging.filename .. "." .. i
                local new_name = config.logging.filename .. "." .. (i + 1)
                
                -- Supprimer le plus ancien si il existe
                if i + 1 == config.logging.max_files then
                    os.remove(new_name)
                end
                
                -- Renommer
                local f = io.open(old_name, "r")
                if f then
                    f:close()
                    os.rename(old_name, new_name)
                end
            end
            
            -- Renommer le fichier actuel
            os.rename(config.logging.filename, config.logging.filename .. ".1")
        end
    end
end

-- Vérifier si un fichier existe
function file_exists(name)
    local f = io.open(name, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- =====================================================================
-- BASE DE DONNÉES POSTGRESQL
-- =====================================================================

-- Variables globales pour la connexion PostgreSQL
local luasql = nil
local db_env = nil
local db_conn = nil

-- Initialiser la connexion PostgreSQL
function init_database()
    if not config.database or not config.database.enabled then
        return false
    end
    
    -- Charger le module luasql
    local ok, err = pcall(function() luasql = require("luasql.postgres") end)
    if not ok then
        print("⚠️ Impossible de charger luasql.postgres: " .. err)
        print("   Installez-le avec: sudo apt install lua-luasql-postgres")
        return false
    end
    
    -- Créer l'environnement
    db_env = luasql.postgres()
    if not db_env then
        print("⚠️ Impossible de créer l'environnement PostgreSQL")
        return false
    end
    
    -- Se connecter à la base de données
    local conn_str = string.format("host=%s port=%d dbname=%s user=%s password=%s",
        config.database.host,
        config.database.port,
        config.database.database,
        config.database.user,
        config.database.password)
    
    db_conn = db_env:connect(conn_str)
    if not db_conn then
        print("⚠️ Impossible de se connecter à PostgreSQL")
        print("   Vérifiez: host, port, database, user, password")
        return false
    end
    
    print("✓ Connecté à PostgreSQL")
    log_message("SYS", "Database", "Connecté à PostgreSQL")
    
    -- Créer la table si elle n'existe pas
    create_menus_table()
    
    return true
end

-- Créer la table des menus si elle n'existe pas
function create_menus_table()
    if not db_conn then return end
    
    local cursor = db_conn:execute([[
        CREATE TABLE IF NOT EXISTS ]] .. config.database.menus_table .. [[ (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            created_by VARCHAR(255) NOT NULL
        )
    ]])
    
    if cursor then
        cursor:close()
        print("✓ Table " .. config.database.menus_table .. " prête")
    end
end

-- Fermer la connexion PostgreSQL
function close_database()
    if db_conn then
        db_conn:close()
        db_conn = nil
    end
    if db_env then
        db_env:close()
        db_env = nil
    end
    if luasql then
        luasql = nil
    end
end

-- Écrire dans le log
function log_message(type, source, message)
    if not config.logging.enabled or not log_file then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_line = string.format("[%s] [%s] %s: %s\n", timestamp, type, source, message)
    
    log_file:write(log_line)
    log_file:flush()
    
    -- Mettre à jour la taille
    current_log_size = current_log_size + #log_line
    
    -- Vérifier si on doit faire une rotation
    if current_log_size > config.logging.max_size then
        close_logging()
        rotate_logs()
        init_logging()
    end
end

-- Menu boissons et nourriture
local menu = {
    boissons = {
        {"Café", 2.50},
        {"Thé", 2.00},
        {"Jus d'orange", 3.00},
        {"Soda", 2.75},
        {"Eau", 1.50},
        {"Bière", 4.50},
        {"Vin", 6.00},
    },
    nourriture = {
        {"Croissant", 3.00},
        {"Sandwich", 7.50},
        {"Salade", 8.00},
        {"Pizza", 12.00},
        {"Burger", 10.00},
        {"Frites", 4.00},
        {"Tarte aux pommes", 5.50},
    }
}

-- =====================================================================
-- MENUS PERSONNALISÉS AVEC HORODATAGE
-- =====================================================================

-- Table pour stocker les menus personnalisés
-- Structure: {name = nom, content = contenu, created_at = timestamp, created_by = nick}
local custom_menus = {}

-- Fichier de sauvegarde des menus
local custom_menus_file = "custom_menus.dat"

-- Charger les menus personnalisés (choisit entre PostgreSQL et fichier)
function load_custom_menus()
    if config.database and config.database.enabled and db_conn then
        load_custom_menus_from_pg()
    else
        load_custom_menus_from_file()
    end
end

-- Sauvegarder les menus (postgreSQL ou fichier selon config)
function save_custom_menus()
    if config.database and config.database.enabled and db_conn then
        for _, menu in ipairs(custom_menus) do
            save_custom_menu_to_pg(menu)
        end
        print("✓ " .. #custom_menus .. " menu(s) sauvegardé(s) en PostgreSQL")
        log_message("SYS", "Menus", #custom_menus .. " menu(s) sauvegardé(s) en PostgreSQL")
    else
        save_custom_menus_to_file()
    end
end

-- Charger les menus depuis le fichier local (fallback)
function load_custom_menus_from_file()
    local file = io.open(custom_menus_file, "r")
    if not file then return end
    
    local content = file:read("*a")
    file:close()
    
    if content and content ~= "" then
        local chunk = loadstring("return " .. content)
        if chunk then
            local ok, loaded_menus = pcall(chunk)
            if ok and type(loaded_menus) == "table" then
                custom_menus = loaded_menus
                print("✓ " .. #custom_menus .. " menu(s) chargé(s) depuis " .. custom_menus_file)
                log_message("SYS", "Menus", #custom_menus .. " menu(s) chargé(s) depuis fichier")
            end
        end
    end
end

-- Formater un timestamp en date lisible
function format_timestamp(ts)
    return os.date("%Y-%m-%d %H:%M:%S", ts or os.time())
end

-- =====================================================================
-- FONCTIONS DE SAUVEGARDE DES MENUS (Fichier local)
-- =====================================================================

-- Sauvegarder les menus dans un fichier local
function save_custom_menus_to_file()
    local file = io.open(custom_menus_file, "w")
    if file then
        local serialization = "{"
        for i, menu in ipairs(custom_menus) do
            if i > 1 then serialization = serialization .. "," end
            serialization = serialization .. string.format(
                "\n    {name=%q, content=%q, created_at=%d, created_by=%q}",
                menu.name, menu.content, menu.created_at, menu.created_by
            )
        end
        serialization = serialization .. "\n}"
        file:write(serialization)
        file:close()
        print("✓ " .. #custom_menus .. " menu(s) sauvegardé(s) dans " .. custom_menus_file)
        log_message("SYS", "Menus", #custom_menus .. " menu(s) sauvegardé(s) dans fichier")
    else
        print("⚠️ Impossible de sauvegarder les menus dans " .. custom_menus_file)
    end
end

-- =====================================================================
-- FONCTIONS DE SAUVEGARDE DES MENUS (PostgreSQL)
-- =====================================================================

-- Sauvegarder un menu dans PostgreSQL
function save_custom_menu_to_pg(menu)
    if not db_conn then return false end
    
    -- Échappement des apostrophes pour SQL
    local function escape_sql(str)
        return (str or ""):gsub("'", "''")
    end
    
    -- Vérifier si le menu existe déjà
    local cursor = db_conn:execute(
        "SELECT 1 FROM " .. config.database.menus_table .. 
        " WHERE name = '" .. escape_sql(menu.name) .. "'"
    )
    
    if cursor and cursor:fetch() then
        -- Update
        cursor:close()
        cursor = db_conn:execute(
            "UPDATE " .. config.database.menus_table .. " SET " ..
            "content = '" .. escape_sql(menu.content) .. "', " ..
            "created_by = '" .. escape_sql(menu.created_by) .. "' " ..
            "WHERE name = '" .. escape_sql(menu.name) .. "'"
        )
    else
        -- Insert
        if cursor then cursor:close() end
        cursor = db_conn:execute(
            "INSERT INTO " .. config.database.menus_table .. " " ..
            "(name, content, created_at, created_by) VALUES (" ..
            "'" .. escape_sql(menu.name) .. "', " ..
            "'" .. escape_sql(menu.content) .. "', " ..
            "NOW(), '" .. escape_sql(menu.created_by) .. "')"
        )
    end
    
    if cursor then
        cursor:close()
        return true
    end
    return false
end

-- Charger les menus depuis PostgreSQL
function load_custom_menus_from_pg()
    if not db_conn then return end
    
    local cursor = db_conn:execute(
        "SELECT name, content, EXTRACT(EPOCH FROM created_at) as created_at, created_by " ..
        "FROM " .. config.database.menus_table .. " ORDER BY created_at DESC"
    )
    
    if cursor then
        local row = cursor:fetch({}, "a")
        while row do
            table.insert(custom_menus, {
                name = row.name,
                content = row.content,
                created_at = tonumber(row.created_at) or os.time(),
                created_by = row.created_by
            })
            row = cursor:fetch(row, "a")
        end
        cursor:close()
        print("✓ " .. #custom_menus .. " menu(s) chargé(s) depuis PostgreSQL")
        log_message("SYS", "Menus", #custom_menus .. " menu(s) chargé(s) depuis PostgreSQL")
    end
end

-- Supprimer un menu de PostgreSQL
function delete_custom_menu_from_pg(name)
    if not db_conn then return false end
    
    local function escape_sql(str)
        return (str or ""):gsub("'", "''")
    end
    
    local cursor = db_conn:execute(
        "DELETE FROM " .. config.database.menus_table .. 
        " WHERE name = '" .. escape_sql(name) .. "'"
    )
    
    if cursor then
        local affected = cursor:numrows() or 0
        cursor:close()
        return affected > 0
    end
    return false
end

-- =====================================================================
-- FONCTIONS PUBLIQUES POUR LES MENUS
-- =====================================================================

-- Ajouter un menu personnalisé
function add_custom_menu(name, content, creator)
    -- Vérifier que le nom n'existe pas déjà
    for _, menu in ipairs(custom_menus) do
        if menu.name:lower() == name:lower() then
            return nil, "Un menu avec ce nom existe déjà"
        end
    end
    
    local new_menu = {
        name = name,
        content = content,
        created_at = os.time(),
        created_by = creator or "inconnu"
    }
    
    table.insert(custom_menus, new_menu)
    
    -- Sauvegarder selon la configuration
    if config.database and config.database.enabled and db_conn then
        save_custom_menu_to_pg(new_menu)
    else
        save_custom_menus_to_file()
    end
    
    return new_menu, "Menu ajouté avec succès"
end

-- Supprimer un menu personnalisé
function delete_custom_menu(name)
    for i, menu in ipairs(custom_menus) do
        if menu.name:lower() == name:lower() then
            table.remove(custom_menus, i)
            
            -- Sauvegarder selon la configuration
            if config.database and config.database.enabled and db_conn then
                delete_custom_menu_from_pg(name)
            else
                save_custom_menus_to_file()
            end
            
            return true, "Menu supprimé"
        end
    end
    return false, "Menu non trouvé"
end

-- Lister tous les menus personnalisés
function list_custom_menus()
    if #custom_menus == 0 then
        return "Aucun menu personnalisé n'a été créé."
    end
    
    local count = #custom_menus
    local output = "📋 **Menus personnalisés** (" .. count .. ") :\n"
    for i, menu in ipairs(custom_menus) do
        output = output .. string.format("%d. **%s** - Créé par %s le %s\n", 
            i, menu.name, menu.created_by, format_timestamp(menu.created_at))
    end
    output = output .. "\nUtilisez !showmenu <nom> pour afficher un menu, !delmenu <nom> pour le supprimer"
    return output
end

-- Afficher un menu personnalisé
function show_custom_menu(name)
    for _, menu in ipairs(custom_menus) do
        if menu.name:lower() == name:lower() then
            local timestamp = format_timestamp(menu.created_at)
            return string.format("=== Menu: %s ===\nCréé par %s le %s\n\n%s", 
                menu.name, menu.created_by, timestamp, menu.content)
        end
    end
    return "❌ Menu non trouvé: " .. name
end

-- =====================================================================
-- Fonctions utilitaires
-- =====================================================================

-- Nettoyer une URL YouTube en supprimant les trackers
function clean_youtube_url(url)
    -- Vérifier que c'est bien une URL YouTube
    if not url:match("youtube%.com") and not url:match("youtu%.be/") then
        return "⚠️  Ce n'est pas une URL YouTube valide."
    end

    -- Remplacer youtu.be/ par youtube.com/watch?v=
    url = url:gsub("youtu%.be/([%w_-]+)", "youtube.com/watch?v=%1")
    
    -- Extraire l'ID vidéo depuis différentes formes d'URL
    local video_id = url:match("v=([%w_-]+)") 
                    or url:match("youtube%.com/embed/([%w_-]+)") 
                    or url:match("youtube%.com/watch/([%w_-]+)")
                    or url:match("youtube%.com/v/([%w_-]+)")
                    or url:match("youtube%.com/shorts/([%w_-]+)")
                    or url:match("youtu%.be/([%w_-]+)")
    
    if video_id then
        -- Reconstruire l'URL propre
        return "https://www.youtube.com/watch?v=" .. video_id
    end
    
    -- Si on n'a pas trouvé d'ID mais que c'est une URL youtube.com
    -- Retourner l'URL nettoyée (sans paramètres)
    if url:match("youtube%.com") then
        local clean = url:match("^(https?://[^/]+/[^%?#]+)") or url
        return clean:gsub("?.*", ""):gsub("#.*", "")
    end
    
    return url
end

-- Afficher le menu
function show_menu(category)
    local output = "=== Menu ==="
    
    if category == "boissons" or category == "boire" then
        output = output .. "\n🥤 **BOISSONS** 🥤\n"
        for i, item in ipairs(menu.boissons) do
            output = output .. string.format("%d. %s - €%.2f\n", i, item[1], item[2])
        end
    elseif category == "nourriture" or category == "manger" then
        output = output .. "\n🍔 **NOURRITURE** 🍔\n"
        for i, item in ipairs(menu.nourriture) do
            output = output .. string.format("%d. %s - €%.2f\n", i, item[1], item[2])
        end
    else
        output = output .. "\n🥤 **BOISSONS** 🥤\n"
        for i, item in ipairs(menu.boissons) do
            output = output .. string.format("%d. %s - €%.2f\n", i, item[1], item[2])
        end
        output = output .. "\n🍔 **NOURRITURE** 🍔\n"
        for i, item in ipairs(menu.nourriture) do
            output = output .. string.format("%d. %s - €%.2f\n", i, item[1], item[2])
        end
        output = output .. "\nUtilisation: !menu [boire|manger|tout]"
    end
    
    return output
end

-- =====================================================================
-- Gestion IRC
-- =====================================================================

local socket = require("socket")
local tcp = socket.tcp
local ltn12 = require("ltn12")
local ssl = nil
if config.use_ssl then
    ssl = require("ssl")
end

local irc_socket = nil
local connected = false
local last_hour = nil

-- Se connecter au serveur IRC
function connect_irc()
    print("Connexion à " .. config.server .. ":" .. config.port .. "...")
    
    irc_socket = tcp()
    irc_socket:settimeout(5)  -- Timeout plus long pour la connexion initiale
    
    local result, err = irc_socket:connect(config.server, config.port)
    if not result then
        print("❌ Erreur de connexion: " .. err)
        log_message("ERR", "Connection", "Erreur: " .. err)
        return false
    end
    
    -- Réduire le timeout pour la lecture des messages
    irc_socket:settimeout(0.5)
    
    if config.use_ssl then
        irc_socket = ssl.wrap(irc_socket, {mode = "client", protocol = "tlsv1_2"})
        local ok, ssl_err = pcall(function() irc_socket:handshake() end)
        if not ok then
            print("❌ Erreur SSL: " .. ssl_err)
            log_message("ERR", "SSL", ssl_err)
            return false
        end
    end
    
    -- Authentification
    irc_socket:send("NICK " .. config.nick .. "\r\n")
    irc_socket:send("USER " .. config.user .. " 0 * :" .. config.realname .. "\r\n")
    
    -- Identification automatique à NickServ si configuré
    -- ⚠️ CRITIQUE SUR LIBERA.CHAT: Sans identification, le bot sera déconnecté après quelques minutes
    if config.nickserv and config.nickserv.enabled and config.nickserv.password then
        print("⏳ Attente avant identification NickServ...")
        socket.sleep(config.nickserv.wait_time or 5)  -- Attendre 5 secondes pour la stabilité
        irc_socket:send("PRIVMSG NickServ :IDENTIFY " .. config.nickserv.password .. "\r\n")
        print("✓ Identification NickServ envoyée pour " .. config.nick)
        log_message("SYS", "NickServ", "Identification envoyée pour " .. config.nick)
    else
        print("⚠️  ⚠️  ⚠️ ATTENTION: NickServ N'EST PAS CONFIGURÉ !")
        print("    Sur Libera.Chat, ton bot sera déconnecté après quelques minutes.")
        print("    Pour configurer NickServ:")
        print("      1. Enregistre ton nick: /MSG NickServ REGISTER ton@email.com ton_mot_de_passe")
        print("      2. Valide avec le code reçu par email")
        print("      3. Dans irc_bot.lua, configure:")
        print("         config.nickserv = {enabled = true, password = 'ton_mot_de_passe'}")
        print("    ⚠️  ⚠️  ⚠️")
    end
    
    connected = true
    print("✓ Connecté au serveur IRC")
    log_message("SYS", "Connection", "Connecté à " .. config.server .. ":" .. config.port)
    return true
end

-- Envoyer un message IRC
function send_irc_message(target, message)
    if not connected or not irc_socket then return end
    irc_socket:send("PRIVMSG " .. target .. " :" .. message .. "\r\n")
    
    -- Logger le message sortant
    if config.logging.enabled and config.logging.log_outgoing then
        log_message("OUT", config.nick .. " -> " .. target, message)
    end
end

-- Rejoindre un channel
function join_channel(channel)
    if not connected or not irc_socket then return end
    irc_socket:send("JOIN " .. channel .. "\r\n")
    print("Rejoint le channel: " .. channel)
end

-- Quitter un channel
function part_channel(channel)
    if not connected or not irc_socket then return end
    irc_socket:send("PART " .. channel .. "\r\n")
end

-- Déconnecter
function disconnect()
    if connected and irc_socket then
        irc_socket:send("QUIT :Bot arrêté\r\n")
        irc_socket:close()
        connected = false
        print("Déconnecté du serveur IRC")
        log_message("SYS", "Connection", "Déconnecté du serveur IRC")
    end
end

-- Parser les messages IRC
function parse_irc_message(line)
    if not line or line == "" then return nil end
    
    -- Supprimer le 

    line = line:gsub("\r", "")
    
    -- Vérifier les codes PING
    if line:match("^PING :(.+)") then
        local token = line:match("^PING :(.+)")
        irc_socket:send("PONG :" .. token .. "\r\n")
        
        -- Logger les PING/PONG
        if config.logging.enabled and config.logging.log_pings then
            log_message("PING", "Server", token)
        end
        
        return {type = "ping"}
    end
    
    -- Parser les messages PRIVMSG
    local prefix, command, params = line:match("^(:[^ ]+) ([^ ]+) (.+)")
    
    if command == "PRIVMSG" then
        local target = params:match("^([^ ]+)")
        local message = params:match(" :(.+)") or ""
        local nick = prefix:match("^:([^!]+)") or ""
        
        return {
            type = "message",
            nick = nick,
            target = target,
            message = message
        }
    end
    
    -- Parser les messages JOIN
    if command == "JOIN" then
        local nick = prefix:match("^:([^!]+)") or ""
        local channel = params:match("^([^ ]+)")
        return {type = "join", nick = nick, channel = channel}
    end
    
    -- Parser les messages de bienvenue (fin de la connexion)
    if line:find("001") or line:find("002") or line:find("003") or line:find("004") then
        -- Logger la connexion réussie
        if config.logging.enabled then
            log_message("SYS", "Server", "Message de bienvenue reçu (code " .. (line:match("(%d+)") or "unknown") .. ")")
        end
        return {type = "welcome"}
    end
    
    return nil
end

-- Traiter un message
function handle_message(msg)
    if not msg or msg.type ~= "message" then return end
    
    -- Ignorer les messages du bot lui-même
    if msg.nick == config.nick then return end
    
    local message = msg.message
    local target = msg.target
    local nick = msg.nick
    
    -- Logger le message entrant
    if config.logging.enabled and config.logging.log_incoming then
        log_message("IN", nick .. " -> " .. target, message)
    end
    
    -- Commande : nettoyer une URL YouTube
    if message:match("!clean %S+") then
        local url = message:match("!clean (%S+)")
        if url then
            local cleaned = clean_youtube_url(url)
            send_irc_message(target, nick .. ": " .. cleaned)
        end
    end
    
    -- Commande : menu (menu par défaut)
    if message:match("!menu") then
        local category = message:match("!menu (%S+)") or "tout"
        send_irc_message(target, show_menu(category))
    end
    
    -- Commande : aide
    if message:match("!help") or message:match("!aide") then
        local help_text = "Commandes disponibles: !clean <url> - nettoyer une URL YouTube | !menu [boire|manger] - afficher le menu | " ..
                         "!addmenu <nom> <texte> - créer un menu | !delmenu <nom> - supprimer un menu | " ..
                         "!listmenus - lister les menus | !showmenu <nom> - afficher un menu | !help - aide"
        send_irc_message(target, help_text)
    end
    
    -- =====================================================================
    -- COMMANDES DE GESTION DES MENUS PERSONNALISÉS
    -- =====================================================================
    
    -- Ajouter un menu personnalisé : !addmenu NomDuMenu Contenu du menu
    -- Gère les espaces dans le nom et le contenu
    if message:lower():match("^!addmenu %S") then
        -- Trouver le premier espace après !addmenu
        local cmd, rest = message:match("^(.-) (.+)")
        if cmd and rest then
            -- Le nom est le premier mot après !addmenu, le reste est le contenu
            local name = rest:match("^(%S+)")
            local content = rest:match("^%S+ (.+)")
            
            if name and content then
                local menu, err = add_custom_menu(name, content, nick)
                if menu then
                    local ts = format_timestamp(menu.created_at)
                    send_irc_message(target, nick .. ": ✅ Menu '" .. menu.name .. "' créé avec succès ! (" .. ts .. ")")
                else
                    send_irc_message(target, nick .. ": ❌ " .. err)
                end
            else
                send_irc_message(target, nick .. ": ❌ Utilisation: !addmenu <nom> <texte>")
            end
        else
            send_irc_message(target, nick .. ": ❌ Utilisation: !addmenu <nom> <texte>")
        end
    elseif message:lower():match("^!addmenu$") then
        send_irc_message(target, nick .. ": ❌ Utilisation: !addmenu <nom> <texte>")
    end
    
    -- Supprimer un menu : !delmenu NomDuMenu
    local delmenu_match = message:lower():match("^!delmenu (%S+)")
    if delmenu_match then
        local success, msg = delete_custom_menu(delmenu_match)
        send_irc_message(target, nick .. ": " .. (success and "✅ " or "❌ ") .. msg)
    elseif message:lower():match("^!delmenu$") then
        send_irc_message(target, nick .. ": ❌ Utilisation: !delmenu <nom>")
    end
    
    -- Lister les menus : !listmenus ou !listmenu (alias)
    if message:lower():match("^!listmenus$") or message:lower():match("^!listmenu$") then
        send_irc_message(target, list_custom_menus())
    end
    
    -- Afficher un menu : !showmenu NomDuMenu ou !listmenu NomDuMenu (alias)
    local showmenu_match = message:lower():match("^!showmenu (%S+)") or message:lower():match("^!listmenu (%S+)")
    if showmenu_match then
        local result = show_custom_menu(showmenu_match)
        send_irc_message(target, result)
    elseif message:lower():match("^!showmenu$") or message:lower():match("^!listmenu$") then
        send_irc_message(target, nick .. ": ❌ Utilisation: !showmenu <nom> ou !listmenu <nom>")
    end
end

-- Vérifier si c'est une heure ronde
function check_hourly_task()
    local now = os.date("*t")
    local current_hour = now.hour
    local current_minute = now.min
    
    -- Si c'est une heure ronde (minute 0) et que ce n'est pas la même heure que précédemment
    if current_minute == 0 and (last_hour == nil or last_hour ~= current_hour) then
        last_hour = current_hour
        -- Exécuter la commande /exec -o date
        send_irc_message(config.channel, "/exec -o date")
        print("Exécuté: /exec -o date à " .. os.date("%H:%M"))
    end
end

-- =====================================================================
-- Boucle principale
-- =====================================================================

function main()
    -- Initialiser le logging
    init_logging()
    log_message("SYS", "Bot", "Démarrage du bot IRC")
    
    -- Initialiser la base de données (PostgreSQL) si configurée
    if config.database and config.database.enabled then
        if not init_database() then
            print("⚠️  PostgreSQL non disponible, utilise le fichier local")
        end
    end
    
    -- Charger les menus personnalisés sauvegardés
    load_custom_menus()
    
    -- Se connecter
    if not connect_irc() then
        log_message("ERR", "Connection", "Échec de la connexion IRC")
        close_logging()
        return
    end
    
    log_message("SYS", "Connection", "Connecté au serveur " .. config.server .. ":" .. config.port)
    
    -- Attendre la connexion complète (messages de bienvenue)
    print("Attente de la connexion complète...")
    local connected_complete = false
    local tries = 0
    
    while not connected_complete and tries < 100 do
        local line = irc_socket:receive()
        if line then
            if line:find("001") or line:find("002") then
                connected_complete = true
                print("Connexion IRC complète")
            end
            -- Répondre aux PING pendant la connexion
            if line:match("^PING :(.+)") then
                local token = line:match("^PING :(.+)")
                irc_socket:send("PONG :" .. token .. "\r\n")
            end
        end
        socket.sleep(0.1)
        tries = tries + 1
    end
    
    -- Rejoindre le channel
    join_channel(config.channel)
    
    -- Message de bienvenue
    socket.sleep(1)
    
    -- Vérifier si NickServ est configuré
    local welcome_msg = "🤖 Bot démarré !"
    if config.nickserv and config.nickserv.enabled then
        welcome_msg = welcome_msg .. " (NickServ: ✓ Identifié)"
    else
        welcome_msg = welcome_msg .. " (⚠️ NickServ: non configuré)"
    end
    send_irc_message(config.channel, welcome_msg .. " Commandes: !clean <url>, !menu, !help")
    
    -- Afficher les infos dans la console
    print("\n" .. string.rep("=", 60))
    print("  ✓ Bot démarré avec succès !")
    print(string.rep("=", 60))
    print("Serveur:   " .. config.server .. ":" .. config.port)
    print("Nick:      " .. config.nick)
    print("Channel:   " .. config.channel)
    print("Logging:   " .. (config.logging.enabled and "✓ Activé (" .. config.logging.filename .. ")" or "✗ Désactivé"))
    print("NickServ:  " .. (config.nickserv and config.nickserv.enabled and "✓ Configuré" or "✗ Non configuré"))
    print("SSL:       " .. (config.use_ssl and "✓ Activé" or "✗ Désactivé"))
    print(string.rep("=", 60))
    print("\nCommandes disponibles:")
    print("  !clean <url>    - Nettoyer une URL YouTube")
    print("  !menu [boire|manger] - Afficher le menu")
    print("  !help            - Affiche cette aide")
    print("\nPour configurer NickServ (nécessaire sur Libera.Chat):")
    print("  1. Enregistre ton nick: /MSG NickServ REGISTER ton@email.com ton_mot_de_passe")
    print("  2. Valide avec le code reçu par email")
    print("  3. Dans config.lua: nickserv = {enabled = true, password = 'ton_mot_de_passe'}")
    print("  4. Redémarre le bot")
    print(string.rep("=", 60) .. "\n")
    
    while connected do
        -- Lire les messages
        local line = irc_socket:receive()
        if line then
            -- ⚠️ CORRECTION CRITIQUE: Gestion prioritaire des PING pour éviter le timeout
            -- Le serveur envoie un PING toutes les 5 minutes. Si on ne répond pas, on est déconnecté.
            if line:match("^PING") then
                local token = line:match("^PING :(.+)") or line:match("^PING (%S+)")
                if token then
                    irc_socket:send("PONG :" .. token .. "\r\n")
                    log_message("PING", "Server", "Réponse PONG envoyée pour: " .. token)
                end
            else
                -- Logger la ligne brute (optionnel, pour debug)
                -- log_message("RAW", "Server", line)
                
                local msg = parse_irc_message(line)
                if msg then
                    -- Logger les différents types de messages
                    if msg.type == "message" then
                        handle_message(msg)
                    elseif msg.type == "join" then
                        log_message("JOIN", msg.nick, "a rejoint " .. msg.channel)
                    elseif msg.type == "welcome" then
                        log_message("SYS", "Server", "Messages de bienvenue reçus")
                    end
                end
            end
        else
            -- Timeout sur receive, vérifier si toujours connecté
            -- Cela peut arriver si le serveur ne send rien pendant un moment
            if not connected then
                break
            end
        end
        
        -- Vérifier les tâches horaires
        check_hourly_task()
        
        -- Petit délai pour éviter la surcharge
        socket.sleep(0.1)
    end
    
    -- Fin de la boucle, déconnexion
    log_message("SYS", "Bot", "Fin de la boucle principale")
    save_custom_menus()  -- Sauvegarder les menus avant de quitter
end

-- Gestion des erreurs
function handle_error(err)
    print("Erreur: " .. err)
    log_message("ERR", "System", err)
    if config.database and config.database.enabled then
        close_database()
    end
    save_custom_menus()  -- Sauvegarder les menus avant de quitter
    disconnect()
    close_logging()
    os.exit(1)
end

-- Gestion du signal Ctrl+C
function handle_signal()
    print("\nReçu signal d'arrêt...")
    log_message("SYS", "System", "Arrêt demandé par l'utilisateur (Ctrl+C)")
    if config.database and config.database.enabled then
        close_database()
    end
    disconnect()
    close_logging()
    os.exit(0)
end

-- Exécuter le bot
-- Configurer le gestionnaire de signal pour Ctrl+C (fonctionne sur Unix)
-- Note: Lua standard ne gère pas les signaux, mais on peut utiliser un hack
local function run_main()
    local ok, err = pcall(main)
    if not ok then
        handle_error(err)
    end
end

-- Pour gérer Ctrl+C, nous utilisons une approche simple :
-- L'utilisateur doit appuyer sur Ctrl+C dans le terminal, ce qui enverra SIGINT
-- Nous ne pouvons pas l'intercepter proprement en Lua pur, mais nous pouvons
-- nettoyer à la fin de main()

run_main()

-- Nettoyage final (au cas où main() se terminerait normalement)
close_logging()
