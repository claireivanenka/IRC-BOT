-- =====================================================================
-- IRC Bot en Lua - Nettoyage YouTube, Menu, Date horaire
-- Utilise lua-socket (disponible via apt: lua-socket)
-- =====================================================================

-- Configuration
local config = {
    server = "irc.libera.chat",     -- Serveur IRC (ex: irc.libera.chat, irc.freenode.net)
    port = 6667,                     -- Port (6697 pour SSL)
    nick = "YouTubeCleanBot",        -- Nom du bot
    user = "youtube_clean_bot",     -- Identifiant utilisateur
    realname = "Bot de nettoyage YouTube et Menu",
    channel = "#test",               -- Channel principal
    -- Si vous voulez utiliser SSL (port 6697)
    use_ssl = false,
}

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
    irc_socket:settimeout(0.1)  -- Timeout court pour vérifier régulièrement
    
    local result, err = irc_socket:connect(config.server, config.port)
    if not result then
        print("Erreur de connexion: " .. err)
        return false
    end
    
    if config.use_ssl then
        irc_socket = ssl.wrap(irc_socket, {mode = "client", protocol = "tlsv1_2"})
        irc_socket:handshake()
    end
    
    -- Authentification
    irc_socket:send("NICK " .. config.nick .. "\r\n")
    irc_socket:send("USER " .. config.user .. " 0 * :" .. config.realname .. "\r\n")
    
    connected = true
    print("Connecté au serveur IRC")
    return true
end

-- Envoyer un message IRC
function send_irc_message(target, message)
    if not connected or not irc_socket then return end
    irc_socket:send("PRIVMSG " .. target .. " :" .. message .. "\r\n")
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
    -- Se connecter
    if not connect_irc() then
        return
    end
    
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
    send_irc_message(config.channel, "🤖 Bot démarré ! Commandes: !clean <url>, !menu, !help")
    
    -- Boucle principale
    print("Bot démarré. Appuyez sur Ctrl+C pour arrêter.")
    print("Commandes disponibles:")
    print("  !clean <url> - Nettoyer une URL YouTube")
    print("  !menu [boire|manger] - Afficher le menu")
    print("  !help - Aide")
    
    while connected do
        -- Lire les messages
        local line = irc_socket:receive()
        if line then
            local msg = parse_irc_message(line)
            if msg then
                if msg.type == "message" then
                    handle_message(msg)
                end
            end
        end
        
        -- Vérifier les tâches horaires
        check_hourly_task()
        
        -- Petit délai pour éviter la surcharge
        socket.sleep(0.1)
    end
end

-- Gestion des erreurs
function handle_error(err)
    print("Erreur: " .. err)
    disconnect()
    os.exit(1)
end

-- Exécuter le bot
local ok, err = pcall(main)
if not ok then
    handle_error(err)
end
