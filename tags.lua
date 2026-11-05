-- =====================================================================
-- Module simplifié de lecture de tags audio
-- Utilise principalement ffprobe pour la compatibilité
-- =====================================================================

local tags = {}

-- =====================================================================
-- Configuration
-- =====================================================================
tags.config = {
    use_ffprobe = true,
    use_exiftool = false,
    ffprobe_path = "ffprobe",
    exiftool_path = "exiftool"
}

-- =====================================================================
-- Fonctions utilitaires
-- =====================================================================

-- Exécuter une commande shell
local function execute_command(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil, "Impossible d'exécuter la commande" end
    local result = handle:read("*a")
    handle:close()
    return result, nil
end

-- Formater la durée (secondes -> MM:SS)
function tags.format_duration(seconds)
    if not seconds or seconds <= 0 then return "0:00" end
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, secs)
end

-- Formater le bitrate (bits/s -> kbps)
function tags.format_bitrate(bitrate)
    if not bitrate or bitrate == 0 then return "0 kbps" end
    return string.format("%.0f kbps", bitrate / 1000)
end

-- =====================================================================
-- Lecture des tags avec ffprobe (méthode recommandée)
-- =====================================================================

function tags.read_with_ffprobe(file_path)
    local cmd = string.format("%s -v quiet -print_format json -show_format -show_streams \"%s\"",
        tags.config.ffprobe_path, file_path)
    
    local result, err = execute_command(cmd)
    if not result or result == "" then
        return nil, "ffprobe a échoué: " .. (err or "erreur inconnue")
    end
    
    -- Parser le JSON manuellement (sans dépendance externe)
    local tags_data = tags.parse_ffprobe_json(result)
    return tags_data, nil
end

-- Parseur JSON simple pour la sortie ffprobe
function tags.parse_ffprobe_json(json_str)
    local data = {
        titre = "",
        artiste = "",
        album = "",
        annee = 0,
        genre = "",
        duree = 0,
        bitrate = 0,
        format = ""
    }
    
    -- Extraire les informations simples sans parser JSON complet
    -- Titre
    local titre = json_str:match('"title"%s*:%s*"([^"]*)"') or
                  json_str:match('"TITLE"%s*:%s*"([^"]*)"')
    if titre then data.titre = titre end
    
    -- Artiste
    local artiste = json_str:match('"artist"%s*:%s*"([^"]*)"') or
                    json_str:match('"ARTIST"%s*:%s*"([^"]*)"')
    if artiste then data.artiste = artiste end
    
    -- Album
    local album = json_str:match('"album"%s*:%s*"([^"]*)"') or
                  json_str:match('"ALBUM"%s*:%s*"([^"]*)"')
    if album then data.album = album end
    
    -- Année (sans parenthèses dans le pattern)
    local year_str = json_str:match('"year"%s*:%s*"(%d%d%d%d)"') or
                     json_str:match('"Year"%s*:%s*"(%d%d%d%d)"') or
                     json_str:match('"date"%s*:%s*"(%d%d%d%d)[^%"]*"') or
                     json_str:match('"Date"%s*:%s*"(%d%d%d%d)[^%"]*"')
    if year_str then data.annee = tonumber(year_str) end
    
    -- Genre
    local genre = json_str:match('"genre"%s*:%s*"([^"]*)"') or
                  json_str:match('"GENRE"%s*:%s*"([^"]*)"')
    if genre then data.genre = genre end
    
    -- Durée (en secondes)
    local duree_str = json_str:match('"duration"%s*:%s*"([%d%.]*)"') or
                      json_str:match('"DURATION"%s*:%s*"([%d%.]*)"')
    if duree_str then data.duree = math.floor(tonumber(duree_str) or 0) end
    
    -- Bitrate (en bits/s)
    local bitrate_str = json_str:match('"bit_rate"%s*:%s*"([%d]*)"') or
                        json_str:match('"bitrate"%s*:%s*"([%d]*)"') or
                        json_str:match('"BIT_RATE"%s*:%s*"([%d]*)"') or
                        json_str:match('"BITRATE"%s*:%s*"([%d]*)"')
    if bitrate_str then data.bitrate = tonumber(bitrate_str) or 0 end
    
    -- Format
    local format = json_str:match('"format_name"%s*:%s*"([^"]*)"') or
                   json_str:match('"FORMAT_NAME"%s*:%s*"([^"]*)"')
    if format then data.format = format end
    
    return data
