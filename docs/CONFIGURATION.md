# ⚙️ Configuration du Bot IRC

Guide complet pour configurer ton bot selon tes besoins.

---

## 📝 Fichiers de configuration

Le bot peut être configuré de plusieurs manières :

| Fichier | Description | Requis |
|---------|-------------|--------|
| `irc_bot.lua` | Configuration intégrée | ✅ Oui |
| `config.lua` | Configuration par défaut | ❌ Non |
| `config_custom.lua` | Configuration personnalisée | ❌ Non |

---

## 🔧 Configuration de base

### 1. Configuration dans `irc_bot.lua`

Édite le fichier principal et modifie la section `config` :

```lua
local config = {
    -- === CONNEXION IRC ===
    server = "irc.libera.chat",     -- Serveur IRC
    port = 6667,                     -- Port (6667 ou 6697)
    use_ssl = false,                 -- true pour SSL (port 6697)
    
    -- === IDENTITÉ DU BOT ===
    nick = "YouTubeCleanBot",        -- Nom du bot (doit être unique)
    user = "youtube_clean_bot",     -- Identifiant utilisateur
    realname = "Bot de nettoyage YouTube et Menu",
    
    -- === CANAUX ===
    channel = "#test",               -- Channel principal à rejoindre
    
    -- === TÂCHES PLANIFIÉES ===
    hourly_date = true,              -- Exécuter /exec -o date chaque heure
}
```

### 2. Configuration avec `config.lua`

Le fichier `config.lua` retourne une table de configuration :

```lua
return {
    server = {
        host = "irc.libera.chat",
        port = 6667,
        use_ssl = false,
    },
    bot = {
        nick = "MonBot",
        user = "monbot",
        realname = "Mon Bot",
    },
    channels = {
        "#mon-channel",
        "#autre-channel",
    },
    command_prefix = "!",
}
```

---

## 🌐 Configuration des serveurs IRC

### Serveurs IRC populaires

| Serveur | Port (non-SSL) | Port (SSL) | Notes |
|---------|----------------|------------|-------|
| `irc.libera.chat` | 6667 | 6697 | Recommandé pour les projets open source |
| `irc.oftc.net` | 6667 | 6697 | Bon pour les tests |
| `irc.freenode.net` | 6667 | 6697 | Historique |
| `irc.undernet.org` | 6667 | - | |

### Exemple : Configuration pour Libera.Chat avec SSL

```lua
local config = {
    server = "irc.libera.chat",
    port = 6697,
    use_ssl = true,
    nick = "MonBotSecure",
    channel = "#mon-channel",
}
```

---

## 👥 Configuration des canaux

### Rejoindre un seul canal

```lua
config = {
    channel = "#mon-channel",
}
```

### Rejoindre plusieurs canaux

Modifie le code pour rejoindre plusieurs canaux :

```lua
-- Dans irc_bot.lua, après la connexion
local channels = {"#channel1", "#channel2", "#channel3"}
for _, channel in ipairs(channels) do
    join_channel(channel)
end
```

---

## 🍽️ Personnalisation du menu

### Modifier les boissons

```lua
local menu = {
    boissons = {
        {"Café", 2.50},
        {"Thé", 2.00},
        {"Jus d'orange", 3.00},
        {"Soda", 2.75},
        {"Eau", 1.50},
        -- Ajoute tes propres boissons
        {"Expresso", 3.00},
        {"Capuccino", 4.50},
    },
    -- ...
}
```

### Modifier la nourriture

```lua
local menu = {
    -- ...
    nourriture = {
        {"Croissant", 3.00},
        {"Pain au chocolat", 3.50},
        {"Sandwich", 7.50},
        -- Ajoute tes propres plats
        {"Pâtes", 10.00},
        {"Riz", 8.00},
    }
}
```

### Ajouter des catégories

Tu peux ajouter de nouvelles catégories au menu :

```lua
local menu = {
    boissons = {...},
    nourriture = {...},
    desserts = {
        {"Tiramisu", 6.50},
        {"Crème brûlée", 7.00},
    }
}
```

Puis modifie la fonction `show_menu` pour afficher les desserts.

---

## ⏰ Configuration des tâches planifiées

### Activer/désactiver la date horaire

```lua
-- Dans la configuration
local hourly_date_enabled = true  -- true pour activer, false pour désactiver
```

