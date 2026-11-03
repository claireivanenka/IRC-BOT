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
config = {
    -- === CONNEXION IRC ===
    server = "irc.libera.chat",     -- Serveur IRC (irc.libera.chat, irc.oftc.net, etc.)
    port = 6667,                     -- Port (6697 pour SSL)
    use_ssl = false,                -- true pour SSL (port 6697)
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
        enabled = true,            -- Activer PostgreSQL (true) ou utiliser fichier local (false)
        driver = "postgres",      -- Driver de la base de données
        host = "localhost",       -- Adresse du serveur PostgreSQL
        port = 5432,              -- Port PostgreSQL
        database = "irc_bot",     -- Nom de la base de données
        user = "irc_user",        -- Nom d'utilisateur PostgreSQL
        password = "irc_password", -- Mot de passe PostgreSQL
        menus_table = "custom_menus" -- Nom de la table pour les menus
    },
}

-- Charger la configuration personnalisée si elle existe
local custom_config_file = io.open("config_custom.lua", "r")
if custom_config_file then
    custom_config_file:close()
    local custom_config = dofile("config_custom.lua")
    if custom_config and type(custom_config) == "table" then
        -- Fusionner les configurations
        for k, v in pairs(custom_config) do
            if type(v) == "table" and config[k] and type(config[k]) == "table" then
                -- Fusion profonde pour les tables
                for k2, v2 in pairs(v) do
                    config[k][k2] = v2
                end
            else
                config[k] = v
            end
        end
        print("✓ Configuration personnalisée chargée depuis config_custom.lua")
    end
end

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
db_env = nil
db_conn = nil

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
    
    local result = db_conn:execute([[
        CREATE TABLE IF NOT EXISTS ]] .. config.database.menus_table .. [[ (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            created_by VARCHAR(255) NOT NULL
        )
    ]])
    
    -- result peut être un curseur (pour SELECT) ou un nombre (pour CREATE/INSERT)
    -- Si c'est un curseur, le fermer
    if result and type(result) == "userdata" then
        result:close()
    end
    print("✓ Table " .. config.database.menus_table .. " prête")
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
custom_menus = {}

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
                -- Filtrer les menus invalides (sans nom)
                custom_menus = {}
                for _, menu in ipairs(loaded_menus) do
                    if menu.name and menu.name ~= "" then
                        table.insert(custom_menus, menu)
                    end
                end
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
    
    local exists = false
    if cursor then
        exists = cursor:fetch() ~= nil
        cursor:close()
    end
    
    local result
    if exists then
        -- Update
        result = db_conn:execute(
            "UPDATE " .. config.database.menus_table .. " SET " ..
            "content = '" .. escape_sql(menu.content) .. "', " ..
            "created_by = '" .. escape_sql(menu.created_by) .. "' " ..
            "WHERE name = '" .. escape_sql(menu.name) .. "'"
        )
    else
        -- Insert
        result = db_conn:execute(
            "INSERT INTO " .. config.database.menus_table .. " " ..
            "(name, content, created_at, created_by) VALUES (" ..
            "'" .. escape_sql(menu.name) .. "', " ..
            "'" .. escape_sql(menu.content) .. "', " ..
            "NOW(), '" .. escape_sql(menu.created_by) .. "')"
        )
    end
    
    -- result peut être un curseur (pour SELECT) ou un nombre (pour UPDATE/INSERT)
    if result and type(result) == "userdata" then
        result:close()
    end
    return true
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
    
    local result = db_conn:execute(
        "DELETE FROM " .. config.database.menus_table .. 
        " WHERE name = '" .. escape_sql(name) .. "'"
    )
    
    -- result peut être un curseur (pour SELECT) ou un nombre (pour DELETE)
    -- Si c'est un curseur, le fermer
    if result and type(result) == "userdata" then
        local affected = result:numrows() or 0
        result:close()
        return affected > 0
    end
    return false
