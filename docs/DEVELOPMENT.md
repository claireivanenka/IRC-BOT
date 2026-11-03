# 👨‍💻 Guide de développement

Comment contribuer au bot IRC et l'étendre avec de nouvelles fonctionnalités.

---

## 📥 Prérequis pour le développement

### Outils recommandés

```bash
# Lua et outils
sudo apt install lua5.4 lua-socket lua-sec luarocks

# Outils de développement
sudo apt install git make curl

# Éditeurs (optionnels)
sudo apt install vim nano code
```

### Structure recommandée

```
IRC-BOT/
├── src/                # Code source principal
│   └── irc_bot.lua     # Script principal
├── lib/                # Bibliothèques Lua
├── config/             # Fichiers de configuration
├── docs/               # Documentation
├── tests/              # Tests unitaires
├── scripts/            # Scripts utilitaires
└── Makefile            # Automatisation
```

---

## 🏗️ Architecture du bot

### Diagramme des composants

```
+------------------+
|   IRC Bot Lua    |
+------------------+
        |
        v
+------------------+
|  Configuration   |  <- config.lua
+------------------+
        |
        v
+------------------+
|   Connexion IRC  |  <- socket, ssl
+------------------+
        |
        v
+------------------+
|  Parsing Messages |  <- parse_irc_message
+------------------+
        |
        v
+------------------+
| Command Handlers |  <- handle_message
+------------------+
        |
        v
+------------------+
|   Fonctions      |  <- clean_youtube_url, show_menu
|   Utilitaires    |
+------------------+
```

---

## 🔧 Extendre le bot

### 1. Ajouter une nouvelle commande

#### Étapes :

1. **Définis ta commande** dans `handle_message` :

```lua
function handle_message(msg)
    -- ... code existant ...
    
    -- Nouvelle commande : !bonjour
    if message:match(command_prefix .. "bonjour") then
        send_irc_message(target, "Bonjour " .. nick .. " ! 👋")
    end
    
    -- Nouvelle commande avec argument : !recherche <terme>
    local recherche = message:match(command_prefix .. "recherche (%S+)")
    if recherche then
        send_irc_message(target, "Tu cherches : " .. recherche)
    end
end
```

2. **Met à jour l'aide** :

```lua
if message:match(command_prefix .. "help") then
    local help = "Commandes : !clean, !menu, !bonjour, !recherche, !help"
    send_irc_message(target, help)
end
```

---

### 2. Ajouter une nouvelle fonctionnalité de nettoyage

#### Exemple : Nettoyer les URLs Twitter

```lua
function clean_twitter_url(url)
    -- Supprime les paramètres de tracking Twitter
    return url:gsub("?.*", ""):gsub("#.*", "")
end

-- Dans handle_message :
if message:match(command_prefix .. "clean_twitter %S+") then
    local url = message:match(command_prefix .. "clean_twitter (%S+)")
    local cleaned = clean_twitter_url(url)
    send_irc_message(target, nick .. ": " .. cleaned)
end
```

---

### 3. Ajouter un nouveau menu

#### Exemple : Menu des desserts

```lua
-- Dans la table menu
local menu = {
    boissons = {...},
    nourriture = {...},
    desserts = {
        {"Tiramisu", 6.50},
        {"Crème brûlée", 7.00},
        {"Mousse au chocolat", 5.50},
    }
}

-- Met à jour show_menu
function show_menu(category)
    local output = "=== Menu ===\n"
    
    if category == "desserts" then
        output = output .. "\n🍰 **DESSERTS** 🍰\n"
        for i, item in ipairs(menu.desserts) do
            output = output .. string.format("%d. %s - €%.2f\n", i, item[1], item[2])
        end
    -- ... reste du code
    end
    
    return output
end
```

---

### 4. Ajouter une tâche planifiée

#### Exemple : Message de bienvenue chaque jour à midi

```lua
local last_welcome = nil

function check_daily_welcome()
    local now = os.date("*t")
    if now.hour == 12 and now.min == 0 and (last_welcome == nil or last_welcome ~= now.day) then
        last_welcome = now.day
        send_irc_message(config.channel, "🌞 Bonjour à tous ! C'est l'heure de la pause déjeuner !")
    end
end

-- Dans la boucle principale, ajoute :
check_daily_welcome()
```

---

### 5. Travailler avec la base de données PostgreSQL

#### Architecture de la base de données

Le bot utilise `luasql.postgres` pour interagir avec PostgreSQL. Voici comment étendre les fonctionnalités de la base de données.

#### Exemple : Ajouter une nouvelle table

