# 🚨 Dépannage du Bot IRC

Solutions aux problèmes courants avec ton bot IRC en Lua.

---

## 🔍 Diagnostic rapide

### 1. Vérifier que Lua est installé

```bash
lua -v
```

**Si non installé** :
```bash
sudo apt install lua5.4
```

---

### 2. Vérifier que lua-socket est installé

```bash
lua -e "require('socket')"
```

**Si erreur** :
```bash
sudo apt install lua-socket
```

---

### 3. Vérifier la syntaxe du script

```bash
luac5.4 -p irc_bot.lua
```

**Si erreur de syntaxe** : Le fichier contient une erreur. Voir le message d'erreur pour la corriger.

---

## ❌ Problèmes de connexion

### Erreur : `module 'socket' not found`

**Cause** : lua-socket n'est pas installé.

**Solution** :
```bash
sudo apt install lua-socket
```

---

### Erreur : `Error loading module 'socket.core'`

**Cause** : Version incompatible de lua-socket.

**Solution** :
```bash
sudo apt remove lua-socket
sudo apt install lua-socket
```

---

### Le bot ne se connecte pas au serveur IRC

**Causes possibles** :
1. Serveur IRC incorrect
2. Port incorrect
3. Nick déjà utilisé
4. Problème de réseau

**Solutions** :

1. **Vérifie le serveur et le port** :
   ```lua
   -- Dans irc_bot.lua
   config = {
       server = "irc.libera.chat",  -- Vérifie le nom
       port = 6667,                  -- 6667 ou 6697
   }
   ```

2. **Change de nick** :
   ```lua
   config.nick = "MonBotUnique123"  -- Ajoute des chiffres
   ```

3. **Teste la connexion avec telnet** :
   ```bash
   telnet irc.libera.chat 6667
   ```
   - Si ça ne fonctionne pas, le problème vient de ton réseau ou du serveur.

4. **Utilise SSL** :
   ```lua
   config = {
       use_ssl = true,
       port = 6697,
   }
   ```
   *N'oublie pas d'installer lua-sec* : `sudo apt install lua-sec`

---

### Erreur : `Permission denied` ou `Connection refused`

**Cause** : Le port est bloqué ou le serveur refuse la connexion.

**Solutions** :

1. **Essaie un autre port** :
   ```lua
   config.port = 6667  -- ou 6697 pour SSL
   ```

2. **Vérifie ton firewall** :
   ```bash
   sudo ufw status
   ```
   Si le firewall est actif, autorise le port :
   ```bash
   sudo ufw allow out 6667
   sudo ufw allow out 6697
   ```

3. **Essaie un autre serveur** :
   ```lua
   config.server = "irc.oftc.net"
   ```

---

### Erreur : `Could not resolve host`

**Cause** : Le nom du serveur est incorrect ou ton DNS ne fonctionne pas.

**Solutions** :

1. **Vérifie le nom du serveur** :
   ```bash
   ping irc.libera.chat
   ```
   Si ça ne fonctionne pas, essaie :
   ```bash
   ping 209.141.36.15  # IP de irc.libera.chat
   ```

2. **Change le serveur** :
   ```lua
   config.server = "irc.oftc.net"
   ```

---

## 🔄 Problèmes de déconnexion

### Le bot se déconnecte après quelques minutes

**Causes possibles** :
1. Le serveur IRC a un timeout
2. Le bot ne répond pas aux PING
3. Problème de connexion instable

**Solutions** :

1. **Ajoute un keepalive** :
   Dans `irc_bot.lua`, ajoute un envoi de PONG périodique :
   ```lua
   local last_ping = os.time()
   
   function check_keepalive()
       if os.time() - last_ping > 300 then  -- 5 minutes
           irc_socket:send("PING :keepalive\r\n")
           last_ping = os.time()
       end
   end
   ```
   Puis appelle `check_keepalive()` dans la boucle principale.

