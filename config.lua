-- =====================================================================
-- Fichier de configuration pour le bot IRC
-- Copiez ce fichier en config_custom.lua et modifiez-le selon vos besoins
-- =====================================================================

return {
    -- Configuration du serveur IRC
    server = {
        host = "irc.libera.chat",
        port = 6667,
        use_ssl = false,          -- true pour SSL (port 6697)
    },
    
    -- Configuration du bot
    bot = {
        nick = "YouTubeCleanBot",
        user = "youtube_clean_bot",
        realname = "Bot de nettoyage YouTube et Menu",
    },
    
    -- Channel(s) à rejoindre (peuvent être plusieurs)
    channels = {
        "#test",
        -- "#autre-channel",
    },
    
    -- Configuration du menu
    menu = {
        boissons = {
            {"Café", 2.50},
            {"Thé", 2.00},
            {"Jus d'orange", 3.00},
            {"Soda", 2.75},
            {"Eau", 1.50},
            {"Bière", 4.50},
            {"Vin", 6.00},
            {"Cocktail", 8.00},
        },
        nourriture = {
            {"Croissant", 3.00},
            {"Pain au chocolat", 3.50},
            {"Sandwich", 7.50},
            {"Salade César", 8.00},
            {"Pizza Margherita", 12.00},
            {"Burger", 10.00},
            {"Frites", 4.00},
            {"Tarte aux pommes", 5.50},
            {"Glace", 4.00},
        }
    },
    
    -- Tâches planifiées
    scheduled_tasks = {
        hourly_date = true,      -- Exécuter /exec -o date chaque heure ronde
    },
    
    -- Préfixe des commandes (par défaut: !)
    command_prefix = "!",
}
