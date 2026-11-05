-- music_db.lua - Module de gestion de la base de données musicale
-- Part of IRC-BOT project

local music_db = {}

-- Configuration de la table
music_db.table_name = "tracks"

-- Initialiser la connexion (utilise la connexion db_conn globale)
function music_db.init()
    -- La connexion est gérée par le module principal
    -- Vérifier que la table existe
    music_db._ensure_table()
end

-- S'assurer que la table existe
function music_db._ensure_table()
    if not db_conn then return false end
    
    -- Vérifier si la table existe
    local result = db_conn:execute("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = '" .. music_db.table_name .. "')")
    if result then
        local row = result:fetch({}, "a")
        if row and row.exists == true then
            result:close()
            return true
        end
        result:close()
    end
    
    -- Créer la table si elle n'existe pas
    local create_sql = io.open("sql/music_schema.sql", "r")
    if create_sql then
        local sql = create_sql:read("*a")
        create_sql:close()
        local ok, err = pcall(function()
            local res = db_conn:execute(sql)
            if res and type(res) == "userdata" then
                res:close()
            end
        end)
        if ok then
            print("✓ Table " .. music_db.table_name .. " créée")
            return true
        else
            print("⚠️ Erreur création table music: " .. tostring(err))
            return false
        end
    else
        print("⚠️ Fichier sql/music_schema.sql introuvable")
        return false
    end
end

-- Échapper les chaînes SQL
local function escape_sql(str)
    if not str then return "NULL" end
    return (str:gsub("'", "''"))
end