2. **Améliore la gestion des PING** :
   Vérifie que la fonction `parse_irc_message` gère bien les PING :
   ```lua
   if line:match("^PING :(.+)") then
       local token = line:match("^PING :(.+)")
       irc_socket:send("PONG :" .. token .. "\r\n")
   end
   ```

---

## 🤖 Problèmes de fonctionnement

### Le bot ne répond pas aux commandes

**Causes possibles** :
1. Le préfixe des commandes est différent
2. Le bot n'est pas dans le bon channel
3. Le bot a un problème de parsing

**Solutions** :

1. **Vérifie le préfixe** :
   Par défaut, les commandes commencent par `!`. Vérifie que tu utilises le bon préfixe.

2. **Vérifie le channel** :
   Le bot doit être dans le même channel que toi. Vérifie avec :
   ```lua
   print("Channel : " .. config.channel)
   ```

3. **Active le debug** :
   Ajoute des `print` dans `handle_message` :
   ```lua
   function handle_message(msg)
       print("Message reçu : " .. msg.message .. " de " .. msg.nick)
       -- ... reste du code
   end
   ```

---

### Erreur : `attempt to index a nil value`

**Cause** : Tu essaies d'accéder à une variable qui n'existe pas.

**Solution** :

1. **Vérifie que `msg` n'est pas nil** :
   ```lua
   function handle_message(msg)
       if not msg then return end
       -- ... reste du code
   end
   ```

2. **Vérifie les champs de `msg`** :
   ```lua
   if not msg.type or not msg.nick or not msg.message then return end
   ```

---

### Le nettoyage YouTube ne fonctionne pas

**Causes possibles** :
1. L'URL n'est pas au bon format
2. La fonction a un bug

**Solutions** :

1. **Teste manuellement** :
   ```bash
   lua -i irc_bot.lua
   ```
   Puis :
   ```lua
   > =clean_youtube_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share")
   ```
   *Doit retourner* : `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

2. **Vérifie le format de l'URL** :
   - Doit contenir `youtube.com` ou `youtu.be`
   - Doit avoir un paramètre `v=` ou être au format `youtu.be/ID`

3. **Corrige la fonction** :
   La fonction actuelle gère :
   - `youtube.com/watch?v=ID`
   - `youtu.be/ID`
   - `youtube.com/embed/ID`
   - `youtube.com/shorts/ID`

---

### Le menu ne s'affiche pas

**Causes possibles** :
1. La table `menu` est mal définie
2. La fonction `show_menu` a un problème

**Solutions** :

1. **Teste manuellement** :
   ```bash
   lua -i irc_bot.lua
   ```
   Puis :
   ```lua
   > =show_menu("boire")
   ```

2. **Vérifie la table `menu`** :
   Assure-toi que chaque élément a bien un nom et un prix :
   ```lua
   menu = {
       boissons = {
           {"Café", 2.50},  -- Format : {nom, prix}
           -- ...
       },
       -- ...
   }
   ```

---

## ⏰ Problèmes de tâches planifiées

### `/exec -o date` ne s'exécute pas chaque heure

**Causes possibles** :
1. La fonction `check_hourly_task` n'est pas appelée
2. Le temps système est incorrect

**Solutions** :

1. **Vérifie que la fonction est appelée** :
   Ajoute un `print` dans `check_hourly_task` :
   ```lua
   function check_hourly_task()
       print("Vérification de l'heure : " .. os.date("%H:%M"))
       -- ... reste du code
   end
   ```

2. **Vérifie l'heure système** :
   ```bash
   date
   ```

3. **Force un test** :
   Modifie temporairement la fonction pour tester :
   ```lua
   function check_hourly_task()
       send_irc_message(config.channel, "/exec -o date")
       send_irc_message(config.channel, "Test : " .. os.date("%H:%M"))
   end
   ```

---

## 📦 Problèmes de dépendances

### Erreur : `module 'ssl' not found`

**Cause** : lua-sec n'est pas installé.

**Solution** :
```bash
sudo apt install lua-sec
```

---

### Erreur : `module 'ltn12' not found`

**Cause** : ltn12 fait partie de lua-socket mais n'est pas chargé.

**Solution** :
```bash
sudo apt install --reinstall lua-socket
```

---

## 🌐 Problèmes de réseau

### Le bot ne peut pas se connecter à Internet

**Solutions** :

1. **Vérifie ta connexion** :
   ```bash
   ping google.com
   ```

2. **Vérifie le proxy** (si tu en utilises un) :
   ```bash
   echo $http_proxy
   echo $https_proxy
   ```
   Si tu as un proxy, configure Lua pour l'utiliser :
   ```lua
   require("socket.http")
   require("socket.proxy")
   -- Configurer le proxy
   ```

---

## 🛠️ Problèmes de performance

### Le bot consomme trop de CPU

**Causes possibles** :
1. Pas de délai dans la boucle principale
2. Trop de messages à traiter

**Solutions** :

1. **Ajoute un délai** :
   Dans la boucle principale :
   ```lua
   socket.sleep(0.1)  -- 100ms de délai
   ```

2. **Optimise le parsing** :
   Réduis le nombre de regex dans `parse_irc_message`.

---

## 📝 Journalisation pour le dépannage

### Activer les logs

Ajoute ce code au début de `irc_bot.lua` :

```lua
-- Ouverture du fichier de log
local log_file = io.open("irc_bot.log", "a")