end

-- =====================================================================
-- Lecture des tags avec exiftool (fallback)
-- =====================================================================

function tags.read_with_exiftool(file_path)
    if not tags.config.use_exiftool then
        return nil, "exiftool désactivé"
    end
    
    local cmd = string.format("%s -json \"%s\"", tags.config.exiftool_path, file_path)
    local result, err = execute_command(cmd)
    if not result or result == "" then
        return nil, "exiftool a échoué: " .. (err or "erreur inconnue")
    end
    
    -- Parser la sortie JSON d'exiftool
    local tags_data = tags.parse_exiftool_json(result)
    return tags_data, nil
end

-- Parseur JSON simple pour exiftool
function tags.parse_exiftool_json(json_str)
    local data = {
        titre = "",
        artiste = "",
        album = "",
        annee = 0,
        genre = "",
        duree = 0,
        bitrate = 0,
        format = ""
    }
    
    -- Extraire les tags simples
    local titre = json_str:match('"Title"%s*:%s*"([^"]*)"') or
                  json_str:match('"title"%s*:%s*"([^"]*)"')
    if titre then data.titre = titre end
    
    local artiste = json_str:match('"Artist"%s*:%s*"([^"]*)"') or
                    json_str:match('"artist"%s*:%s*"([^"]*)"')
    if artiste then data.artiste = artiste end
    
    local album = json_str:match('"Album"%s*:%s*"([^"]*)"') or
                  json_str:match('"album"%s*:%s*"([^"]*)"')
    if album then data.album = album end
    
    local year_str = json_str:match('"Year"%s*:%s*"(%d%d%d%d)"') or
                     json_str:match('"year"%s*:%s*"(%d%d%d%d)"')
    if year_str then data.annee = tonumber(year_str) end
    
    local genre = json_str:match('"Genre"%s*:%s*"([^"]*)"') or
                  json_str:match('"genre"%s*:%s*"([^"]*)"')
    if genre then data.genre = genre end
    
    -- Durée (convertir de la forme HH:MM:SS)
    local duree_str = json_str:match('"Duration"%s*:%s*"([%d:.]*)"') or
                      json_str:match('"duration"%s*:%s*"([%d:.]*)"')
    if duree_str then
        local hours, mins, secs = duree_str:match("(%d+):(%d+):(%d+)")
        if hours then
            data.duree = tonumber(hours) * 3600 + tonumber(mins) * 60 + tonumber(secs)
        else
            local mins, secs = duree_str:match("(%d+):(%d+)")
            if mins then
                data.duree = tonumber(mins) * 60 + tonumber(secs)
            end
        end
    end
    
    return data
end

-- =====================================================================
-- Lecture des tags avec parsing binaire (pour MP3 ID3v1)
-- =====================================================================

function tags.read_with_binary(file_path)
    local file = io.open(file_path, "rb")
    if not file then return nil, "Impossible d'ouvrir le fichier" end
    
    local content = file:read("*a")
    file:close()
    
    if not content or #content < 128 then
        return nil, "Fichier trop court"
    end
    
    -- Chercher le tag ID3v1 à la fin
    if #content >= 128 then
        local tags_data = tags.parse_id3v1(content)
        if tags_data then return tags_data, nil end
    end
    
    return nil, "Aucun tag reconnu trouvé"
end