-- Calculer le hash SHA-256 d'un fichier (nécessite le module luacrypto ou openssl)
-- Version fallback avec sha256sum en ligne de commande
function music_db.calculate_sha256(filepath)
    if not filepath then return nil end
    
    -- Essayer d'utiliser luacrypto si disponible
    local crypto_ok, crypto = pcall(function() return require("crypto") end)
    if crypto_ok then
        local f = io.open(filepath, "rb")
        if f then
            local content = f:read("*a")
            f:close()
            return crypto.hash.sha256(content)
        end
        return nil
    end
    
    -- Fallback: utiliser sha256sum en ligne de commande
    local handle = io.popen("sha256sum \"" .. filepath:gsub("'", "'\\''") .. "\" 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            return result:match("^([a-f0-9]+)")
        end
    end
    
    return nil
end

-- Ajouter une piste
-- @param track: table avec les champs: titre, artiste, album, annee, genre, duree, bitrate, chemin_fichier, url_streaming, ajoute_par
-- @return: id de la piste insérée, ou nil en cas d'erreur
function music_db.add_track(track)
    if not db_conn then
        log_message("ERR", "music_db", "Connexion PostgreSQL non disponible")
        return nil
    end
    
    -- Vérifier les champs obligatoires
    if not track.titre then
        log_message("ERR", "music_db", "Champ 'titre' manquant")
        return nil
    end
    
    -- Calculer le hash si le chemin est fourni
    local hash = track.hash_fichier
    if not hash and track.chemin_fichier then
        hash = music_db.calculate_sha256(track.chemin_fichier)
    end
    if not hash then hash = "" end
    
    local query = string.format(
        "INSERT INTO %s (titre, artiste, album, annee, genre, duree, bitrate, chemin_fichier, url_streaming, hash_fichier, ajoute_par) VALUES ('%s', '%s', '%s', %s, '%s', %d, %s, '%s', '%s', '%s', '%s') RETURNING id",
        music_db.table_name,
        escape_sql(track.titre),
        escape_sql(track.artiste or ""),
        escape_sql(track.album or ""),
        track.annee and tonumber(track.annee) or "NULL",
        escape_sql(track.genre or ""),
        tonumber(track.duree) or 0,
        track.bitrate and tonumber(track.bitrate) or "NULL",
        escape_sql(track.chemin_fichier or ""),
        escape_sql(track.url_streaming or ""),
        escape_sql(hash),
        escape_sql(track.ajoute_par)
    )
    
    local ok, err = pcall(function()
        local res = db_conn:execute(query)
        if res then
            local row = res:fetch({}, "a")
            local id = row and tonumber(row.id)
            res:close()
            return id
        end
        return nil
    end)
    
    if ok then
        log_message("DBG", "music_db", "Piste ajoutée avec ID: " .. tostring(ok))
        return ok
    else
        log_message("ERR", "music_db", "Erreur ajout piste: " .. tostring(err))
        return nil
    end
end

-- Obtenir une piste par ID
-- @param id: ID de la piste
-- @return: table avec les champs de la piste, ou nil
function music_db.get_track_by_id(id)
    if not db_conn or not id then return nil end
    
    local query = "SELECT * FROM " .. music_db.table_name .. " WHERE id = " .. tonumber(id)
    local cursor = db_conn:execute(query)
    
    if cursor then
        local row = cursor:fetch({}, "a")
        cursor:close()
        if row then
            return {
                id = tonumber(row.id),
                titre = row.titre,
                artiste = row.artiste,
                album = row.album,
                annee = row.annee and tonumber(row.annee),
                genre = row.genre,
                duree = tonumber(row.duree),
                bitrate = row.bitrate and tonumber(row.bitrate),
                chemin_fichier = row.chemin_fichier,
                url_streaming = row.url_streaming,
                hash_fichier = row.hash_fichier,
                ajoute_par = row.ajoute_par,
                date_ajout = row.date_ajout,
                nb_lectures = tonumber(row.nb_lectures),
                date_derniere_lecture = row.date_derniere_lecture
            }
        end
    end
    return nil
end

-- Rechercher des pistes
-- @param query: chaîne de recherche (recherche dans titre, artiste, album)
-- @param limit: nombre maximal de résultats (défaut: 5)
-- @return: table de pistes
function music_db.search_tracks(query, limit)
    if not db_conn or not query then return {} end
    
    limit = limit or 5
    
    local search_query = string.format(
        "SELECT * FROM %s WHERE to_tsvector('french', titre || ' ' || artiste || ' ' || album) @@ to_tsquery('french', '%s') OR titre ILIKE '%%%s%%' OR artiste ILIKE '%%%s%%' OR album ILIKE '%%%s%%' ORDER BY nb_lectures DESC, date_ajout DESC LIMIT %d",
        music_db.table_name,
        escape_sql(query),
        escape_sql(query),
        escape_sql(query),
        escape_sql(query),
        limit
    )
    
    local tracks = {}
    local cursor = db_conn:execute(search_query)
    
    if cursor then
        local row = cursor:fetch({}, "a")
        local count = 0
        while row and count < limit do
            count = count + 1
            table.insert(tracks, {
                id = tonumber(row.id),
                titre = row.titre,
                artiste = row.artiste,
                album = row.album,
                annee = row.annee and tonumber(row.annee),
                genre = row.genre,
                duree = tonumber(row.duree),
                bitrate = row.bitrate and tonumber(row.bitrate),
                chemin_fichier = row.chemin_fichier,
                url_streaming = row.url_streaming,
                hash_fichier = row.hash_fichier,
                ajoute_par = row.ajoute_par,
                date_ajout = row.date_ajout,
                nb_lectures = tonumber(row.nb_lectures),
                date_derniere_lecture = row.date_derniere_lecture
            })
            row = cursor:fetch(row, "a")
        end
        cursor:close()
    end
    
    return tracks
end

-- Incrémenter le compteur de lectures
-- @param id: ID de la piste
-- @return: true si succès, false sinon
function music_db.increment_play_count(id)
    if not db_conn or not id then return false end
    
    local query = "UPDATE " .. music_db.table_name .. " SET nb_lectures = nb_lectures + 1, date_derniere_lecture = NOW() WHERE id = " .. tonumber(id)
    
    local ok, err = pcall(function()
        local res = db_conn:execute(query)
        if res and type(res) == "userdata" then
            res:close()
        end
        return true
    end)
    
    return ok or false
end

-- Obtenir les statistiques (top N pistes)
-- @param limit: nombre de résultats (défaut: 10)
-- @return: table de pistes triées par nb_lectures DESC
function music_db.get_stats(limit)
    if not db_conn then return {} end
    
    limit = limit or 10
    
    local query = "SELECT * FROM " .. music_db.table_name .. " ORDER BY nb_lectures DESC, date_ajout DESC LIMIT " .. limit
    
    local tracks = {}
    local cursor = db_conn:execute(query)
    
    if cursor then
        local row = cursor:fetch({}, "a")
        while row do
            table.insert(tracks, {
                id = tonumber(row.id),
                titre = row.titre,
                artiste = row.artiste,
                album = row.album,
                annee = row.annee and tonumber(row.annee),
                genre = row.genre,
                duree = tonumber(row.duree),
                bitrate = row.bitrate and tonumber(row.bitrate),
                chemin_fichier = row.chemin_fichier,
                url_streaming = row.url_streaming,
                hash_fichier = row.hash_fichier,
                ajoute_par = row.ajoute_par,
                date_ajout = row.date_ajout,
                nb_lectures = tonumber(row.nb_lectures),
                date_derniere_lecture = row.date_derniere_lecture
            })
            row = cursor:fetch(row, "a")
        end
        cursor:close()
    end
    
    return tracks
end

-- Supprimer une piste
-- @param id: ID de la piste
-- @return: true si succès, false sinon
function music_db.delete_track(id)
    if not db_conn or not id then return false end
    
    local query = "DELETE FROM " .. music_db.table_name .. " WHERE id = " .. tonumber(id)
    
    local ok, err = pcall(function()
        local res = db_conn:execute(query)
        if res and type(res) == "userdata" then
            res:close()
        end
        return true
    end)
    
    return ok or false
end

-- Obtenir le nombre total de pistes
-- @return: nombre de pistes
function music_db.get_track_count()
    if not db_conn then return 0 end
    
    local query = "SELECT COUNT(*) as count FROM " .. music_db.table_name
    local cursor = db_conn:execute(query)
    
    if cursor then
        local row = cursor:fetch({}, "a")
        local count = row and tonumber(row.count) or 0
        cursor:close()
        return count
    end
    
    return 0
end

return music_db