-- Fonction de log
function log(message)
    if log_file then
        log_file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        log_file:flush()
    end
    print(message)
end

-- Remplace tous les print par log
```

Puis pour voir les logs :
```bash
tail -f irc_bot.log
```

---

## 🔄 Réinstallation complète

Si rien ne fonctionne, réinstalle tout :

```bash
# Supprimer les dépendances
sudo apt remove lua5.4 lua-socket lua-sec

# Supprimer le dossier du bot
rm -rf /home/claire/IRC-BOT

# Réinstaller
sudo apt install lua5.4 lua-socket lua-sec
cd /home/claire
git clone https://github.com/claireivanenka/IRC-BOT.git
cd IRC-BOT
```

---

## 💡 Astuces de dépannage

### 1. Utilise `strace` pour voir les appels système

```bash
strace -f -o bot_trace.log lua irc_bot.lua
```

### 2. Vérifie les connexions réseau

```bash
# Voir les connexions actives
netstat -tulnp | grep lua

# Voir le trafic réseau
sudo tcpdump -i any port 6667 -n
```

### 3. Teste avec un serveur IRC local

Installe un serveur IRC local pour tester :

```bash
# Installer InspIRCd (serveur IRC)
sudo apt install inspircd

# Configurer et démarrer
sudo systemctl start inspircd
```

Puis modifie `irc_bot.lua` :
```lua
config = {
    server = "127.0.0.1",
    port = 6667,
    nick = "TestBot",
    channel = "#test",
}
```

---

## 🗄️ Problèmes avec PostgreSQL

### Erreur : `module 'luasql.postgres' not found`

**Cause** : La bibliothèque luasql.postgres n'est pas installée.

**Solution** :
```bash
# Sur Debian/Ubuntu
sudo apt install lua-sql-postgres

# Ou avec LuaRocks
luarocks install luasql-postgres
```

**Vérification** :
```bash
lua -e "require('luasql.postgres'); print('OK')"
```

---

### Erreur : `connection failed: could not connect to server`

**Causes possibles** :
1. PostgreSQL n'est pas démarré
2. Mauvais identifiants
3. Mauvaise adresse IP/port
4. Firewall bloquant la connexion

**Solutions** :

**1. Vérifier que PostgreSQL est démarré** :
```bash
sudo systemctl status postgresql
```

Si non démarré :
```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**2. Tester la connexion manuellement** :
```bash
psql -h localhost -p 5432 -U irc_user -d irc_bot
```