end

-- Sauvegarder une URL nettoyée dans PostgreSQL
function save_cleaned_url(original_url, cleaned_url, cleaned_by)
    if not db_conn then return false end
    
    local function escape_sql(str)
        return (str or ""):gsub("'", "''")
    end
    
    -- Vérifier si l'URL originale existe déjà
    local check_success, check_exists = pcall(function()
        local cursor = db_conn:execute(
            "SELECT 1 FROM cleaned_urls WHERE original_url = '" .. escape_sql(original_url) .. "'"
        )
        if cursor then
            local row = cursor:fetch({}, 'a')
            cursor:close()
            return row ~= nil
        end
        return false
    end)
    
    if not check_success or check_exists then
        return false
    end
    
    -- Extraire le domaine et obtenir l'IP
    local domain = extract_domain(cleaned_url)
    local ip = get_ip_address(domain)
    
    -- Insérer la nouvelle URL nettoyée avec IP
    local insert_success, insert_result = pcall(function()
        local result = db_conn:execute(
            "INSERT INTO cleaned_urls (original_url, cleaned_url, created_at, cleaned_by, ip_address) VALUES (" ..
            "'" .. escape_sql(original_url) .. "', " ..
            "'" .. escape_sql(cleaned_url) .. "', " ..
            "NOW(), '" .. escape_sql(cleaned_by) .. "', '" .. escape_sql(ip) .. "')"
        )
        if result and type(result) == "userdata" then
            result:close()
        end
        return true
    end)
    
    return insert_success or false
end

-- Charger les URLs nettoyées depuis PostgreSQL
function load_cleaned_urls()
    if not db_conn then return {} end
    
    local urls = {}
    local cursor = db_conn:execute(
        "SELECT original_url, cleaned_url, EXTRACT(EPOCH FROM created_at) as created_at, cleaned_by, ip_address " ..
        "FROM cleaned_urls ORDER BY created_at DESC"
    )
    
    if cursor then
        local row = cursor:fetch({}, "a")
        while row do
            table.insert(urls, {
                original_url = row.original_url,
                cleaned_url = row.cleaned_url,
                created_at = tonumber(row.created_at) or os.time(),
                cleaned_by = row.cleaned_by,
                ip_address = row.ip_address or "N/A"
            })
            row = cursor:fetch(row, "a")
        end
        cursor:close()
    end
    return urls
end

