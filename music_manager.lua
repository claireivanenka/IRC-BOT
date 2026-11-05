-- =====================================================================
-- Module de gestion de la musique pour IRC-BOT
-- =====================================================================

local music_manager = {}

-- =====================================================================
-- Configuration par défaut
-- =====================================================================
music_manager.default_config = {
    enabled = false,
    music_dir = "./music",
    base_url = "http://localhost:8080/music",
    use_ffprobe = true,
    use_exiftool = false,
    max_file_size = 100 * 1024 * 1024,  -- 100 Mo
    allowed_extensions = {
        ".mp3", ".flac", ".ogg", ".m4a", ".wav", ".aac", ".opus"
    }
}

-- =====================================================================
-- Initialisation
-- =====================================================================
function music_manager.init(external_config)
    -- Fusionner avec la configuration principale
    music_manager.config = {}
    for k, v in pairs(music_manager.default_config) do
        music_manager.config[k] = v
    end
    
    -- Charger depuis la config globale si disponible
    if external_config and external_config.music then
        for k, v in pairs(external_config.music) do
            music_manager.config[k] = v
        end
    end
    
    -- Charger depuis _G.config si disponible
    if _G.config and _G.config.music then
        for k, v in pairs(_G.config.music) do
            music_manager.config[k] = v
        end
    end
    
    -- Vérifier la configuration
    if not music_manager.config.enabled then
        return false
    end
    
    -- Créer le répertoire de musique s'il n'existe pas
    local lfs = pcall(require, "lfs")
    if lfs then
        local ok, lfs_module = pcall(require, "lfs")
        if ok then
            local music_dir = music_manager.config.music_dir
            local attrs = lfs_module.attributes(music_dir)
            if not attrs then
                local success, err = lfs_module.mkdir(music_dir)
                if not success then
                    print("⚠️  Impossible de créer le répertoire musique: " .. (err or ""))
                else
                    print("✓ Répertoire musique créé: " .. music_dir)
                end
            end
        end
    end
    
    -- Charger les modules
    music_manager.db = require("music_db")
    music_manager.tags = require("tags")
    
    -- Initialiser la base de données
    local db_ok = music_manager.db.init(_G.config and _G.config.postgres or nil)
    if not db_ok then
        print("⚠️  Impossible d'initialiser la base de données musique")
    end
    
    return true
end

-- =====================================================================
-- Gestion des commandes IRC
-- =====================================================================

-- Table des commandes
music_manager.commands = {
    ["!music"] = {
        description = "Module musique - Utilisez !music help pour l'aide",
        handler = function(nick, channel, args)
            return music_manager.show_help(nick, channel)
        end
    },
    ["!music help"] = {
        description = "Affiche l'aide du module musique",
        handler = function(nick, channel, args)
            return music_manager.show_help(nick, channel)
        end
    },
    ["!music add"] = {
        description = "Ajoute une piste à la bibliothèque",
        usage = "!music add <chemin|URL>",
        handler = function(nick, channel, args)
            return music_manager.add_track(nick, channel, args)
        end
    },
    ["!music search"] = {
        description = "Recherche des pistes",
        usage = "!music search <requête>",
        handler = function(nick, channel, args)
            return music_manager.search_tracks(nick, channel, args)
        end
    },
    ["!music info"] = {
        description = "Affiche les informations d'une piste",
        usage = "!music info <id>",
        handler = function(nick, channel, args)
            return music_manager.show_track_info(nick, channel, args)
        end
    },
    ["!music stats"] = {
        description = "Affiche les statistiques de la bibliothèque",
        handler = function(nick, channel, args)
            return music_manager.show_stats(nick, channel)
        end
    },
    ["!music dl"] = {
        description = "Génère un lien de téléchargement",
        usage = "!music dl <id>",
        handler = function(nick, channel, args)
            return music_manager.generate_download_link(nick, channel, args)
        end
    },
    ["!music play"] = {
        description = "Joue une piste (envoie l'URL de streaming)",
        usage = "!music play <id>",
        handler = function(nick, channel, args)
            return music_manager.play_track(nick, channel, args)
        end
    }
}