**3. Vérifier les identifiants** dans `config.lua` :
```lua
database = {
    host = "localhost",
    port = 5432,
    database = "irc_bot",
    user = "irc_user",
    password = "ton_mot_de_passe",
}
```

**4. Vérifier le firewall** :
```bash
sudo ufw allow 5432
```

---

### Erreur : `relation 'custom_menus' does not exist`

**Cause** : La table n'a pas été créée.

**Solution 1** : Le bot essaie de créer la table automatiquement. Si cela échoue :

**Solution 2** : Crée la table manuellement :
```bash
psql -U irc_user -d irc_bot -f docs/database_schema.sql
```

Ou exécute ces commandes :
```sql
CREATE TABLE custom_menus (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL
);
```

---

### Erreur : `permission denied for table custom_menus`

**Cause** : L'utilisateur PostgreSQL n'a pas les permissions sur la table.

**Solution** :
```bash
# Se connecter en tant que postgres
sudo -u postgres psql

# Donner les permissions
GRANT ALL PRIVILEGES ON TABLE custom_menus TO irc_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO irc_user;

# Quitter
\q
```

---

### Le bot ne sauvegarde pas en PostgreSQL mais ne donne pas d'erreur

**Causes possibles** :
1. `enabled = false` dans la configuration
2. La connexion a échoué silencieusement
3. La table n'existe pas

**Solutions** :

**1. Vérifier que PostgreSQL est activé** :
```lua
-- Dans config.lua ou config_custom.lua
database = {
    enabled = true,  -- Doit être true !
    -- ...
}
```

**2. Vérifier les logs du bot** :
```bash
tail -f irc_bot.log | grep -i postgres
```

**3. Tester la connexion manuellement** :
```lua
# Dans un fichier test_db.lua
local luasql = require("luasql.postgres")
local env = luasql.postgres()
local conn = env:connect("irc_bot", "irc_user", "ton_mot_de_passe", "localhost", 5432)

if conn then
    print("✓ Connexion réussie")
    conn:close()
else
    print("✗ Connexion échouée")
end
```

**4. Activer le mode debug** : Ajoute ceci dans `irc_bot.lua` :
```lua
-- Dans init_database()
function init_database()
    print("DEBUG: Tentative de connexion PostgreSQL...")
    -- ... reste du code
    if not db_conn then
        print("DEBUG: Échec de la connexion PostgreSQL")
        return false
    end
    print("DEBUG: Connexion PostgreSQL réussie")
    return true
end
```

---

### Problème : Les menus ne sont pas chargés depuis PostgreSQL

**Solutions** :

1. **Vérifier que les menus existent en base** :
```bash
psql -U irc_user -d irc_bot -c "SELECT * FROM custom_menus;"
```

2. **Vérifier la configuration** :
```lua
database = {
    enabled = true,
    menus_table = "custom_menus",  -- Vérifie que c'est le bon nom
}
```

3. **Forcer le rechargement** : Redémarre le bot après avoir vérifié la base.

---

## 📚 Voir aussi

- [Installation](INSTALLATION.md)
- [Configuration](CONFIGURATION.md)
- [Utilisation](USAGE.md)

---

## 🆘 Besoin d'aide supplémentaire ?

Si tu rencontres un problème qui n'est pas dans cette liste :

1. **Vérifie les logs** avec les astuces ci-dessus
2. **Décris le problème** :
   - Quelle commande as-tu exécutée ?
   - Quel est le message d'erreur exact ?
   - Quel est ton système d'exploitation ?
   - Quelles sont les versions de Lua et lua-socket ?

3. **Crée un rapport de bug** sur GitHub :
   [https://github.com/claireivanenka/IRC-BOT/issues](https://github.com/claireivanenka/IRC-BOT/issues)

---

**Bon dépannage !** 🛠️
