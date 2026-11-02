# Makefile pour le bot IRC Lua

.PHONY: install run test clean

# Couleurs pour les messages
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

# Commande Lua
LUA = lua

install:
	@echo "$(YELLOW)Installation des dépendances...$(NC)"
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
	@echo "$(GREEN)✓ Installation terminée!$(NC)"

run:
	@echo "$(YELLOW)Démarrage du bot IRC...$(NC)"
	@echo ""
	$(LUA) irc_bot.lua

test:
	@echo "$(YELLOW)Test des dépendances...$(NC)"
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
	@echo "$(GREEN)✓ Tous les tests ont réussi!$(NC)"

clean:
	@echo "$(YELLOW)Nettoyage...$(NC)"
	@rm -f *.log *.tmp
	@echo "$(GREEN)✓ Nettoyage terminé$(NC)"

help:
	@echo "Commandes disponibles:"
	@echo "  make install  - Installe les dépendances"
	@echo "  make run      - Démarre le bot"
	@echo "  make test     - Teste les dépendances"
	@echo "  make clean    - Nettoie les fichiers temporaires"
	@echo "  make help     - Affiche cette aide"