-- Lister les URLs nettoyées
function list_cleaned_urls(limit)
    local urls = load_cleaned_urls()
    limit = limit or 10  -- Par défaut, afficher les 10 dernières
    
    if #urls == 0 then
        return "Aucune URL n'a été nettoyée pour l'instant."
    end
    
    -- Prendre les plus récentes (déjà triées par date)
    local recent_urls = {}
    for i = 1, math.min(limit, #urls) do
        table.insert(recent_urls, urls[i])
    end
    
    local output = "🔍 **URLs nettoyées** (" .. #urls .. " total, " .. #recent_urls .. " affichées) :\n"
    for i, url in ipairs(recent_urls) do
        local ts = format_timestamp(url.created_at)
        local original_short = shorten_url(url.original_url, 35)
        local cleaned_short = shorten_url(url.cleaned_url, 35)
        local ip = url.ip_address or "N/A"
        output = output .. string.format("%d. **%s** → %s [IP:%s] *(par %s, %s)*\n", 
            i, original_short, cleaned_short, ip, url.cleaned_by, ts)
    end
    return output
end

-- Lister les URLs nettoyées avec toutes les informations (format brut de la base)
function list_cleaned_urls_raw(limit)
    if not db_conn then
        return "❌ Base de données non disponible"
    end
    
    limit = limit or 10
    
    local cursor = db_conn:execute(
        "SELECT id, original_url, cleaned_url, created_at, cleaned_by, ip_address " ..
        "FROM cleaned_urls ORDER BY created_at DESC" .. (limit and " LIMIT " .. limit or "")
    )
    
    if not cursor then
        return "❌ Erreur lors de la requête"
    end
    
    local row = cursor:fetch({}, 'a')
    if not row then
        cursor:close()
        return "Aucune URL trouvée dans la base de données"
    end
    
    local count_cursor = db_conn:execute("SELECT COUNT(*) as total FROM cleaned_urls")
    local total = 0
    if count_cursor then
        local count_row = count_cursor:fetch({}, 'a')
        if count_row then
            total = tonumber(count_row.total) or 0
        end
        count_cursor:close()
    end
    
    local output = "🗄️ **Contenu de la base PostgreSQL** (cleaned_urls, " .. total .. " entrées): "
    local i = 0
    while row do
        i = i + 1
        local ts = format_timestamp(tonumber(row.created_at) or os.time())
        local orig_short = shorten_url(row.original_url, 40)
        local cleaned_short = shorten_url(row.cleaned_url, 40)
        output = output .. string.format("%d.[ID:%s,Orig:%s,Net:%s,IP:%s,Par:%s,Date:%s] ",
            i, row.id, orig_short, cleaned_short, row.ip_address or 'N/A', row.cleaned_by, ts)
        row = cursor:fetch(row, 'a')
        if limit and i >= limit then break end
    end
    cursor:close()
    
    return output
end

-- Lister les requêtes DNS depuis PostgreSQL
function list_dns_queries(limit)
    if not db_conn then
        return "❌ Base de données non disponible"
    end
    
    limit = limit or 10
    
    local query = "SELECT id, domain, ip_address, hostname, resolved_at, query_time, status, requested_by " ..
                   "FROM dns_queries ORDER BY resolved_at DESC" .. (limit and " LIMIT " .. limit or "")
    
    local cursor = db_conn:execute(query)
    
    if not cursor then
        return "❌ Erreur lors de la requête DNS"
    end
    
    local row = cursor:fetch({}, 'a')
    if not row then
        cursor:close()
        return "Aucune requête DNS trouvée"
    end
    
    local count_cursor = db_conn:execute("SELECT COUNT(*) as total FROM dns_queries")
    local total = 0
    if count_cursor then
        local count_row = count_cursor:fetch({}, 'a')
        if count_row then
            total = tonumber(count_row.total) or 0
        end
        count_cursor:close()
    end
    
    local output = "🔍 **Requêtes DNS** (" .. total .. " total, " .. limit .. " affichées): "
    local i = 0
    while row do
        i = i + 1
        local domain_short = shorten_url(row.domain, 30)
        local ip = row.ip_address or 'N/A'
        local status = row.status or 'UNKNOWN'
        local requested_by = row.requested_by or 'unknown'
        local query_time = row.query_time or 0
        output = output .. string.format(" | %s->%s[%sms](%s)", domain_short, ip, query_time, status)
        row = cursor:fetch(row, 'a')
        if limit and i >= limit then break end
    end
    cursor:close()
    
    return output
end

-- Fonction utilitaire pour raccourcir les URLs
function shorten_url(url, max_length)
    max_length = max_length or 50
    if #url <= max_length then
        return url
    else
        return url:sub(1, max_length - 3) .. "..."
    end
end

-- Fonction utilitaire pour extraire le domaine d'une URL
function extract_domain(url)
    -- Supprimer le protocole (http://, https://)
    local domain = url:gsub("^%a+://", "")
    -- Supprimer le chemin et les paramètres
    domain = domain:gsub("/[^?#]*", "")
    domain = domain:gsub("?[^%s]*", "")
    domain = domain:gsub("#[^%s]*", "")
    -- Supprimer les espaces et retours à la ligne
    domain = domain:gsub("%s+", "")
    return domain
end

-- Fonction utilitaire pour obtenir l'adresse IP d'un domaine
function get_ip_address(domain)
    if not domain or domain == "" then return "N/A" end
    
    -- Si c'est déjà une IP
    if domain:match("^%d+%.%d+%.%d+%.%d+$") then
        return domain
    end
    
    local socket = require("socket")
    local ok, ip = pcall(function()
        return socket.dns.toip(domain)
    end)
    
    return ok and ip or "N/A"
end

-- Sauvegarder une requête DNS dans PostgreSQL
function save_dns_query(domain, ip_address, requested_by)
    if not db or not domain then return end
    
    local hostname = "N/A"
    local start_time = os.time()
    
    -- Résolution DNS
    local resolved_ip = ip_address or get_ip_address(domain)
    local end_time = os.time()
    local query_time = end_time - start_time
    local status = resolved_ip ~= "N/A" and "SUCCESS" or "FAILED"
    
    local query = string.format(
        "INSERT INTO dns_queries (domain, ip_address, hostname, resolved_at, query_time, status, requested_by) VALUES ($1, $2, $3, NOW(), %d, $4, $5)",
        query_time
    )
    
    local ok, err = pcall(function()
        local res = assert(db:execute(query, domain, resolved_ip, hostname, status, requested_by))
        return res
    end)
    
    if not ok then
        log_message("[DBG] Erreur sauvegarde DNS: " .. tostring(err))
    else
        log_message(string.format("[DBG] DNS sauvegardée: %s -> %s (par %s)", domain, resolved_ip, requested_by))
    end
end

-- =====================================================================
-- FONCTIONS PUBLIQUES POUR LES MENUS
-- =====================================================================

-- Ajouter un menu personnalisé
function add_custom_menu(name, content, creator)
    -- Vérifier que le nom n'existe pas déjà et générer un nom unique si nécessaire
    local final_name = name
    local iteration = 1
    
    -- Trouver si le nom existe déjà et quel est le plus haut numéro d'itération
    for _, menu in ipairs(custom_menus) do
        if menu.name:lower() == name:lower() then
            -- Nom existe déjà, trouver un nom unique avec itération
            iteration = iteration + 1
            final_name = name .. "_" .. iteration
            -- Vérifier si ce nouveau nom existe aussi (peu probable mais possible)
            for _, m in ipairs(custom_menus) do
                if m.name:lower() == final_name:lower() then
                    iteration = iteration + 1
                    final_name = name .. "_" .. iteration
                end
            end
        end
    end
    
    local new_menu = {
        name = final_name,
        content = content,
        created_at = os.time(),
        created_by = creator or "inconnu"
    }
    
    table.insert(custom_menus, new_menu)
    
    -- Trier automatiquement par date (du plus récent au plus ancien)
    table.sort(custom_menus, function(a, b)
        return (a.created_at or 0) > (b.created_at or 0)
    end)
    
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
-- @param sort_by: nil (par défaut, ordre d'insertion), "date" (du plus récent au plus ancien), "name" (alphabétique), "creator" (par créateur)
function list_custom_menus(sort_by)
    -- Filtrer les menus sans nom (pour éviter les entrées corrompues)
    local valid_menus = {}
    for _, menu in ipairs(custom_menus) do
        if menu.name and menu.name ~= "" then
            table.insert(valid_menus, menu)
        end
    end
    
    if #valid_menus == 0 then
        return "Aucun menu personnalisé n'a été créé."
    end
    
    -- Trier selon le paramètre
    if sort_by == "date" then
        table.sort(valid_menus, function(a, b)
            return (a.created_at or 0) > (b.created_at or 0)  -- Plus récent en premier
        end)
    elseif sort_by == "name" then
        table.sort(valid_menus, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
    elseif sort_by == "creator" then
        table.sort(valid_menus, function(a, b)
            return (a.created_by or ""):lower() < (b.created_by or ""):lower()
        end)
    end
    
    local count = #valid_menus
    local output = "📋 **Menus personnalisés** (" .. count .. ") : "
    local menu_list = {}
    for i, menu in ipairs(valid_menus) do
        table.insert(menu_list, string.format("%d. **%s** *(par %s)* - %s", 
            i, menu.name, menu.created_by or "inconnu", format_timestamp(menu.created_at or os.time())))
    end
    output = output .. table.concat(menu_list, " | ")
    return output
end

-- Afficher un menu personnalisé
function show_custom_menu(name)
    for _, menu in ipairs(custom_menus) do
        if menu.name:lower() == name:lower() then
            local timestamp = format_timestamp(menu.created_at)
            return string.format("=== Menu: %s ===\n👤 Créé par: %s\n⏰ Le: %s\n\n📝 %s", 
                menu.name, menu.created_by, timestamp, menu.content)
        end
    end
    return "❌ Menu non trouvé: " .. name
end

-- =====================================================================
-- Fonctions utilitaires
-- =====================================================================

-- Nettoyer une URL YouTube en supprimant les trackers
function clean_youtube_url(url, requested_by)
    -- Vérifier que c'est bien une URL YouTube
    if not url:match("youtube%.com") and not url:match("youtu%.be/") then
        return "⚠️  Ce n'est pas une URL YouTube valide.", nil
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
    
    local cleaned_url
    if video_id then
        -- Reconstruire l'URL propre
        cleaned_url = "https://www.youtube.com/watch?v=" .. video_id
    elseif url:match("youtube%.com") then
        -- Si on n'a pas trouvé d'ID mais que c'est une URL youtube.com
        -- Retourner l'URL nettoyée (sans paramètres)
        local clean = url:match("^(https?://[^/]+/[^%?#]+)") or url
        cleaned_url = clean:gsub("?.*", ""):gsub("#.*", "")
    else
        cleaned_url = url
    end
    
    -- Extraire le domaine pour la requête DNS
    local domain = extract_domain(cleaned_url)
    if domain and requested_by then
        -- Sauvegarder la requête DNS en arrière-plan (ne pas bloquer)
        local co = coroutine.create(function()
            save_dns_query(domain, nil, requested_by)
        end)
        coroutine.resume(co)
    end
    
    return cleaned_url, domain
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

irc_socket = nil
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
            local cleaned, domain = clean_youtube_url(url, nick)
            local ip = get_ip_address(domain)
            send_irc_message(target, nick .. ": " .. cleaned .. " [IP: " .. ip .. "]")
            
            -- Sauvegarder l'URL nettoyée dans PostgreSQL si activé
            if config.database and config.database.enabled and db_conn then
                save_cleaned_url(url, cleaned, nick)
            end
        end
    end
    
    -- Commande : lister les URLs nettoyées (!urls, !lasturls, ou !listurls)
    local urls_match = message:lower():match("^!urls(%s*)")
    local lasturls_match = message:lower():match("^!lasturls(%s*)")
    local listurls_match = message:lower():match("^!listurls(%s*)")
    if urls_match or lasturls_match then
        local limit_str = urls_match or lasturls_match or ""
        local limit = tonumber(limit_str:match("^%s+(%d+)")) or (lasturls_match and 5 or nil)
        send_irc_message(target, list_cleaned_urls(limit))
    elseif listurls_match then
        local limit_str = listurls_match or ""
        local limit = tonumber(limit_str:match("^%s+(%d+)")) or nil
        send_irc_message(target, list_cleaned_urls_raw(limit))
    end
    
    -- Commande : lister les requêtes DNS (!dns ou !dnsqueries)
    local dns_match = message:lower():match("^!dns(%s*)")
    local dnsqueries_match = message:lower():match("^!dnsqueries(%s*)")
    if dns_match or dnsqueries_match then
        local limit_str = dns_match or dnsqueries_match or ""
        local limit = tonumber(limit_str:match("^%s+(%d+)")) or nil
        send_irc_message(target, list_dns_queries(limit))
    end
    
    -- Commande : menu (menu par défaut)
    if message:match("!menu") then
        local category = message:match("!menu (%S+)") or "tout"
        send_irc_message(target, show_menu(category))
    end
    
    -- Commande : aide
    if message:match("!help") or message:match("!aide") then
        local help_text = "Commandes disponibles: !clean <url> - nettoyer une URL YouTube | !urls [N] - lister les URLs nettoyées | !lasturls [N] - dernières URLs | !listurls [N] - afficher le contenu brut de la base PostgreSQL | !dns [N] - lister les requêtes DNS | !menu [boire|manger] - afficher le menu | " ..
                         "!addmenu <nom> <texte> - créer un menu | !delmenu <nom> - supprimer un menu | " ..
                         "!listmenus [date|name|creator] - lister les menus | !showmenu <nom> - afficher un menu | !date - afficher la date | !ping - tester le bot | !help - aide"
        send_irc_message(target, help_text)
    end
    
    -- Commande : ping (vérifier que le bot est vivant)
    if message:lower():match("^!ping$") then
        send_irc_message(target, nick .. ": 🏓 Pong ! Le bot est bien vivant ! ⏱️")
    end
    
    -- Commande : date (affiche la date et l'heure)
    if message:lower():match("^!date$") then
        local current_date = os.date("%a %b %d %H:%M:%S %Y")
        send_irc_message(target, "📅 Date: " .. current_date)
        log_message("CMD", nick, "a demandé la date")
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
                    send_irc_message(target, nick .. ": ✅ Menu '" .. menu.name .. "' créé avec succès ! (par " .. nick .. ", " .. ts .. ")")
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
    
    -- Lister les menus : !listmenus [date|name|creator] ou !listmenu [date|name|creator]
    local list_match = message:lower():match("^!listmenus(%s*)")
    local listmenu_match = message:lower():match("^!listmenu(%s*)")
    if list_match or listmenu_match then
        local sort_by = nil
        if list_match ~= "" then
            sort_by = list_match:match("^%s+(%S+)")
        elseif listmenu_match ~= "" then
            sort_by = listmenu_match:match("^%s+(%S+)")
        end
        send_irc_message(target, list_custom_menus(sort_by))
    end
    
    -- Afficher un menu : !showmenu NomDuMenu ou !listmenu NomDuMenu
    local showmenu_match = message:lower():match("^!showmenu (%S+)") or message:lower():match("^!listmenu (%S+)")
    if showmenu_match then
        local result = show_custom_menu(showmenu_match)
        send_irc_message(target, result)
    elseif message:lower():match("^!showmenu$") then
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
    send_irc_message(config.channel, welcome_msg .. " Commandes: !clean <url>, !urls, !lasturls, !listurls, !menu, !addmenu, !listmenus, !showmenu, !delmenu, !date, !ping, !help")
    
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
    print("  !urls [N]       - Lister les URLs nettoyées")
    print("  !lasturls [N]   - Lister les N dernières URLs nettoyées (défaut: 5)")
    print("  !listurls [N]   - Afficher le contenu brut de la base PostgreSQL")
    print("  !menu [boire|manger] - Afficher le menu")
    print("  !addmenu <nom> <texte> - Créer un menu personnalisé")
    print("  !listmenus [date|name|creator] - Lister les menus personnalisés (par date, nom ou créateur)")
    print("  !showmenu <nom>  - Afficher un menu personnalisé")
    print("  !delmenu <nom>   - Supprimer un menu personnalisé")
    print("  !date            - Afficher la date et l'heure")
    print("  !ping            - Tester si le bot répond")
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
                        local ok, err = pcall(handle_message, msg)
                        if not ok then
                            log_message("ERR", "handle_message", err)
                            print("⚠️  Erreur dans handle_message: " .. err)
                        end
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
