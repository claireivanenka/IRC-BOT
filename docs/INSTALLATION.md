# 📥 Installation du Bot IRC en Lua

Guide complet pour installer et configurer ton bot IRC.

---

## 📋 Prérequis

### Système requis
- **OS** : Linux (Debian/Ubuntu recommandé)
- **Lua** : Version 5.1 ou supérieure
- **Connexion Internet** : Pour se connecter aux serveurs IRC

---

## 🛠️ Installation des dépendances

### 1. Installer Lua

```bash
# Sur Debian/Ubuntu
sudo apt update
sudo apt install lua5.4

# Vérifier l'installation
lua -v
# Doit afficher : Lua 5.4.x
```

### 2. Installer lua-socket (obligatoire)

Le bot utilise `lua-socket` pour les connexions réseau.

```bash
sudo apt install lua-socket

# Vérifier
lua -e "require('socket')"
# Pas d'erreur = OK
```

### 3. Installer lua-sec (optionnel, pour SSL)

Si tu veux utiliser une connexion sécurisée (port 6697) :

```bash
sudo apt install lua-sec

# Vérifier
lua -e "require('ssl')"
```

### 4. Installer les outils de développement (optionnel)

```bash
# Pour les tests et le développement
sudo apt install luarocks git make
```

---

## 📥 Téléchargement du bot

### Méthode 1 : Cloner le dépôt GitHub

```bash
git clone https://github.com/claireivanenka/IRC-BOT.git
cd IRC-BOT
```

### Méthode 2 : Télécharger l'archive ZIP

1. Va sur : [https://github.com/claireivanenka/IRC-BOT](https://github.com/claireivanenka/IRC-BOT)
2. Clique sur **"Code"** → **"Download ZIP"**
3. Décompresse le fichier

```bash
unzip IRC-BOT-main.zip
cd IRC-BOT-main
```

---

## 🔧 Configuration initiale

### 1. Copier le fichier de configuration

```bash
# Optionnel : crée une copie de config.lua pour le personnaliser
cp config.lua config_custom.lua
```

### 2. Modifier la configuration

Édite `irc_bot.lua` ou `config.lua` avec ton éditeur préféré :

```bash
nano irc_bot.lua
# ou
vim irc_bot.lua
# ou
code irc_bot.lua
```

Modifie la section de configuration :

```lua
local config = {
    server = "irc.libera.chat",     -- Serveur IRC
    port = 6667,                     -- Port (6697 pour SSL)
    nick = "MonBot",                -- Nom du bot (doit être unique)
    user = "monbot",                -- Identifiant utilisateur
    realname = "Mon Bot Personnel", -- Nom affiché
    channel = "#mon-channel",       -- Channel à rejoindre
    use_ssl = false,                 -- true pour SSL
}
```

---

## 🚀 Vérification de l'installation

### Tester les dépendances

```bash
# Tester Lua
lua -v

# Tester lua-socket
lua -e "require('socket'); print('lua-socket: OK')"

# Tester lua-sec (optionnel)
lua -e "require('ssl'); print('lua-sec: OK')" 2>/dev/null || echo "lua-sec: non installé"
```

### Exécuter les tests unitaires

```bash
lua test_functions.lua
```

✅ **Résultat attendu** : `🎉 Tous les tests ont réussi !`

---

## 📁 Structure du projet

```
IRC-BOT/
├── irc_bot.lua              # Script principal du bot
├── config.lua               # Configuration par défaut
├── config_custom.lua        # Configuration personnalisée (optionnel)
├── start_bot.sh             # Script de lancement
├── test_functions.lua       # Tests unitaires
├── Makefile                 # Automatisation (make install, make run, etc.)
├── README.md                # Documentation générale
├── .gitignore               # Fichiers à ignorer par Git
└── docs/                    # Documentation détaillée
    ├── INSTALLATION.md      # Guide d'installation (ce fichier)
    ├── CONFIGURATION.md     # Guide de configuration
    ├── USAGE.md             # Guide d'utilisation
    └── TROUBLESHOOTING.md   # Dépannage
```

---

## 🎯 Prochaines étapes

Une fois l'installation terminée :

1. [Configurer le bot](CONFIGURATION.md)
2. [Démarrer et utiliser le bot](USAGE.md)
3. [Résoudre les problèmes éventuels](TROUBLESHOOTING.md)

---

## 📚 Voir aussi

- [Guide de configuration](CONFIGURATION.md)
- [Guide d'utilisation](USAGE.md)
- [Dépannage](TROUBLESHOOTING.md)
