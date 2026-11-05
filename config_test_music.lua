-- Configuration pour tester le module musique
-- Copier ce fichier vers config_custom.lua pour l'utiliser

local music_config = {
    -- =====================================================================
    -- MODULE MUSIQUE
    -- =====================================================================
    music = {
        enabled = true,                   -- Activer le module musique
        music_dir = "/var/lib/irc_bot/music",  -- Répertoire de stockage
        base_url = "http://localhost:8080/music",  -- URL de base
        use_ffprobe = true,               -- Utiliser ffprobe pour les tags
        use_exiftool = false,              -- Utiliser exiftool comme fallback
        max_file_size = 100 * 1024 * 1024,  -- 100 Mo max
        allowed_extensions = {".mp3", ".flac", ".ogg", ".m4a", ".wav", ".aac", ".opus"}
    },
    
    -- =====================================================================
    -- BASE DE DONNÉES POSTGRESQL (déjà configurée)
    -- =====================================================================
    database = {
        enabled = true,
        driver = "postgres",
        host = "localhost",
        port = 5432,
        database = "irc_bot",
        user = "irc_user",
        password = "irc_password"
    },
    
    -- =====================================================================
    -- CONNEXION IRC
    -- =====================================================================
    server = "irc.libera.chat",
    port = 6667,
    use_ssl = false,
    nick = "titoune",
    user = "titoune",
    realname = "Bot IRC avec Module Musique",
    channel = "#fauve",
    nickserv = {
        enabled = true,
        password = "JusteVivre",
        wait_time = 5
    }
}

return music_config
