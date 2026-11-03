# 📝 Système de Logging

Le bot IRC inclut un **système de logging complet** pour suivre toutes les conversations et événements.

---

## 🚀 Activation du logging

Le logging est **activé par défaut** dans la configuration. Pour le désactiver ou le personnaliser :

```lua
-- Dans irc_bot.lua
config = {
    -- ...
    logging = {
        enabled = true,              -- Activer/désactiver le logging
        filename = "irc_bot.log",    -- Nom du fichier de log
        max_size = 10 * 1024 * 1024,  -- Taille max (10 Mo)
        max_files = 5,                -- Nombre max de backups
        log_incoming = true,         -- Logger les messages entrants
        log_outgoing = true,         -- Logger les messages sortants
        log_pings = false,            -- Logger les PING/PONG
        log_errors = true,            -- Logger les erreurs
    }
}
```

---

## 📁 Fichiers de log

### Emplacement
- **Fichier principal** : `irc_bot.log` (dans le même dossier que le bot)
- **Fichiers de backup** : `irc_bot.log.1`, `irc_bot.log.2`, etc.

### Rotation automatique
Lorsque le fichier `irc_bot.log` atteint **10 Mo** (par défaut), il est automatiquement renommé et un nouveau fichier est créé.

**Exemple de rotation :**
```
irc_bot.log       (fichier actuel, < 10 Mo)
irc_bot.log.1     (ancien fichier, 10 Mo)
irc_bot.log.2     (encore plus ancien)
irc_bot.log.3     
irc_bot.log.4     
irc_bot.log.5     (le plus ancien, sera supprimé à la prochaine rotation)
```

---

## 📋 Format des logs

Chaque ligne de log suit ce format :

```
[TIMESTAMP] [TYPE] SOURCE: MESSAGE
```

### Exemples

```
[2024-11-02 14:30:45] [SYS] Bot: Démarrage du bot IRC
[2024-11-02 14:30:45] [SYS] Connection: Connecté au serveur irc.libera.chat:6667
[2024-11-02 14:30:46] [OUT] YouTubeCleanBot -> #test: 🤖 Bot démarré ! Commandes: !clean <url>, !menu, !help
[2024-11-02 14:31:02] [IN] Alice -> #test: !clean https://youtu.be/abc?feature=share
[2024-11-02 14:31:02] [OUT] YouTubeCleanBot -> #test: Alice: https://www.youtube.com/watch?v=abc
[2024-11-02 14:31:15] [IN] Bob -> #test: !menu
[2024-11-02 14:31:15] [OUT] YouTubeCleanBot -> #test: === Menu ===
...
[2024-11-02 15:00:00] [OUT] YouTubeCleanBot -> #test: /exec -o date
[2024-11-02 15:00:00] [SYS] Bot: Test de date : 15:00
[2024-11-02 15:30:00] [JOIN] Charlie -> a rejoint #test
```

---

## 🏷️ Types de logs

| Type | Description | Exemple |
|------|-------------|---------|
| `SYS` | Messages système | Démarrage, arrêt, connexion |
| `IN` | Messages entrants | Messages reçus des utilisateurs |
| `OUT` | Messages sortants | Messages envoyés par le bot |
| `JOIN` | Connexions | Un utilisateur rejoint un channel |
| `PING` | PING/PONG | Messages de keepalive |
| `ERR` | Erreurs | Erreurs de connexion ou d'exécution |

---

## 🔍 Lire les logs

### 1. Afficher le fichier de log actuel

```bash
cat irc_bot.log
```

### 2. Suivre les logs en temps réel

```bash
tail -f irc_bot.log
```

### 3. Afficher les dernières lignes

```bash
# Dernières 100 lignes
tail -n 100 irc_bot.log

# Dernières 50 lignes
tail -n 50 irc_bot.log
```

### 4. Filtrer les logs