### Modifier l'intervalle

Par défaut, la date est affichée chaque heure ronde (00:00, 01:00, etc.).
Pour modifier l'intervalle, édite la fonction `check_hourly_task` :

```lua
function check_hourly_task()
    local now = os.date("*t")
    -- Chaque 30 minutes
    if now.min % 30 == 0 and (last_time == nil or last_time ~= now.min) then
        last_time = now.min
        send_irc_message(config.channel, "/exec -o date")
    end
end
```

---

## 🔐 Configuration des commandes

### Modifier le préfixe des commandes

Par défaut, les commandes commencent par `!`. Pour le changer :

```lua
local command_prefix = "."  -- Les commandes seront .clean, .menu, etc.
```

Puis modifie toutes les conditions dans `handle_message` :

```lua
-- Remplace !clean par ..clean
if message:match(command_prefix .. "clean %S+") then
    -- ...
end
```

### Ajouter une nouvelle commande

Pour ajouter une commande personnalisée :

```lua
-- Dans handle_message, ajoute :
if message:match(command_prefix .. "maCommande") then
    send_irc_message(target, "Réponse à ma commande !")
end
```

---

## 🛡️ Configuration de la sécurité

### Limiter les commandes à certains utilisateurs

```lua
local admins = {
    ["ton_nick"] = true,
    ["autre_nick"] = true,
}

function handle_message(msg)
    -- ...
    if message:match(command_prefix .. "admin") then
        if admins[msg.nick] then
            send_irc_message(target, "Commande admin exécutée !")
        else
            send_irc_message(target, "Accès refusé.")
        end
    end
end
```

### Bloquer certains canaux

```lua
local blocked_channels = {
    ["#spam"] = true,
}

function join_channel(channel)
    if not blocked_channels[channel] then
        irc_socket:send("JOIN " .. channel .. "\r\n")
    end
end
```

---

## 📊 Configuration avancée

### Gérer les erreurs de connexion

```lua
local reconnect_attempts = 0
local max_reconnect_attempts = 5

function connect_irc()
    -- ... code existant ...
    
    if not result then
        reconnect_attempts = reconnect_attempts + 1
        if reconnect_attempts < max_reconnect_attempts then
            print("Tentative de reconnexion " .. reconnect_attempts .. "/" .. max_reconnect_attempts)
            socket.sleep(5)
            return connect_irc()
        else
            print("Échec de connexion après " .. max_reconnect_attempts .. " tentatives")
            return false
        end
    end
    reconnect_attempts = 0
    return true
end
```

### Logger les messages

```lua
local log_file = io.open("bot.log", "a")

function send_irc_message(target, message)
    if log_file then
        log_file:write(os.date("%Y-%m-%d %H:%M:%S") .. " [" .. target .. "] " .. message .. "\n")
        log_file:flush()
    end
    if connected and irc_socket then
        irc_socket:send("PRIVMSG " .. target .. " :" .. message .. "\r\n")
    end
end
```

---

## 🗄️ Configuration PostgreSQL

### Activer la sauvegarde en base de données

Le bot peut sauvegarder **les menus personnalisés** et **les URLs YouTube nettoyées** dans une base de données PostgreSQL au lieu d'un fichier local.

#### Configuration minimale

```lua
return {
    -- ... autres configurations ...
    
    database = {
        enabled = true,            -- Activer PostgreSQL
        host = "localhost",        -- Adresse du serveur
        port = 5432,               -- Port PostgreSQL
        database = "irc_bot",      -- Nom de la base
        user = "irc_user",         -- Utilisateur
        password = "motdepasse",  -- Mot de passe
        menus_table = "custom_menus",  -- Table pour les menus
        -- Le bot utilise aussi la table 'cleaned_urls' pour les URLs nettoyées
    }
}
```

#### Configuration avancée

| Option | Type | Description | Valeur par défaut |
|--------|------|-------------|-------------------|
| `enabled` | boolean | Activer/désactiver PostgreSQL | `false` |
| `host` | string | Adresse du serveur PostgreSQL | `localhost` |
| `port` | number | Port de connexion | `5432` |
| `database` | string | Nom de la base de données | `irc_bot` |
| `user` | string | Nom d'utilisateur | `irc_user` |
| `password` | string | Mot de passe | `irc_password` |
| `menus_table` | string | Nom de la table pour les menus personnalisés | `custom_menus` |

