-- tags.lua - Module de lecture des métadonnées audio (ID3v2, FLAC, Vorbis)
-- Part of IRC-BOT project

local tags = {}

-- Format des tags supportés
local SUPPORTED_FORMATS = {
    mp3 = "ID3v2",
    flac = "FLAC/Vorbis",
    ogg = "Vorbis",
    m4a = "MP4",
    wma = "WMA"
}

-- Fonction pour lire un fichier et retourner ses métadonnées
-- @param filepath: chemin du fichier
-- @return: table avec les métadonnées (titre, artiste, album, annee, genre, duree, bitrate), ou nil en cas d'erreur
function tags.read_tags(filepath)
    if not filepath then return nil end
    
    local ext = filepath:match("%.([^%.]+)$") or ""
    ext = ext:lower()
    
    -- Essayer les différents parseurs selon l'extension
    if ext == "mp3" then
        return tags._parse_mp3(filepath)
    elseif ext == "flac" then
        return tags._parse_flac(filepath)
    elseif ext == "ogg" or ext == "oga" then
        return tags._parse_ogg(filepath)
    elseif ext == "m4a" or ext == "mp4" then
        return tags._parse_mp4(filepath)
    else
        -- Essayer ffprobe comme fallback
        return tags._parse_with_ffprobe(filepath)
    end
end

