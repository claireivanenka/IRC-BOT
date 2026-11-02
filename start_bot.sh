#!/bin/bash

# Script de lancement pour le bot IRC Lua

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  Lancement du bot IRC en Lua"
echo "========================================="
echo ""

# Vérifier que Lua est installé
if ! command -v lua &> /dev/null; then
    echo "❌ Erreur: Lua n'est pas installé."
    echo "   Installez-le avec: sudo apt install lua5.4"
    exit 1
fi

# Vérifier que lua-socket est installé
if ! lua -e "require('socket')" 2> /dev/null; then
    echo "❌ Erreur: lua-socket n'est pas installé."
    echo "   Installez-le avec: sudo apt install lua-socket"
    exit 1
fi

# Vérifier que le script existe
if [ ! -f "irc_bot.lua" ]; then
    echo "❌ Erreur: irc_bot.lua introuvable dans le dossier courant."
    exit 1
fi

# Afficher les informations de version
echo "✓ Lua: $(lua -v 2>&1)"
echo "✓ lua-socket: installé"

if lua -e "require('ssl')" 2> /dev/null; then
    echo "✓ lua-sec: installé"
else
    echo "⚠ lua-sec: non installé (nécessaire pour SSL)"
fi

echo ""
echo "Démarrage du bot..."
echo "Appuyez sur Ctrl+C pour arrêter."
echo ""

# Lancer le bot
lua irc_bot.lua
