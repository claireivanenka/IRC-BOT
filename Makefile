# Makefile pour le bot IRC Lua

.PHONY: install install-full install-music run run-music test test-full test-music clean help

# Couleurs pour les messages
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

# Commande Lua
LUA = lua

install:
	@echo "$(YELLOW)Installation des dépendances de base...$(NC)"
	@echo ""
	@if [ -f /etc/debian_version ] || [ -f /etc/os-release ]; then \
		echo "$(GREEN)✓ Détection de Debian/Ubuntu$(NC)"; \
		sudo apt update; \
		sudo apt install -y lua5.4 lua-socket lua-sec; \
	else \
		echo "$(RED)❌ Système non supporté. Utilisez Debian/Ubuntu ou installez manuellement.$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Installation de base terminée!$(NC)"

install-full: install install-music

install-music:
	@echo "$(YELLOW)Installation des dépendances pour le module musique...$(NC)"
	@echo ""
	@if [ -f /etc/debian_version ] || [ -f /etc/os-release ]; then \
		echo "$(GREEN)✓ Détection de Debian/Ubuntu$(NC)"; \
		sudo apt update; \
		sudo apt install -y postgresql postgresql-contrib ffmpeg nginx luarocks; \
		luarocks install luasql-postgres; \
		luarocks install lua-json; \
		luarocks install luasocket; \
		luarocks install luafilesystem; \
	else \
		echo "$(RED)❌ Système non supporté.$(NC)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Installation du module musique terminée!$(NC)"

run:
	@echo "$(YELLOW)Démarrage du bot IRC...$(NC)"
	@echo ""
	$(LUA) irc_bot.lua

run-music:
	@echo "$(YELLOW)Démarrage du bot IRC avec le serveur API musique...$(NC)"
	@echo ""
	$(LUA) irc_bot.lua &
	$(LUA) deploy/music_api.lua &
	@echo "$(GREEN)✓ Bot et API musique démarrés!$(NC)"

test:
	@echo "$(YELLOW)Test des dépendances de base...$(NC)"
	@echo ""
	@if command -v $(LUA) &> /dev/null; then \
		echo "$(GREEN)✓ Lua est installé: $($(LUA) -v 2>&1)$(NC)"; \
	else \
		echo "$(RED)❌ Lua n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('socket')" 2> /dev/null; then \
		echo "$(GREEN)✓ lua-socket est installé$(NC)"; \
	else \
		echo "$(RED)❌ lua-socket n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('ssl')" 2> /dev/null; then \
		echo "$(GREEN)✓ lua-sec est installé$(NC)"; \
	else \
		echo "$(YELLOW)⚠ lua-sec n'est pas installé (optionnel pour SSL)$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Tous les tests de base ont réussi!$(NC)"

test-full: test test-music

test-music:
	@echo "$(YELLOW)Test des dépendances pour le module musique...$(NC)"
	@echo ""
	@if command -v $(LUA) &> /dev/null; then \
		echo "$(GREEN)✓ Lua est installé$(NC)"; \
	else \
		echo "$(RED)❌ Lua n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('luasql.postgres')" 2> /dev/null; then \
		echo "$(GREEN)✓ luasql-postgres est installé$(NC)"; \
	else \
		echo "$(RED)❌ luasql-postgres n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('json')" 2> /dev/null; then \
		echo "$(GREEN)✓ lua-json est installé$(NC)"; \
	else \
		echo "$(RED)❌ lua-json n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('socket')" 2> /dev/null; then \
		echo "$(GREEN)✓ luasocket est installé$(NC)"; \
	else \
		echo "$(RED)❌ luasocket n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if $(LUA) -e "require('lfs')" 2> /dev/null; then \
		echo "$(GREEN)✓ luafilesystem est installé$(NC)"; \
	else \
		echo "$(RED)❌ luafilesystem n'est pas installé$(NC)"; \
		exit 1; \
	fi
	@if command -v ffprobe &> /dev/null; then \
		echo "$(GREEN)✓ ffprobe est installé$(NC)"; \
	else \
		echo "$(YELLOW)⚠ ffprobe n'est pas installé (pour la lecture des tags)$(NC)"; \
	fi
	@if command -v nginx &> /dev/null; then \
		echo "$(GREEN)✓ nginx est installé$(NC)"; \
	else \
		echo "$(YELLOW)⚠ nginx n'est pas installé (pour le streaming)$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Tous les tests pour le module musique ont réussi!$(NC)"

clean:
	@echo "$(YELLOW)Nettoyage...$(NC)"
	@rm -f *.log *.tmp custom_menus.dat
	@rm -rf deploy/music/player/.cache
	@echo "$(GREEN)✓ Nettoyage terminé$(NC)"

clean-all: clean
	@echo "$(YELLOW)Nettoyage complet...$(NC)"
	@rm -rf /var/lib/irc_bot/music
	@echo "$(GREEN)✓ Nettoyage complet terminé$(NC)"

setup-music:
	@echo "$(YELLOW)Configuration du module musique...$(NC)"
	@echo ""
	@mkdir -p /var/lib/irc_bot/music
	@mkdir -p /var/www/irc_bot/music/player
	@cp -r deploy/player/* /var/www/irc_bot/music/player/
	@cp deploy/nginx.conf /etc/nginx/sites-available/irc_bot_music
	@ln -sf /etc/nginx/sites-available/irc_bot_music /etc/nginx/sites-enabled/
	@cp sql/music_schema.sql /tmp/
	@echo ""
	@echo "$(GREEN)✓ Configuration du module musique terminée!$(NC)"
	@echo ""
	@echo "Pour finaliser l'installation:"
	@echo "  1. Exécutez : sudo nginx -t && sudo systemctl restart nginx"
	@echo "  2. Importez le schéma SQL dans PostgreSQL:"
	@echo "     sudo -u postgres psql -d irc_bot -f /tmp/music_schema.sql"
	@echo "  3. Configurez config_custom.lua avec les paramètres musique"
	@echo ""

help:
	@echo "Commandes disponibles:"
	@echo ""
	@echo "🏗️  Installation:"
	@echo "  make install          - Installe les dépendances de base"
	@echo "  make install-full     - Installe toutes les dépendances (base + musique)"
	@echo "  make install-music    - Installe les dépendances pour le module musique"
	@echo ""
	@echo "▶️   Exécution:"
	@echo "  make run              - Démarre le bot IRC"
	@echo "  make run-music        - Démarre le bot + API musique"
	@echo ""
	@echo "🧪 Tests:"
	@echo "  make test             - Teste les dépendances de base"
	@echo "  make test-full        - Teste toutes les dépendances"
	@echo "  make test-music       - Teste les dépendances musique"
	@echo ""
	@echo "🧹 Nettoyage:"
	@echo "  make clean            - Nettoie les fichiers temporaires"
	@echo "  make clean-all        - Nettoyage complet"
	@echo ""
	@echo "⚙️  Configuration:"
	@echo "  make setup-music      - Configure le module musique (nginx, etc.)"
	@echo ""
	@echo "ℹ️   Aide:"
	@echo "  make help             - Affiche cette aide"