-- =====================================================================
-- Traitement des commandes
-- =====================================================================

function music_manager.handle_command(nick, channel, message)
    if not music_manager.config.enabled then
        return nil
    end
    
    -- Créer une liste des commandes triées par longueur décroissante
    -- pour que les commandes les plus spécifiques soient testées en premier
    local sorted_commands = {}
    for cmd, info in pairs(music_manager.commands) do
        table.insert(sorted_commands, {cmd = cmd, info = info, len = #cmd})
    end
    
    -- Trier par longueur décroissante
    table.sort(sorted_commands, function(a, b) return a.len > b.len end)
    
    -- Vérifier si le message commence par une commande musique
    for _, entry in ipairs(sorted_commands) do
        local cmd = entry.cmd
        local info = entry.info
        if message:lower():sub(1, #cmd) == cmd:lower() then
            -- Vérifier qu'on a un match exact ou que le caractère suivant est un espace
            local next_char = message:sub(#cmd + 1, #cmd + 1)
            if next_char == "" or next_char == " " then
                local args = message:sub(#cmd + 1):match("^%s*(.*)")
                return info.handler(nick, channel, args)
            end
        end
    end
    
    return nil
end

-- =====================================================================
-- Commandes
-- =====================================================================

function music_manager.show_help(nick, channel)
    local help_lines = {
        "🎵 Commandes du module Musique:",
        "─" .. string.rep("─", 48),
        "!music add <chemin|URL>   - Ajoute une piste avec extraction des tags",
        "!music search <requête>   - Recherche dans la bibliothèque",
        "!music info <id>          - Affiche les informations complètes",
        "!music stats              - Affiche les statistiques",
        "!music dl <id>             - Génère un lien de téléchargement",
        "!music play <id>          - Envoie l'URL de streaming",
        "!music help               - Affiche cette aide",
        "─" .. string.rep("─", 48),
        "Player web: " .. music_manager.config.base_url .. "/player/"
    }
    
    return help_lines
end

function music_manager.add_track(nick, channel, args)
    if not args or args == "" then
        return {"❌ Utilisation: !music add <chemin|URL>"}
    end
    
    local file_path = args:match("^%s*(%S+)")
    if not file_path then
        return {"❌ Veuillez fournir un chemin de fichier ou une URL"}
    end
    
    -- Vérifier si c'est une URL
    local is_url = file_path:match("^https?://") ~= nil
    
    -- Télécharger ou traiter le fichier
    local temp_file
    if is_url then
        -- Pour les URLs, on ne peut pas télécharger directement, on stocke l'URL
        temp_file = file_path
    else
        -- Vérifier que le fichier existe
        local tags_module = music_manager.tags
        if not tags_module.file_exists(file_path) then
            return {"❌ Fichier non trouvé: " .. file_path}
        end
        
        -- Vérifier l'extension
        local extension = file_path:match("%.(%a+)$")
        if extension then
            extension = "." .. extension:lower()
            local allowed = false
            for _, ext in ipairs(music_manager.config.allowed_extensions) do
                if ext == extension then
                    allowed = true
                    break
                end
            end
            if not allowed then
                return {"❌ Extension non autorisée: " .. extension}
            end
        end
        
        -- Vérifier la taille
        local file_size = tags_module.get_file_size(file_path)
        if file_size > music_manager.config.max_file_size then
            return {"❌ Fichier trop grand (max: " .. (music_manager.config.max_file_size / 1024 / 1024) .. " Mo)"}
        end
        
        temp_file = file_path
    end
    
    -- Extraire les métadonnées
    local tags, err = music_manager.tags.read_tags(temp_file)
    if not tags then
        return {"⚠️  Impossible de lire les tags: " .. (err or "erreur inconnue")}
    end
    
    -- Calculer le hash
    local hash = music_manager.calculate_file_hash(temp_file)
    if not hash then
        -- Générer un hash basé sur le chemin si on ne peut pas lire le fichier
        hash = music_manager.simple_hash(temp_file)
    end
    
    -- Préparer les données de la piste
    local track_data = {
        titre = tags.titre or "Inconnu",
        artiste = tags.artiste or "Inconnu",
        album = tags.album or "Inconnu",
        annee = tags.annee or 0,
        genre = tags.genre or "Autre",
        duree = tags.duree or 0,
        bitrate = tags.bitrate or 0,
        chemin_fichier = is_url and temp_file or music_manager.get_relative_path(temp_file),
        hash_fichier = hash,
        ajoute_par = nick,
        nb_lectures = 0
    }
    
    -- Vérifier si la piste existe déjà (par hash)
    local existing = music_manager.db.get_track_by_hash(hash)
    if existing then
        return {"⚠️  Une piste avec ce hash existe déjà (ID: " .. existing.id .. ")"}
    end
    
    -- Sauvegarder dans la base de données
    local track_id = music_manager.db.add_track(track_data)
    if not track_id then
        return {"❌ Impossible d'ajouter la piste"}
    end
    
    -- Générer l'URL de streaming
    local stream_url = music_manager.config.base_url .. "/stream/" .. hash
    
    -- Message de confirmation
    local response = {
        "✅ Piste ajoutée (ID: " .. track_id .. "):",
        "🎵 " .. tags.titre .. " | " .. tags.artiste .. " | " .. tags.album .. " | " .. 
            (tags.annee or "???") .. " | " .. (tags.genre or "Autre") .. " | " .. 
            music_manager.format_duration(tags.duree) .. " | " .. (tags.bitrate or 0) .. " kbps",
        "🔗 Streaming: " .. stream_url,
        "📥 Téléchargement: " .. music_manager.config.base_url .. "/dl/" .. hash .. "?file=" .. 
            string.gsub(tags.titre or "track", "[^%w%-%._]", "_")
    }
    
    return response
end

function music_manager.search_tracks(nick, channel, args)
    if not args or args == "" then
        return {"❌ Utilisation: !music search <requête>"}
    end
    
    local query = args:match("^%s*(%S+)") or args
    local tracks = music_manager.db.search_tracks(query)
    
    if not tracks or #tracks == 0 then
        return {"🔍 Aucune piste trouvée pour: " .. query}
    end
    
    local response = {"🔍 Résultats (" .. (#tracks > 5 and "5+" or #tracks) .. ") pour: " .. query .. ":"}
    
    local max_results = math.min(#tracks, 5)
    for i = 1, max_results do
        local track = tracks[i]
        table.insert(response, string.format("%d. %s - %s [%s, %d, %s, %s]",
            track.id,
            track.titre,
            track.artiste,
            track.album,
            track.annee or 0,
            track.genre,
            music_manager.format_duration(track.duree)
        ))
    end
    
    if #tracks > 5 then
        table.insert(response, "... et " .. (#tracks - 5) .. " autres résultats")
    end
    
    return response
end

function music_manager.show_track_info(nick, channel, args)
    local track_id = tonumber(args:match("^%s*(%d+)") or args)
    if not track_id then
        return {"❌ Utilisation: !music info <id>"}
    end
    
    local track = music_manager.db.get_track_by_id(track_id)
    if not track then
        return {"❌ Piste non trouvée (ID: " .. track_id .. ")"}
    end
    
    local response = {
        "📀 ID: " .. track.id,
        "🎵 Titre: " .. track.titre,
        "🎤 Artiste: " .. track.artiste,
        "💿 Album: " .. track.album,
        "📅 Année: " .. (track.annee or "???"),
        "🎭 Genre: " .. track.genre,
        "⏱️ Durée: " .. music_manager.format_duration(track.duree),
        "🔊 Bitrate: " .. (track.bitrate or 0) .. " kbps",
        "📁 Fichier: " .. track.chemin_fichier,
        "👤 Ajouté par: " .. track.ajoute_par,
        "📅 Date: " .. track.date_ajout,
        "🎧 Lectures: " .. track.nb_lectures,
        "🔗 Hash: " .. track.hash_fichier,
        "🔗 Streaming: " .. music_manager.config.base_url .. "/stream/" .. track.hash_fichier
    }
    
    return response
end

function music_manager.show_stats(nick, channel)
    local stats = music_manager.db.get_stats()
    
    if not stats then
        return {"❌ Impossible de récupérer les statistiques"}
    end
    
    local response = {
        "📊 Statistiques de la bibliothèque:",
        "📁 Total pistes: " .. (stats.total_tracks or 0),
        "🎧 Total lectures: " .. (stats.total_plays or 0)
    }
    
    if stats.top_tracks and #stats.top_tracks > 0 then
        table.insert(response, "🏆 Top " .. (#stats.top_tracks > 10 and "10" or #stats.top_tracks) .. ":")
        for i = 1, math.min(#stats.top_tracks, 10) do
            local track = stats.top_tracks[i]
            table.insert(response, string.format("%d. %s - %s (%d lectures)",
                i, track.titre, track.artiste, track.nb_lectures or 0))
        end
    end
    
    return response
end

function music_manager.generate_download_link(nick, channel, args)
    local track_id = tonumber(args:match("^%s*(%d+)") or args)
    if not track_id then
        return {"❌ Utilisation: !music dl <id>"}
    end
    
    local track = music_manager.db.get_track_by_id(track_id)
    if not track then
        return {"❌ Piste non trouvée (ID: " .. track_id .. ")"}
    end
    
    local filename = string.gsub(track.titre or "track", "[^%w%-%._]", "_") .. ".mp3"
    local url = music_manager.config.base_url .. "/dl/" .. track.hash_fichier .. "?file=" .. filename
    
    return {"📥 Télécharger: " .. url}
end

function music_manager.play_track(nick, channel, args)
    local track_id = tonumber(args:match("^%s*(%d+)") or args)
    if not track_id then
        return {"❌ Utilisation: !music play <id>"}
    end
    
    local track = music_manager.db.get_track_by_id(track_id)
    if not track then
        return {"❌ Piste non trouvée (ID: " .. track_id .. ")"}
    end
    
    -- Incrémenter le compteur de lectures
    music_manager.db.increment_play_count(track_id)
    
    local stream_url = music_manager.config.base_url .. "/stream/" .. track.hash_fichier
    
    return {
        "🎵 Lecture: " .. track.titre .. " - " .. track.artiste .. " (" .. 
            music_manager.format_duration(track.duree) .. ") | " .. stream_url
    }
end

-- =====================================================================
-- Fonctions utilitaires
-- =====================================================================

function music_manager.format_duration(seconds)
    if not seconds or seconds == 0 then return "0:00" end
    
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, secs)
end

function music_manager.calculate_file_hash(file_path)
    local lfs = pcall(require, "lfs")
    if not lfs then return nil end
    
    local lfs_module = require("lfs")
    local file = io.open(file_path, "rb")
    if not file then return nil end
    
    -- Lire le fichier par blocs
    local sha256 = require("sha256")  -- Si disponible
    if not sha256 then
        -- Implémentation simple de hash si sha256 n'est pas disponible
        local crypto = require("crypto")  -- LuaSec
        if crypto then
            local hash = crypto.digest("sha256", "")
            -- Lire le fichier
            local content = file:read("*a")
            file:close()
            if content then
                hash = crypto.digest("sha256", content)
                return hash:lower()
            end
        else
            -- Hash simple basé sur la taille et le nom
            local attrs = lfs_module.attributes(file_path)
            if attrs then
                return music_manager.simple_hash(file_path .. attrs.size)
            end
        end
    end
    
    file:close()
    return nil
end

function music_manager.simple_hash(text)
    -- Génère un hash simple (pas cryptographique)
    local hash = 0
    for i = 1, #text do
        hash = (hash * 31 + string.byte(text, i)) % 16777216
    end
    return string.format("%08x", hash)
end

function music_manager.get_relative_path(file_path)
    local music_dir = music_manager.config.music_dir
    -- Remplacer le chemin absolu par un chemin relatif
    if file_path:sub(1, 1) == "/" then
        return file_path
    end
    return file_path
end

function music_manager.get_stream_url(track)
    if track.url_streaming and track.url_streaming ~= "" then
        return track.url_streaming
    end
    return music_manager.config.base_url .. "/stream/" .. track.hash_fichier
end

-- =====================================================================
-- Export
-- =====================================================================

return music_manager