> ⚠️ **Note** : Le bot utilise également la table `cleaned_urls` pour stocker les URLs YouTube nettoyées. Cette table est créée automatiquement ou peut être créée manuellement avec le schéma fourni dans `docs/cleaned_urls_schema.sql`.

### Installation de PostgreSQL

#### Sur Debian/Ubuntu

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

#### Configuration PostgreSQL

1. Crée un utilisateur PostgreSQL :
   ```bash
   sudo -u postgres createuser -P irc_user
   ```

2. Crée la base de données :
   ```bash
   sudo -u postgres createdb -O irc_user irc_bot
   ```

3. Connecte-toi à la base et crée les tables :
   
   **Option 1** : Exécute les schémas SQL fournis
   ```bash
   psql -U irc_user -d irc_bot -f docs/database_schema.sql
   psql -U irc_user -d irc_bot -f docs/cleaned_urls_schema.sql
   ```
   
   **Option 2** : Crée les tables manuellement
   ```sql
   -- Table pour les menus personnalisés
   CREATE TABLE custom_menus (
       id SERIAL PRIMARY KEY,
       name VARCHAR(100) NOT NULL UNIQUE,
       content TEXT NOT NULL,
       created_at TIMESTAMP NOT NULL DEFAULT NOW(),
       created_by VARCHAR(100) NOT NULL
   );
   
   -- Table pour les URLs nettoyées
   CREATE TABLE cleaned_urls (
       id SERIAL PRIMARY KEY,
       original_url TEXT NOT NULL,
       cleaned_url TEXT NOT NULL,
       created_at TIMESTAMP NOT NULL DEFAULT NOW(),
       cleaned_by VARCHAR(100) NOT NULL,
       ip_address VARCHAR(45),
       UNIQUE(original_url)
   );
   ```

### Utilisation avec Docker

```yaml
version: '3'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: irc_bot
      POSTGRES_USER: irc_user
      POSTGRES_PASSWORD: irc_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
volumes:
  postgres_data:
```

### Installation de luasql.postgres

Le bot utilise la bibliothèque `luasql.postgres` pour se connecter à PostgreSQL.

```bash
sudo apt install lua-sql-postgres
```

Ou avec LuaRocks :
```bash
luarocks install luasql-postgres
```

### Dépannage

- **Erreur de connexion** : Vérifie que PostgreSQL est en cours d'exécution et que les identifiants sont corrects.
- **Table manquante** : Le bot essaye de créer les tables automatiquement au premier démarrage. Sinon, exécute les schémas manuellement.
- **Permissions** : Assure-toi que l'utilisateur a les droits sur la base de données.
- **Colonne manquante** : Si tu as une ancienne version, exécute `ALTER TABLE cleaned_urls ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45);`

### Fallback automatique

Si PostgreSQL n'est pas disponible (connexion échouée), le bot basculera automatiquement sur le système de sauvegarde par fichier local pour les menus personnalisés. Les URLs nettoyées ne seront pas sauvegardées mais le bot continuera de fonctionner.

### Structure des tables

Pour plus de détails sur les schémas, consulte :
- `docs/database_schema.sql` - Schéma pour les menus personnalisés
- `docs/cleaned_urls_schema.sql` - Schéma pour les URLs nettoyées

---

## 📤 Exemple de configuration complète

```lua
local config = {
    -- Serveur
    server = "irc.libera.chat",
    port = 6667,
    use_ssl = false,
    
    -- Bot
    nick = "MonSuperBot",
    user = "monsuperbot",
    realname = "Mon Bot Personnel",
    
    -- Canaux
    channels = {"#mon-channel", "#test"},
    
    -- Commandes
    command_prefix = "!",
    
    -- Menu
    menu = {
        boissons = {
            {"Café", 2.50},
            {"Thé", 2.00},
        },
        nourriture = {
            {"Croissant", 3.00},
            {"Sandwich", 7.50},
        }
    },
    
    -- Tâches planifiées
    hourly_date = true,
}
```

---

## 📚 Voir aussi

- [Installation](INSTALLATION.md)
- [Utilisation](USAGE.md)
- [Dépannage](TROUBLESHOOTING.md)