-- Parser ID3v1 (très simple, 128 derniers bytes)
function tags.parse_id3v1(content)
    local data = {
        titre = "",
        artiste = "",
        album = "",
        annee = 0,
        genre = "",
        duree = 0,
        bitrate = 0,
        format = "MP3"
    }
    
    -- Le tag ID3v1 est aux 128 derniers bytes
    local tag_start = #content - 127
    local tag = content:sub(tag_start)
    
    -- Vérifier le tag "TAG"
    if tag:sub(1, 3) ~= "TAG" then
        return nil
    end
    
    -- Lire les champs (30 bytes chacun)
    data.titre = tag:sub(4, 33):gsub("\0", ""):gsub("%z", "")
    data.artiste = tag:sub(34, 63):gsub("\0", ""):gsub("%z", "")
    data.album = tag:sub(64, 93):gsub("\0", ""):gsub("%z", "")
    data.annee = tonumber(tag:sub(94, 97):gsub("\0", "")) or 0
    -- Genre est un index (byte 128)
    local genre_byte = tag:byte(128)
    if genre_byte >= 0 and genre_byte <= #ttags.GENRES then
        data.genre = ttags.GENRES[genre_byte + 1] or ""
    end
    
    return data
end

-- Liste des genres ID3v1
tags.GENRES = {
    "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop",
    "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B", "Rap",
    "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal",
    "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
    "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip",
    "Gospel", "Noise", "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative"
}

-- =====================================================================
-- Fonction principale de lecture des tags
-- =====================================================================

function tags.read_tags(file_path)
    -- D'abord essayer avec ffprobe (méthode recommandée)
    if tags.config.use_ffprobe then
        local tags_data, err = tags.read_with_ffprobe(file_path)
        if tags_data then
            -- Compléter avec les infos manquantes depuis le parsing binaire
            if tags_data.titre == "" or tags_data.artiste == "" then
                local binary_data = tags.read_with_binary(file_path)
                if binary_data then
                    for k, v in pairs(binary_data) do
                        if tags_data[k] == "" or tags_data[k] == 0 then
                            tags_data[k] = v
                        end
                    end
                end
            end
            return tags_data, nil
        end
    end
    
    -- Si ffprobe échoue, essayer avec exiftool
    if tags.config.use_exiftool then
        local tags_data, err = tags.read_with_exiftool(file_path)
        if tags_data then
            return tags_data, nil
        end
    end
    
    -- Sinon, essayer avec le parsing binaire
    local tags_data, err = tags.read_with_binary(file_path)
    if tags_data then
        return tags_data, nil
    end
    
    -- Si tout échoue, retourner un ensemble de données vide
    return {
        titre = "Inconnu",
        artiste = "Inconnu",
        album = "Inconnu",
        annee = 0,
        genre = "Autre",
        duree = 0,
        bitrate = 0,
        format = "Inconnu"
    }, "Aucune méthode n'a réussi à lire les tags"
end

-- =====================================================================
-- Fonction pour obtenir les informations d'un fichier
-- =====================================================================

function tags.get_file_info(file_path)
    local file = io.open(file_path, "rb")
    if not file then return nil, "Impossible d'ouvrir le fichier" end
    
    local content = file:read("*a")
    file:close()
    
    if not content or #content == 0 then
        return nil, "Fichier vide"
    end
    
    -- Calculer le hash simple (basé sur la taille et le nom)
    local attrs = pcall(require, "lfs") and require("lfs").attributes(file_path)
    local hash
    if attrs then
        hash = string.format("%08x", (attrs.size + string.len(file_path)) % 16777216)
    else
        hash = string.format("%08x", (#content + string.len(file_path)) % 16777216)
    end
    
    -- Obtenir les tags
    local tags_data = tags.read_tags(file_path)
    
    -- Ajouter le hash aux données
    tags_data.hash = hash
    tags_data.file_size = #content
    
    return tags_data, nil
end

-- =====================================================================
-- Export
-- =====================================================================

return tags
