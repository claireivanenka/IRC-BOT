#!/usr/bin/env lua

-- Script pour indexer les fichiers audio du dossier CreamRoad

local function main()
    -- Charger la configuration
    local config = dofile("config_custom.lua")
    
    -- Charger le module creamroad_manager
    local creamroad_manager = require("creamroad_manager")
    
    -- Initialiser
    if not creamroad_manager.init(config) then
        print("❌ Impossible d'initialiser CreamRoad Manager")
        return false
    end
    
    -- Indexer le dossier
    local base_path = config.creamroad and config.creamroad.base_path or "/home/claire/IRC-BOT/CremRoad - Sep 2026"
    
    print(string.format("Indexation du dossier: %s", base_path))
    
    local success, count = creamroad_manager.index_directory(base_path)
    
    if success then
        print(string.format("✅ %d fichiers indexés avec succès !", count))
    else
        print(string.format("❌ Erreur lors de l'indexation: %s", count))
    end
    
    return success
end

return main()