-- Parser MP3 (ID3v2)
function tags._parse_mp3(filepath)
    local f = io.open(filepath, "rb")
    if not f then return nil end
    
    -- Lire le fichier
    local content = f:read("*a")
    f:close()
    
    if not content or #content < 10 then return nil end
    
    -- Chercher la tag ID3v2 (généralement à la fin du fichier)
    -- ID3v2 tag: "ID3" suivi de 2 bytes de version + flags + 4 bytes de taille (big-endian)
    local result = {}
    
    -- Chercher ID3v2 à la fin du fichier
    local id3_pos = content:find("ID3", #content - 128)
    if id3_pos then
        -- Lire la taille de la tag (4 bytes big-endian)
        local size_byte1 = content:byte(id3_pos + 6)
        local size_byte2 = content:byte(id3_pos + 7)
        local size_byte3 = content:byte(id3_pos + 8)
        local size_byte4 = content:byte(id3_pos + 9)
        local tag_size = size_byte1 * 0x200000 + size_byte2 * 0x4000 + size_byte3 * 0x80 + size_byte4
        
        -- Lire les frames dans la tag
        local frame_pos = id3_pos + 10
        local frame_end = id3_pos + tag_size + 10
        
        while frame_pos < frame_end and frame_pos < #content - 10 do
            local frame_id = content:sub(frame_pos, frame_pos + 3)
            local frame_size_byte1 = content:byte(frame_pos + 4)
            local frame_size_byte2 = content:byte(frame_pos + 5)
            local frame_size_byte3 = content:byte(frame_pos + 6)
            local frame_size_byte4 = content:byte(frame_pos + 7)
            local frame_size = frame_size_byte1 * 0x1000000 + frame_size_byte2 * 0x10000 + frame_size_byte3 * 0x100 + frame_size_byte4
            local frame_flags = content:byte(frame_pos + 8, frame_pos + 9)
            
            -- Skip flag bytes
            local data_start = frame_pos + 10
            
            -- Lire les données du frame
            if frame_id == "TIT2" then -- Titre
                result.titre = tags._read_id3_frame(content, data_start, frame_size)
            elseif frame_id == "TPE1" then -- Artiste
                result.artiste = tags._read_id3_frame(content, data_start, frame_size)
            elseif frame_id == "TALB" then -- Album
                result.album = tags._read_id3_frame(content, data_start, frame_size)
            elseif frame_id == "TYER" then -- Année
                result.annee = tonumber(tags._read_id3_frame(content, data_start, frame_size))
            elseif frame_id == "TCON" then -- Genre
                result.genre = tags._read_id3_frame(content, data_start, frame_size)
            elseif frame_id == "TLEN" then -- Durée en ms
                result.duree = math.floor(tonumber(tags._read_id3_frame(content, data_start, frame_size)) / 1000)
            end
            
            frame_pos = frame_pos + 10 + frame_size
        end
    end
    
    -- Si on n'a pas trouvé ID3v2, essayer ID3v1 à la fin
    if not result.titre and #content > 128 then
        local id3v1 = content:sub(#content - 127, #content)
        if id3v1:sub(1, 3) == "TAG" then
            result.titre = id3v1:sub(4, 33):match("^[^\0]+")
            result.artiste = id3v1:sub(34, 63):match("^[^\0]+")
            result.album = id3v1:sub(64, 93):match("^[^\0]+")
            result.annee = tonumber(id3v1:sub(94, 97):match("^[^\0]+"))
            -- Genre ID3v1
            local genre_id = id3v1:byte(98)
            result.genre = tags.ID3V1_GENRES[genre_id] or ""
        end
    end
    
    -- Obtenir la durée et le bitrate depuis le header MP3
    if not result.duree then
        local mp3_info = tags._parse_mp3_header(content)
        if mp3_info then
            result.duree = mp3_info.duree
            result.bitrate = mp3_info.bitrate
        end
    end
    
    return result
end

-- Lire une frame ID3v2
function tags._read_id3_frame(content, start, size)
    local encoding = content:byte(start)
    local data = content:sub(start + 1, start + size)
    
    if encoding == 0 then -- ISO-8859-1
        return data:match("^[^\0]+")
    elseif encoding == 1 then -- UTF-16 with BOM
        -- Simple handling: remove null bytes
        return data:gsub("\0", ""):match("^[^\0]+")
    elseif encoding == 2 then -- UTF-16BE without BOM
        return tags._utf16be_to_utf8(data)
    elseif encoding == 3 then -- UTF-8
        return data:match("^[^\0]+")
    else
        return data:match("^[^\0]+")
    end
end

-- Convertir UTF-16BE en UTF-8 (simplifié)
function tags._utf16be_to_utf8(str)
    local result = ""
    for i = 1, #str, 2 do
        local high = str:byte(i)
        local low = str:byte(i + 1)
        if high == 0 and low == 0 then break end
        local code = high * 256 + low
        if code < 128 then
            result = result .. string.char(code)
        else
            -- Convertir en UTF-8
            if code < 2048 then
                result = result .. string.char(192 + math.floor(code / 64), 128 + (code % 64))
            elseif code < 65536 then
                result = result .. string.char(224 + math.floor(code / 4096), 128 + math.floor((code % 4096) / 64), 128 + (code % 64))
            end
        end
    end
    return result
end

-- Parser le header MP3 pour obtenir durée et bitrate
function tags._parse_mp3_header(content)
    -- Trouver le premier frame MP3
    local pos = 1
    while pos < #content - 4 do
        if content:byte(pos) == 0xFF and (content:byte(pos + 1) >= 0xE0 and content:byte(pos + 1) <= 0xFF) then
            local version = bit32 and bit32.rshift(content:byte(pos + 1), 3) or (content:byte(pos + 1) // 8)
            local layer = bit32 and bit32.band(content:byte(pos + 1), 0x06) or (content:byte(pos + 1) % 8)
            local bitrate_idx = bit32 and bit32.rshift(content:byte(pos + 2), 4) or (content:byte(pos + 2) // 16)
            local sample_rate_idx = bit32 and bit32.band(content:byte(pos + 2), 0x0C) or (content:byte(pos + 2) % 16)
            local padding = bit32 and bit32.band(content:byte(pos + 2), 0x02) or (content:byte(pos + 2) % 4)
            
            -- Bitrate (kbit/s)
            local BITRATES = {
                {0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0}, -- MPEG1 Layer1
                {0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0}, -- MPEG1 Layer2
                {0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0}, -- MPEG1 Layer3
                {0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0}, -- MPEG2 Layer1
                {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0}, -- MPEG2 Layer2
                {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0}  -- MPEG2 Layer3
            }
            
            local version_idx = (version == 3) and 1 or 2 -- MPEG1 ou MPEG2
            local layer_idx = (layer == 3) and 1 or ((layer == 2) and 2 or 3)
            local bitrate = BITRATES[(version_idx - 1) * 3 + layer_idx][bitrate_idx + 1]
            
            if bitrate and bitrate > 0 then
                -- Sample rates
                local SAMPLE_RATES = {
                    {44100, 48000, 32000, 0}, -- MPEG1
                    {22050, 24000, 16000, 0}  -- MPEG2
                }
                local sample_rate = SAMPLE_RATES[version_idx][sample_rate_idx + 1]
                
                -- Taille du frame
                local slot_size = (version_idx == 1) and 1 or 0.5
                local frame_size = (144 * bitrate * 1000 / sample_rate) + padding
                
                -- Calculer la durée (approximation)
                local total_size = #content
                local num_frames = math.floor(total_size / frame_size)
                local duration = (num_frames * 1152 * slot_size) / sample_rate
                
                return {
                    bitrate = bitrate,
                    duree = math.floor(duration)
                }
            end
        end
        pos = pos + 1
    end
    return nil
end

-- Genres ID3v1
ags.ID3V1_GENRES = {
    [0] = "Blues",
    [1] = "Classic Rock",
    [2] = "Country",
    [3] = "Dance",
    [4] = "Disco",
    [5] = "Funk",
    [6] = "Grunge",
    [7] = "Hip-Hop",
    [8] = "Jazz",
    [9] = "Metal",
    [10] = "New Age",
    [11] = "Oldies",
    [12] = "Other",
    [13] = "Pop",
    [14] = "R&B",
    [15] = "Rap",
    [16] = "Reggae",
    [17] = "Rock",
    [18] = "Techno",
    [19] = "Industrial",
    [20] = "Alternative",
    [21] = "Ska",
    [22] = "Death Metal",
    [23] = "Pranks",
    [24] = "Soundtrack",
    [25] = "Euro-Techno",
    [26] = "Ambient",
    [27] = "Trip-Hop",
    [28] = "Vocal",
    [29] = "Jazz+Funk",
    [30] = "Fusion",
    [31] = "Trance",
    [32] = "Classical",
    [33] = "Instrumental",
    [34] = "Acid",
    [35] = "House",
    [36] = "Game",
    [37] = "Sound Clip",
    [38] = "Gospel",
    [39] = "Noise",
    [40] = "AlternRock",
    [41] = "Bass",
    [42] = "Soul",
    [43] = "Punk",
    [44] = "Space",
    [45] = "Meditative",
    [46] = "Instrumental Pop",
    [47] = "Instrumental Rock",
    [48] = "Ethnic",
    [49] = "Gothic",
    [50] = "Darkwave",
    [51] = "Techno-Industrial",
    [52] = "Electronic",
    [53] = "Pop-Folk",
    [54] = "Eurodance",
    [55] = "Dream",
    [56] = "Southern Rock",
    [57] = "Comedy",
    [58] = "Cult",
    [59] = "Gangsta",
    [60] = "Top 40",
    [61] = "Christian Rap",
    [62] = "Pop/Funk",
    [63] = "Jungle",
    [64] = "Native American",
    [65] = "Cabaret",
    [66] = "New Wave",
    [67] = "Psychadelic",
    [68] = "Rave",
    [69] = "Showtunes",
    [70] = "Trailer",
    [71] = "Lo-Fi",
    [72] = "Tribal",
    [73] = "Acid Punk",
    [74] = "Acid Jazz",
    [75] = "Polka",
    [76] = "Retro",
    [77] = "Musical",
    [78] = "Rock & Roll",
    [79] = "Hard Rock"
}

-- Parser FLAC (Ogg FLAC ou native FLAC)
function tags._parse_flac(filepath)
    return tags._parse_with_ffprobe(filepath)
end

-- Parser OGG (Vorbis)
function tags._parse_ogg(filepath)
    return tags._parse_with_ffprobe(filepath)
end

-- Parser MP4/M4A
function tags._parse_mp4(filepath)
    return tags._parse_with_ffprobe(filepath)
end

-- Parser avec ffprobe (fallback)
function tags._parse_with_ffprobe(filepath)
    local handle = io.popen('ffprobe -v quiet -print_format json -show_format -show_streams "' .. filepath:gsub("'", "'\\''") .. '" 2>/dev/null')
    if not handle then return nil end
    
    local json_str = handle:read("*a")
    handle:close()
    
    if not json_str or json_str == "" then return nil end
    
    -- Parser JSON simple
    local result = {}
    
    -- Extraire les infos du format
    local format_match = json_str:match('"format":\s*({[^}]+})')
    if format_match then
        result.duree = tonumber(format_match:match('"duration":\s*([%,.%d]+)') or 0)
        result.bitrate = tonumber(format_match:match('"bit_rate":\s*([%,.%d]+)') or 0) / 1000
    end
    
    -- Extraire les tags
    local tags_str = json_str:match('"tags":\s*({[^}]+})')
    if tags_str then
        result.titre = tags_str:match('"title":\s*"([^"]*)"')
        result.artiste = tags_str:match('"artist":\s*"([^"]*)"')
        result.album = tags_str:match('"album":\s*"([^"]*)"')
        result.genre = tags_str:match('"genre":\s*"([^"]*)"')
        result.annee = tonumber(tags_str:match('"date":\s*"([^"]*)"') or tags_str:match('"year":\s*"([^"]*)"'))
    end
    
    return result
end

-- Vérifier si un fichier existe
function tags.file_exists(filepath)
    local f = io.open(filepath, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Obtenir l'extension d'un fichier
function tags.get_extension(filepath)
    return filepath:match("%.([^%.]+)$") or ""
end

return tags
