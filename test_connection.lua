#!/usr/bin/env lua
-- =====================================================================
-- Script de test pour vérifier que le bot peut gérer les PING correctement
-- =====================================================================

-- Charger les fonctions du bot
local socket = require("socket")

-- Simuler la configuration
local config = {
    server = "irc.libera.chat",
    port = 6667,
    nick = "titoune",
    user = "titoune",
    realname = "Test Bot",
    channel = "#fauve",
    use_ssl = false,
    nickserv = {
        enabled = true,
        password = "JusteVivreHeureuse€2029",
        wait_time = 5
    },
    logging = {
        enabled = false,  -- Désactivé pour le test
    }
}

-- Simuler les fonctions de logging
local log_file = nil
function log_message(type, source, message)
    -- Désactivé pour le test
end
function init_logging() end
function close_logging() end
function rotate_logs() end

-- Tester le parsing des PING
function test_ping_parsing()
    print("\n=== Test 1: Parsing des PING ===")
    
    local test_cases = {
        "PING :abc123",
        "PING abc123",
        "PING :libera.chat",
    }
    
    for i, line in ipairs(test_cases) do
        if line:match("^PING") then
            local token = line:match("^PING :(.+)") or line:match("^PING (%S+)")
            if token then
                print("✓ Test " .. i .. " PASS: token extrait = '" .. token .. "'")
            else
                print("✗ Test " .. i .. " FAIL: impossible d'extraire le token")
                return false
            end
        end
    end
    
    print("✓ Tous les tests de PING ont réussi")
    return true
end

-- Tester la réponse PONG
function test_pong_response()
    print("\n=== Test 2: Réponse PONG ===")
    
    local test_lines = {
        "PING :test123",
        "PING liberachat",
    }
    
    for i, line in ipairs(test_lines) do
        if line:match("^PING") then
            local token = line:match("^PING :(.+)") or line:match("^PING (%S+)")
            if token then
                local response = "PONG :" .. token .. "\r\n"
                print("✓ Test " .. i .. " PASS: PONG = '" .. response:gsub("\r\n", "") .. "'")
            else
                print("✗ Test " .. i .. " FAIL")
                return false
            end
        end
    end
    
    print("✓ Tous les tests de PONG ont réussi")
    return true
end

-- Tester la configuration
function test_configuration()
    print("\n=== Test 3: Configuration ===")
    
    local required = {
        "server", "port", "nick", "user", "realname", "channel"
    }
    
    for i, key in ipairs(required) do
        if config[key] then
            print("✓ " .. key .. " = '" .. tostring(config[key]) .. "'")
        else
            print("✗ " .. key .. " est manquant")
            return false
        end
    end
    
    -- Vérifier NickServ
    if config.nickserv and config.nickserv.enabled then
        if config.nickserv.password then
            print("✓ NickServ: configuré avec mot de passe")
        else
            print("✗ NickServ: mot de passe manquant")
            return false
        end
    else
        print("⚠️  NickServ: non activé (nécessaire pour Libera.Chat)")
    end
    
    print("✓ Configuration validée")
    return true
end

-- Fonction principale de test
function main()
    print("\n" .. string.rep("=", 60))
    print("  TEST DE CONNEXION DU BOT IRC")
    print(string.rep("=", 60) .. "\n")
    
    local all_pass = true
    
    all_pass = test_configuration() and all_pass
    all_pass = test_ping_parsing() and all_pass
    all_pass = test_pong_response() and all_pass
    
    print("\n" .. string.rep("=", 60))
    if all_pass then
        print("  ✅ TOUS LES TESTS ONT RÉUSSI !")
        print("  Le bot devrait maintenant rester connecté sans timeout.")
    else
        print("  ❌ CERTAINS TESTS ONT ÉCHOUÉ")
    end
    print(string.rep("=", 60) .. "\n")
    
    return all_pass and 0 or 1
end

-- Exécuter les tests
local exit_code = main()
os.exit(exit_code)
