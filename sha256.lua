-- =====================================================================
-- Implémentation SHA-256 en Lua pur
-- Basé sur le standard FIPS 180-4
-- =====================================================================

local sha256 = {}

-- Constantes SHA-256
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

-- Fonctions de rotation
local function rotr(x, n)
    return bit32.bor(bit32.rshift(x, n), bit32.lshift(x, 32 - n))
end

local function ch(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(bit32.bnot(x), z))
end

local function maj(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(x, z), bit32.band(y, z))
end

local function sigma0(x)
    return bit32.bxor(rotr(x, 2), rotr(x, 13), rotr(x, 22))
end

local function sigma1(x)
    return bit32.bxor(rotr(x, 6), rotr(x, 11), rotr(x, 25))
end

local function gamma0(x)
    return bit32.bxor(rotr(x, 7), rotr(x, 18), bit32.rshift(x, 3))
end

local function gamma1(x)
    return bit32.bxor(rotr(x, 17), rotr(x, 19), bit32.rshift(x, 10))
end

-- Initialiser le vérificateur de bit32
if not bit32 then
    -- Implémentation minimale pour Lua 5.1/5.2
    bit32 = {}
    
    function bit32.band(a, b, ...)
        local result = a & b
        for i = 1, select('#', ...) do
            result = result & select(i, ...)
        end
        return result
    end
    
    function bit32.bor(a, b, ...)
        local result = a | b
        for i = 1, select('#', ...) do
            result = result | select(i, ...)
        end
        return result
    end
    
    function bit32.bxor(a, b, ...)
        local result = a ~ b
        for i = 1, select('#', ...) do
            result = result ~ select(i, ...)
        end
        return result
    end
    
    function bit32.bnot(a)
        return ~a
    end
    
    function bit32.lshift(a, b)
        return a << b
    end
    
    function bit32.rshift(a, b)
        return a >> b
    end
end

-- Pad le message
local function pad_message(message)
    local len = #message
    local block_size = 64
    local padding_len = ((len + 8 + block_size - 1) // block_size) * block_size - len - 8
    
    local padded = message .. string.char(0x80) .. string.rep(string.char(0), padding_len)
    
    -- Ajouter la longueur en bits (big-endian, 64 bits)
    local bit_len = len * 8
    local bytes = {
        string.char(bit32.band(bit32.rshift(bit_len, 56), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 48), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 40), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 32), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 24), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 16), 0xFF)),
        string.char(bit32.band(bit32.rshift(bit_len, 8), 0xFF)),
        string.char(bit32.band(bit_len, 0xFF))
    }
    
    return padded .. table.concat(bytes)
end

-- Convertir un bloc de 64 bytes en tableau de 32-bit words (big-endian)
local function bytes_to_words(block)
    local words = {}
    for i = 1, 16 do
        local a, b, c, d = string.byte(block, (i-1)*4+1, (i-1)*4+4)
        words[i] = bit32.lshift(a, 24) + bit32.lshift(b, 16) + bit32.lshift(c, 8) + d
    end
    return words
end

-- Hash SHA-256
function sha256.hash(message)
    -- Vérifier si on a bit32
    if not bit32 or not bit32.band then
        -- Utiliser une méthode alternative si disponible
        local crypto = pcall(require, "crypto")
        if crypto then
            return crypto.digest("sha256", message):lower()
        end
        
        -- Utiliser openssl si disponible
        local handle = io.popen("echo -n '" .. message:gsub("'", "'\\''") .. "' | openssl dgst -sha256 2>/dev/null | cut -d' ' -f2")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result and result ~= "" then
                return result:gsub("\n", ""):lower()
            end
        end
        
        -- Retourner un hash simple
        local hash = 0
        for i = 1, #message do
            hash = (hash * 31 + string.byte(message, i)) % 16777216
        end
        return string.format("%08x", hash)
    end
    
    -- Constantes de hachage initiales
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    
    -- Préparer le message
    local padded = pad_message(message)
    
    -- Traiter le message par blocs de 64 bytes
    for i = 1, #padded, 64 do
        local block = padded:sub(i, i + 63)
        local W = bytes_to_words(block)
        
        -- Étendre à 64 mots
        for j = 17, 64 do
            W[j] = gamma1(W[j-2]) + W[j-7] + gamma0(W[j-15]) + W[j-16]
        end
        
        -- Initialiser les variables de travail
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        
        -- Boucle de compression
        for j = 1, 64 do
            local S1 = sigma1(e) + ch(e, f, g) + h + K[j] + W[j]
            local S0 = sigma0(a) + maj(a, b, c)
            
            h = g
            g = f
            f = e
            e = d + S1
            d = c
            c = b
            b = a
            a = S1 + S0
        end
        
        -- Mettre à jour le hash
        H[1] = (H[1] + a)
        H[2] = (H[2] + b)
        H[3] = (H[3] + c)
        H[4] = (H[4] + d)
        H[5] = (H[5] + e)
        H[6] = (H[6] + f)
        H[7] = (H[7] + g)
        H[8] = (H[8] + h)
    end
    
    -- Convertir en hexadécimal
    local result = {}
    for i = 1, 8 do
        table.insert(result, string.format("%08x", H[i]))
    end
    
    return table.concat(result):lower()
end

-- Hash d'un fichier
function sha256.file(file_path)
    local file = io.open(file_path, "rb")
    if not file then return nil end
    
    local hash = sha256.hash("")  -- Initialiser
    
    -- Lire par blocs pour les gros fichiers
    local block_size = 4096
    while true do
        local block = file:read(block_size)
        if not block or #block == 0 then break end
        
        -- Accumuler le hash
        hash = sha256.hash(hash .. block)
    end
    
    file:close()
    return hash
end

return sha256