```bash
# Filtrer par type
cat irc_bot.log | grep "\[IN\]"
cat irc_bot.log | grep "\[OUT\]"
cat irc_bot.log | grep "\[ERR\]"

# Filtrer par utilisateur
cat irc_bot.log | grep "Alice"

# Filtrer par date
cat irc_bot.log | grep "2024-11-02"

# Filtrer par commande
cat irc_bot.log | grep "!clean"
```

### 5. Statistiques de logs

```bash
# Nombre total de lignes
wc -l irc_bot.log

# Nombre de messages entrants
cat irc_bot.log | grep -c "\[IN\]"

# Nombre de messages sortants
cat irc_bot.log | grep -c "\[OUT\]"

# Nombre d'erreurs
cat irc_bot.log | grep -c "\[ERR\]"

# Utilisateurs actifs
cat irc_bot.log | grep "\[IN\]" | awk -F' -> ' '{print $1}' | sort | uniq -c | sort -nr
```

---

## ⚙️ Personnalisation avancée

### 1. Changer le format des logs

Modifie la fonction `log_message` dans `irc_bot.lua` :

```lua
function log_message(type, source, message)
    if not config.logging.enabled or not log_file then return end
    
    -- Format personnalisé
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_line = string.format("[%s] %s - %s: %s\n", timestamp, type, source, message)
    
    log_file:write(log_line)
    log_file:flush()
    -- ...
end
```

### 2. Rotation par date

Pour ajouter une rotation quotidienne :

```lua
-- Dans init_logging()
function init_logging()
    if not config.logging.enabled then return end
    
    -- Rotation par date
    local today = os.date("%Y-%m-%d")
    local current_date = os.date("%Y-%m-%d")
    
    -- Si le fichier existe et que ce n'est pas le même jour, le renommer
    local file = io.open(config.logging.filename, "r")
    if file then
        file:close()
        -- Lire la première ligne pour voir la date
        local first_line = io.open(config.logging.filename, "r"):read("*l")
        if first_line and not first_line:find(today) then
            os.rename(config.logging.filename, config.logging.filename .. "." .. os.date("%Y-%m-%d"))
        end
    end
    
    -- ... reste du code
end
```

### 3. Logger dans plusieurs fichiers

Pour séparer les logs par type :

```lua
local log_files = {
    all = nil,
    incoming = nil,
    outgoing = nil,
    errors = nil
}

function init_logging()
    if not config.logging.enabled then return end
    
    log_files.all = io.open("irc_bot.log", "a")
    log_files.incoming = io.open("irc_bot_incoming.log", "a")
    log_files.outgoing = io.open("irc_bot_outgoing.log", "a")
    log_files.errors = io.open("irc_bot_errors.log", "a")
end

function log_message(type, source, message)
    if not config.logging.enabled then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_line = string.format("[%s] %s: %s\n", timestamp, source, message)
    
    -- Logger dans tous les fichiers
    if log_files.all then
        log_files.all:write(log_line)
        log_files.all:flush()
    end
    
    -- Logger dans le fichier spécifique
    if type == "IN" and log_files.incoming then
        log_files.incoming:write(log_line)
        log_files.incoming:flush()
    elseif type == "OUT" and log_files.outgoing then
        log_files.outgoing:write(log_line)
        log_files.outgoing:flush()
    elseif type == "ERR" and log_files.errors then
        log_files.errors:write(log_line)
        log_files.errors:flush()
    end
end
```

### 4. Compression des logs

Pour compresser les anciens logs :

```bash
# Compresser les logs de plus de 7 jours
find . -name "irc_bot.log.*" -mtime +7 -exec gzip {} \;
```

---

## 🗃️ Gestion des logs

### 1. Nettoyer les anciens logs

```bash
# Supprimer les logs de plus de 30 jours
find . -name "irc_bot.log*" -mtime +30 -delete

# Conserver uniquement les 5 derniers backups
ls -t irc_bot.log.* | tail -n +6 | xargs rm -f
```

### 2. Archiver les logs

```bash
# Créer une archive tar.gz de tous les logs
tar -czvf irc_bot_logs_$(date +%Y-%m-%d).tar.gz irc_bot.log*

# Supprimer les logs après archivage
rm -f irc_bot.log*
```

