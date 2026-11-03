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
    
    -- Commande : menu
    if message:match("!menu") then
        local category = message:match("!menu (%S+)") or "tout"
        send_irc_message(target, show_menu(category))
    end
    
    -- Commande : aide
    if message:match("!help") or message:match("!aide") then
        local help_text = "Commandes disponibles: !clean <url> - nettoyer une URL YouTube | !menu [boire|manger] - afficher le menu | !help - afficher cette aide"
        send_irc_message(target, help_text)
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
end

-- Gestion des erreurs
function handle_error(err)
    print("Erreur: " .. err)
    log_message("ERR", "System", err)
    disconnect()
    close_logging()
    os.exit(1)
end

-- Gestion du signal Ctrl+C
function handle_signal()
    print("\nReçu signal d'arrêt...")
    log_message("SYS", "System", "Arrêt demandé par l'utilisateur (Ctrl+C)")
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
