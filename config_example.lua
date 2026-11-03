-- =====================================================================
-- EXEMPLE DE CONFIGURATION POUR IRC-BOT
-- =====================================================================
--
-- Ce fichier montre la configuration COMPLÈTE pour utiliser le bot sur
-- Libera.Chat avec le channel #fauve.
--
-- INSTRUCTIONS :
-- 1. Copie ce fichier en config_custom.lua
-- 2. Modifie les valeurs selon tes besoins
-- 3. Requires('config_custom') dans irc_bot.lua (ou modifie directement irc_bot.lua)
--
-- =====================================================================

-- =====================================================================
-- CONFIGURATION DE BASE
-- =====================================================================

return {
    -- Serveur IRC
    server = "irc.libera.chat",
    port = 6667,
    use_ssl = false,  -- true pour SSL (port 6697)
    
    -- Identité du bot
    nick = "titoune",           -- DOIT être enregistré sur Libera.Chat
    user = "titoune",           -- Identifiant (généralement = nick)
    realname = "Bot YouTube Cleaner et Menu",
    
    -- Channel
    channel = "#fauve",         -- DOIT exister (crée-le avec /join #fauve)
    
    -- =====================================================================
    -- IDENTIFICATION NICKSERV (OBLIGATOIRE SUR LIBERA.CHAT)
    -- =====================================================================
    --
    -- Pour enregistrer ton nick sur Libera.Chat :
    -- 1. Connecte-toi avec un client IRC
    -- 2. /MSG NickServ REGISTER ton@email.com ton_mot_de_passe
    -- 3. Vérifie ton email et valide avec le code reçu
    -- 4. /MSG NickServ VERIFY REGISTER ton_nick code_de_verification
    --
    -- Une fois enregistré, configure ici :
    --
    nickserv = {
        enabled = true,            -- ACTIVE CECI !
        password = "ton_mot_de_passe_nickserv",  -- Mot de passe que tu as choisi
        wait_time = 5,              -- Temps d'attente avant identification (secondes)
    },
    
    -- =====================================================================
    -- CONFIGURATION DU LOGGING
    -- =====================================================================
    logging = {
        enabled = true,              -- Activer les logs
        filename = "irc_bot.log",    -- Fichier de log
        max_size = 10 * 1024 * 1024,  -- 10 Mo
        max_files = 5,               -- 5 backups max
        log_incoming = true,         -- Logger messages entrants
        log_outgoing = true,         -- Logger messages sortants
        log_pings = false,           -- Logger PING/PONG
        log_errors = true,           -- Logger les erreurs
    },
    
    -- =====================================================================
    -- TÂCHES PLANIFIÉES
    -- =====================================================================
    hourly_date = true,  -- Exécuter /exec -o date chaque heure ronde
}

-- =====================================================================
-- CONFIGURATION POUR AUTRES SERVEURS
-- =====================================================================
--
-- OFTC (pas besoin de NickServ) :
-- return {
--     server = "irc.oftc.net",
--     port = 6667,
--     nick = "MonBot",
--     channel = "#test",
--     nickserv = {enabled = false},
-- }
--
-- Freenode (avec SSL) :
-- return {
--     server = "irc.freenode.net",
--     port = 6697,
--     use_ssl = true,
--     nick = "MonBot",
--     nickserv = {enabled = true, password = "mot_de_passe"},
-- }
--
-- =====================================================================
-- COMMENT UTILISER CE FICHIER
-- =====================================================================
--
-- 1. Copie ce fichier :
--    cp config_example.lua config_custom.lua
--
-- 2. Édite config_custom.lua avec tes informations
--
-- 3. Dans irc_bot.lua, charge la configuration :
--    local custom_config = dofile("config_custom.lua") or {}
--    for k, v in pairs(custom_config) do
--        config[k] = v
--    end
--
-- 4. Ou simplement modifie directement irc_bot.lua
--
-- =====================================================================