1. **Crée la table en SQL** :
```sql
CREATE TABLE user_preferences (
    id SERIAL PRIMARY KEY,
    nick VARCHAR(100) NOT NULL UNIQUE,
    favorite_drink VARCHAR(100),
    theme VARCHAR(50) DEFAULT 'light',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

2. **Ajoute la fonction de connexion dans le bot** :
```lua
-- Dans init_database()
function init_database()
    local luasql = require("luasql.postgres")
    db_env = luasql.postgres()
    
    -- Connexion
    db_conn = db_env:connect(
        config.database.database,
        config.database.user,
        config.database.password,
        config.database.host,
        config.database.port
    )
    
    if not db_conn then return false end
    
    -- Crée les tables si elles n'existent pas
    create_menus_table()
    create_user_preferences_table()  -- Nouvelle fonction
    
    return true
end

function create_user_preferences_table()
    db_conn:execute([[ 
        CREATE TABLE IF NOT EXISTS user_preferences (
            id SERIAL PRIMARY KEY,
            nick VARCHAR(100) NOT NULL UNIQUE,
            favorite_drink VARCHAR(100),
            theme VARCHAR(50) DEFAULT 'light',
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
    ]])
end
```

3. **Ajoute des fonctions utilitaires** :
```lua
-- Sauvegarder les préférences d'un utilisateur
function save_user_preferences(nick, preferences)
    if not db_conn then return false end
    
    local cursor = db_conn:execute(
        "SELECT 1 FROM user_preferences WHERE nick = '" .. escape_sql(nick) .. "'"
    )
    
    if cursor and cursor:fetch() then
        -- Update
        cursor:close()
        db_conn:execute(
            "UPDATE user_preferences SET favorite_drink = '" .. escape_sql(preferences.favorite_drink) .. "', " ..
            "theme = '" .. escape_sql(preferences.theme) .. "' " ..
            "WHERE nick = '" .. escape_sql(nick) .. "'"
        )
    else
        -- Insert
        if cursor then cursor:close() end
        db_conn:execute(
            "INSERT INTO user_preferences (nick, favorite_drink, theme) VALUES (" ..
            "'" .. escape_sql(nick) .. "', " ..
            "'" .. escape_sql(preferences.favorite_drink) .. "', " ..
            "'" .. escape_sql(preferences.theme) .. "')"
        )
    end
    return true
end

-- Charger les préférences
function load_user_preferences(nick)
    if not db_conn then return nil end
    
    local cursor = db_conn:execute(
        "SELECT * FROM user_preferences WHERE nick = '" .. escape_sql(nick) .. "'"
    )
    
    if not cursor then return nil end
    
    local row = cursor:fetch({}, "a")
    cursor:close()
    return row
end
```

#### Exemple : Commande pour gérer les préférences

```lua
-- Dans handle_message :
local set_pref = message:match(command_prefix .. "set_pref (%S+) (%S+) (.+)")
if set_pref then
    local nick_pref = set_pref
    local pref_type = set_pref
    local pref_value = set_pref
    
    -- Sauvegarde dans la base
    save_user_preferences(msg.nick, {
        [pref_type] = pref_value
    })
    
    send_irc_message(target, "✅ Préférence " .. pref_type .. " mise à jour pour " .. msg.nick)
end
```

#### Conseils pour PostgreSQL

- **Échappement des strings** : Toujours utiliser une fonction d'échappement pour éviter les injections SQL
- **Gestion des erreurs** : Vérifie que `db_conn` est valide avant chaque requête
- **Fermeture des cursors** : N'oublie pas de fermer les cursors après utilisation
- **Transactions** : Pour les opérations multiples, utilise des transactions

---

### 6. Ajouter un système de plugins

#### Architecture de base :

```lua
-- Charger un plugin
function load_plugin(name)
    local path = "plugins/" .. name .. ".lua"
    local plugin = dofile(path)
    if plugin and plugin.init then
        plugin.init()
    end
    return plugin
end

-- Appeler les hooks des plugins
function call_plugin_hook(hook_name, ...)
    for _, plugin in ipairs(loaded_plugins) do
        if plugin[hook_name] then
            plugin[hook_name](...)
        end
    end
end

-- Dans handle_message :
call_plugin_hook("on_message", msg)
```

#### Exemple de plugin :

Crée le fichier `plugins/welcome.lua` :

```lua
local M = {}

function M.init()
    print("Plugin Welcome chargé")
end

function M.on_message(msg)
    if msg.message:match("!welcome") then
        send_irc_message(msg.target, "Bienvenue sur le channel, " .. msg.nick .. " !")
    end
end

return M
```

---

## 🧪 Écrire des tests

### Utiliser le framework de test existant

Le fichier `test_functions.lua` contient déjà un framework de test simple.

#### Exemple : Tester une nouvelle fonction

```lua
-- Dans test_functions.lua

-- Ajoute ta fonction à tester
function clean_twitter_url(url)
    return url:gsub("?.*", ""):gsub("#.*", "")
end

-- Ajoute des tests
function run_tests()
    -- ... tests existants ...
    
    print("\n--- Tests: Nettoyage Twitter ---")
    
    local twitter1 = clean_twitter_url("https://twitter.com/user/status/123?s=20&t=abc")
    assert_equals(twitter1, "https://twitter.com/user/status/123", "Nettoyage URL Twitter")
    
    local twitter2 = clean_twitter_url("https://twitter.com/user")
    assert_equals(twitter2, "https://twitter.com/user", "URL Twitter sans paramètres")
end
```

### Utiliser LuaUnit (optionnel)

Installe LuaUnit :

```bash
luarocks install luunit
```

Puis crée un fichier de test :

```lua
local lu = require("luunit")
local test = lu.TestCase("YouTube Cleaner")

function test:clean_basic_url()
    local result = clean_youtube_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    lu.assertEquals(result, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
end

function test:clean_url_with_trackers()
    local result = clean_youtube_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share")
    lu.assertEquals(result, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
end

lu.run()
```

---

## 📊 Optimiser les performances

### 1. Réduire les appels regex

Les regex peuvent être coûteuses. Utilise des motifs simples quand possible :

```lua
-- Moins efficace
if url:match("youtube%.com/watch") then
    -- ...
end

-- Plus efficace
if url:find("youtube.com/watch") then
    -- ...
end
```

### 2. Mettre en cache les résultats

```lua
local url_cache = {}

function clean_youtube_url(url)
    if url_cache[url] then
        return url_cache[url]
    end
    
    -- ... calcul ...
    local result = ...
    
    url_cache[url] = result
    return result
end
```

### 3. Utiliser des coroutines pour le multitâche

Lua supporte les coroutines pour gérer plusieurs tâches :

```lua
local co = coroutine.create(function()
    while true do
        -- Tâche en arrière-plan
        coroutine.yield()
    end
end)

-- Dans la boucle principale
coroutine.resume(co)
```

---

## 🔒 Sécurité

### 1. Valider les entrées

Toujours valider les URLs et autres entrées :

```lua
function is_valid_url(url)
    return url:match("^https?://[^/%.%s]+") ~= nil
end

function handle_message(msg)
    if message:match(command_prefix .. "clean %S+") then
        local url = message:match(command_prefix .. "clean (%S+)")
        if is_valid_url(url) then
            local cleaned = clean_youtube_url(url)
            send_irc_message(target, nick .. ": " .. cleaned)
        else
            send_irc_message(target, nick .. ": URL invalide")
        end
    end
end
```

### 2. Limiter la fréquence des commandes

```lua
local command_cooldown = {}

function handle_message(msg)
    local now = os.time()
    local key = msg.nick .. ":" .. msg.message:match("^%S+")
    
    if command_cooldown[key] and now - command_cooldown[key] < 5 then
        send_irc_message(target, nick .. ": Attends 5 secondes avant de réessayer")
        return
    end
    
    command_cooldown[key] = now
    -- ... reste du code
end
```

---

## 📦 Gérer les dépendances

### Utiliser LuaRocks

LuaRocks est le gestionnaire de paquets pour Lua.

#### Installer une dépendance :

```bash
luarocks install nom_du_paquet
```

#### Exemples de paquets utiles :

```bash
# JSON
luarocks install dkjson

# Base64
luarocks install base64

# HTTP
luarocks install lua-http

# XML
luarocks install lxsh
```

### Créer un fichier rocks.spec

Pour partager ton bot avec LuaRocks :

```lua
package = "irc-bot"
version = "1.0.0"
source = {
    url = "git://github.com/claireivanenka/IRC-BOT.git"
}
dependencies = {
    "lua >= 5.1",
    "luasocket >= 3.0"
}
```

---

## 📤 Déployer le bot

### 1. Créer un binaire avec Lua

Utilise **LuaJIT** ou **Squirrel** pour créer un exécutable.

#### Avec LuaJIT :

```bash
sudo apt install luajit
luajit irc_bot.lua
```

### 2. Utiliser Docker

Crée un Dockerfile :

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    lua5.4 \
    lua-socket \
    lua-sec \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

CMD ["lua", "irc_bot.lua"]
```

Puis construis et lance :

```bash
docker build -t irc-bot .
docker run -d --name my-irc-bot irc-bot
```

### 3. Déployer sur un serveur

#### Avec systemd (recommandé) :

Crée le fichier `/etc/systemd/system/irc_bot.service` :

```ini
[Unit]
Description=IRC Bot Lua
After=network.target

[Service]
User=claire
WorkingDirectory=/home/claire/IRC-BOT
ExecStart=/usr/bin/lua /home/claire/IRC-BOT/irc_bot.lua
Restart=always
RestartSec=5

# Logging
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=irc_bot

[Install]
WantedBy=multi-user.target
```

Puis :

```bash
# Recharger systemd
sudo systemctl daemon-reload

# Démarrer le service
sudo systemctl start irc_bot

# Activer au démarrage
sudo systemctl enable irc_bot

# Voir les logs
journalctl -u irc_bot -f

# Redémarrer
sudo systemctl restart irc_bot

# Arrêter
sudo systemctl stop irc_bot
```

---

## 📝 Contribuer au projet

### 1. Fork le dépôt

1. Va sur : [https://github.com/claireivanenka/IRC-BOT](https://github.com/claireivanenka/IRC-BOT)
2. Clique sur **"Fork"**

### 2. Clone ton fork

```bash
git clone git@github.com:TON_NOM/IRC-BOT.git
cd IRC-BOT
```

### 3. Crée une branche

```bash
git checkout -b feature-ma-nouvelle-fonctionnalite
```

### 4. Fais tes modifications

- Code ta nouvelle fonctionnalité
- Ajoute des tests
- Met à jour la documentation

### 5. Commit et pousse

```bash
git add .
git commit -m "Ajout de ma nouvelle fonctionnalité"
git push origin feature-ma-nouvelle-fonctionnalite
```

### 6. Crée une Pull Request

1. Va sur ton dépôt GitHub
2. Clique sur **"Pull requests"** → **"New pull request"**
3. Sélectionne ta branche
4. Décris tes modifications
5. Clique sur **"Create pull request"**

---

## 📚 Bonnes pratiques

### 1. Nommage

- **Variables** : `snake_case` (ex: `video_id`, `youtube_url`)
- **Fonctions** : `snake_case` (ex: `clean_youtube_url`, `handle_message`)
- **Constantes** : `UPPER_SNAKE_CASE` (ex: `MAX_RETRIES`, `DEFAULT_PORT`)

### 2. Commentaires

- **Fonctions** : Documente le but et les paramètres
- **Code complexe** : Ajoute des commentaires explicatifs
- **TODO** : Utilise `-- TODO: ` pour les améliorations futures

```lua
-- Nettoie une URL YouTube en supprimant les paramètres de tracking
-- @param url string : L'URL YouTube à nettoyer
-- @return string : L'URL nettoyée
function clean_youtube_url(url)
    -- ...
end
```

### 3. Gestion des erreurs

- Utilise `pcall` pour capturer les erreurs
- Affiche des messages d'erreur clairs
- Ne laisse pas le bot planter

```lua
local ok, err = pcall(function()
    -- Code qui peut échouer
end)

if not ok then
    print("Erreur : " .. err)
    -- Gestion de l'erreur
end
```

### 4. Tests

- **Teste chaque fonction** individuellement
- **Couvre les cas limites** (URLs vides, formats invalides, etc.)
- **Automatise les tests** avec `make test`

---

## 🎯 Roadmap / Idées de développement

### Fonctionnalités possibles

| Priorité | Fonctionnalité | Description |
|----------|----------------|-------------|
| ⭐⭐⭐ | Système de plugins | Charger des fonctionnalités dynamiquement |
| ⭐⭐⭐ | Base de données | Stocker les préférences des utilisateurs |
| ⭐⭐ | Interface Web | Contrôler le bot via une interface web |
| ⭐⭐ | Commandes vocales | Intégration avec Discord/Slack |
| ⭐ | IA | Réponses intelligentes avec LLM |
| ⭐ | Statistiques | Suivre l'utilisation du bot |
| ⭐ | Modération | Fonctionnalités de modération de channel |

### Contributions bienvenues

- ✅ **Nouveaux parseurs d'URL** (Vimeo, Dailymotion, etc.)
- ✅ **Amélioration du menu** (catégories, sous-menus, etc.)
- ✅ **Nouvelles tâches planifiées** (rappels, événements, etc.)
- ✅ **Support de plus de serveurs IRC**
- ✅ **Amélioration de la documentation**
- ✅ **Traduction en d'autres langues**

---

## 📚 Voir aussi

- [Installation](INSTALLATION.md)
- [Configuration](CONFIGURATION.md)
- [Utilisation](USAGE.md)
- [Dépannage](TROUBLESHOOTING.md)

---

**Bon développement !** 🚀
