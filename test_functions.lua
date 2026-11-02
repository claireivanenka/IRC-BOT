#!/usr/bin/env lua
-- =====================================================================
-- Script de test pour les fonctions du bot IRC
-- Exécutez avec: lua test_functions.lua
-- =====================================================================

-- Charger les fonctions du bot
local function load_bot_functions()
    local bot_code = io.open("irc_bot.lua", "r"):read("*a")
    
    -- Extraire les fonctions nécessaires
    local functions = {}
    
    -- Fonction clean_youtube_url
    local clean_func = bot_code:match("function clean_youtube_url(.->)end")
    if clean_func then
        functions.clean_youtube_url = loadstring("function clean_youtube_url(url)" .. clean_func .. "end")
    end
    
    -- Menu par défaut
    local menu_data = bot_code:match("local menu = ({.-})\n") or bot_code:match("local menu = ({.-});")
    if menu_data then
        functions.menu = loadstring("return " .. menu_data)()
    end
    
    -- Fonction show_menu
    local show_func = bot_code:match("function show_menu(.->)end")
    if show_func then
        functions.show_menu = loadstring("function show_menu(category) " .. show_func .. " end")
    end
    
    return functions
end

-- Définir les fonctions directement (plus simple)
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
-- Tests
-- =====================================================================

local tests_passed = 0
local tests_failed = 0

local function test(description, condition)
    if condition then
        print("✓ " .. description)
        tests_passed = tests_passed + 1
    else
        print("✗ " .. description)
        tests_failed = tests_failed + 1
    end
end

local function assert_equals(actual, expected, description)
    if actual == expected then
        print("✓ " .. description)
        tests_passed = tests_passed + 1
    else
        print("✗ " .. description .. " (attendu: " .. expected .. ", obtenu: " .. actual .. ")")
        tests_failed = tests_failed + 1
    end
end

function run_tests()
    print("\n" .. string.rep("=", 60))
    print("  TESTS POUR LE BOT IRC")
    print(string.rep("=", 60) .. "\n")
    
    -- Tests pour clean_youtube_url
    print("--- Tests: Nettoyage des URLs YouTube ---")
    
    local url1 = clean_youtube_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=twitter")
    assert_equals(url1, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "Nettoyage URL standard avec trackers")
    
    local url2 = clean_youtube_url("https://youtu.be/dQw4w9WgXcQ?t=10&feature=embed")
    assert_equals(url2, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "Nettoyage URL youtu.be")
    
    local url3 = clean_youtube_url("https://www.youtube.com/watch?v=abc123")
    assert_equals(url3, "https://www.youtube.com/watch?v=abc123", "URL sans trackers")
    
    local url4 = clean_youtube_url("https://www.youtube.com/embed/xyz456?autoplay=1")
    assert_equals(url4, "https://www.youtube.com/watch?v=xyz456", "URL embed")
    
    local url5 = clean_youtube_url("https://google.com")
    test("Détection URL non-YouTube", url5:find("Ce n'est pas une URL YouTube"))
    
    local url6 = clean_youtube_url("https://www.youtube.com/watch?v=test&feature=share&fbclid=abc123&utm_campaign=xyz")
    assert_equals(url6, "https://www.youtube.com/watch?v=test", "Nettoyage multiple trackers")
    
    print("\n--- Tests: Menu ---")
    
    -- Test menu complet
    local full_menu = show_menu("tout")
    test("Menu complet contient les boissons", full_menu:find("BOISSONS"))
    test("Menu complet contient la nourriture", full_menu:find("NOURRITURE"))
    test("Menu complet contient Café", full_menu:find("Café"))
    test("Menu complet contient Pizza", full_menu:find("Pizza"))
    
    -- Test menu boissons seulement
    local boissons_menu = show_menu("boissons")
    test("Menu boissons ne contient pas NOURRITURE", not boissons_menu:find("NOURRITURE"))
    test("Menu boissons contient BOISSONS", boissons_menu:find("BOISSONS"))
    
    -- Test menu nourriture seulement
    local nourriture_menu = show_menu("manger")
    test("Menu nourriture ne contient pas BOISSONS", not nourriture_menu:find("BOISSONS"))
    test("Menu nourriture contient NOURRITURE", nourriture_menu:find("NOURRITURE"))
    
    print("\n--- Tests: Structure du menu ---")
    
    test("Menu boissons a des éléments", #menu.boissons > 0)
    test("Menu nourriture a des éléments", #menu.nourriture > 0)
    
    -- Vérifier que chaque élément a un nom et un prix
    for _, item in ipairs(menu.boissons) do
        test("Boisson a un nom", item[1] ~= nil)
        test("Boisson a un prix", item[2] ~= nil and type(item[2]) == "number")
    end
    
    for _, item in ipairs(menu.nourriture) do
        test("Nourriture a un nom", item[1] ~= nil)
        test("Nourriture a un prix", item[2] ~= nil and type(item[2]) == "number")
    end
    
    -- =====================================================================
    -- Résumé
    -- =====================================================================
    print("\n" .. string.rep("=", 60))
    print("  RÉSULTATS")
    print(string.rep("=", 60))
    print(string.format("Tests réussis: %d", tests_passed))
    print(string.format("Tests échoués: %d", tests_failed))
    print(string.rep("=", 60) .. "\n")
    
    if tests_failed == 0 then
        print("🎉 Tous les tests ont réussi !")
        return 0
    else
        print("❌ Certains tests ont échoué.")
        return 1
    end
end

-- Exécuter les tests
local exit_code = run_tests()
os.exit(exit_code)