---

## 🛡️ Sécurité des logs

### 1. Restreindre l'accès aux logs

```bash
# Donner la permission de lecture uniquement au propriétaire
chmod 600 irc_bot.log*

# Créer un groupe pour les logs
sudo groupadd log_readers
sudo chown :log_readers irc_bot.log*
sudo chmod 640 irc_bot.log*
```

### 2. Masquer les informations sensibles

Pour éviter de logger les informations sensibles :

```lua
function sanitize_message(message)
    -- Masquer les mots de passe, tokens, etc.
    return message:gsub("(password|token|secret|key)=[%w%-]+", "\1=*****")
end

function log_message(type, source, message)
    if not config.logging.enabled or not log_file then return end
    
    -- Sanitizer le message
    message = sanitize_message(message)
    
    -- ... reste du code
end
```

---

## 📊 Analyse des logs

### 1. Script d'analyse basique

Crée un fichier `analyze_logs.lua` :

```lua
local function analyze_logs(filename)
    local file = io.open(filename, "r")
    if not file then
        print("Fichier introuvable : " .. filename)
        return
    end
    
    local stats = {
        total = 0,
        by_type = {},
        by_user = {},
        by_channel = {},
        commands = {}
    }
    
    for line in file:lines() do
        stats.total = stats.total + 1
        
        -- Extraire le type
        local type = line:match("%[(%w+)%]")
        if type then
            stats.by_type[type] = (stats.by_type[type] or 0) + 1
        end
        
        -- Extraire l'utilisateur pour les messages IN
        if type == "IN" then
            local user = line:match("(%S+) ->")
            if user then
                stats.by_user[user] = (stats.by_user[user] or 0) + 1
            end
            
            -- Extraire les commandes
            local command = line:match("!(%w+)")
            if command then
                stats.commands[command] = (stats.commands[command] or 0) + 1
            end
        end
        
        -- Extraire le channel
        local channel = line:match("-> (%S+)") or line:match(": (%S+)")
        if channel and channel:match("^#") then
            stats.by_channel[channel] = (stats.by_channel[channel] or 0) + 1
        end
    end
    
    file:close()
    
    -- Afficher les statistiques
    print("=== Statistiques des logs ===")
    print("Total des lignes : " .. stats.total)
    print("\nPar type :")
    for type, count in pairs(stats.by_type) do
        print("  " .. type .. ": " .. count)
    end
    
    print("\nUtilisateurs actifs :")
    for user, count in pairs(stats.by_user) do
        print("  " .. user .. ": " .. count .. " messages")
    end
    
    print("\nCommandes utilisées :")
    for cmd, count in pairs(stats.commands) do
        print("  !" .. cmd .. ": " .. count .. " fois")
    end
    
    print("\nPar channel :")
    for channel, count in pairs(stats.by_channel) do
        print("  " .. channel .. ": " .. count .. " messages")
    end
end

-- Utilisation
analyze_logs("irc_bot.log")
```

---

## 🚨 Problèmes courants

### Le fichier de log est trop gros
**Solution** : Réduis `max_size` ou augmente `max_files` :
```lua
config.logging.max_size = 5 * 1024 * 1024  -- 5 Mo
config.logging.max_files = 10
```

### Les logs ne s'affichent pas
**Solutions** :
1. Vérifie que `enabled = true`
2. Vérifie que le fichier est accessible en écriture
3. Vérifie les permissions : `chmod 666 irc_bot.log`

### Les backups de logs ne sont pas créés
**Solution** : Vérifie que le fichier atteint bien la taille max. Tu peux forcer une rotation manuellement :
```lua
rotate_logs()
```

### Les logs contiennent des informations sensibles
**Solution** : Utilise la fonction `sanitize_message` ou désactive le logging pour les messages sensibles.

---

## 📚 Voir aussi

- [Installation](INSTALLATION.md)
- [Configuration](CONFIGURATION.md)
- [Utilisation](USAGE.md)
- [Dépannage](TROUBLESHOOTING.md)
- [Développement](DEVELOPMENT.md)
