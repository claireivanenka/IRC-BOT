# 🎮 Guide d'utilisation du Bot IRC

Apprends à utiliser toutes les fonctionnalités de ton bot IRC.

---

## 🚀 Démarrage rapide

### 1. Démarrer le bot

```bash
cd /home/claire/IRC-BOT
lua irc_bot.lua
```

Ou utilise le script de lancement :
```bash
./start_bot.sh
```

### 2. Utiliser Make

```bash
# Installer les dépendances
make install

# Démarrer le bot
make run

# Exécuter les tests
make test
```

---

## 💬 Commandes du bot

| Commande | Description | Exemple |
|----------|-------------|---------|
| `!clean <url>` | Nettoie une URL YouTube des trackers | `!clean https://youtu.be/xyz?feature=share` |
| `!urls [N]` | Liste toutes les URLs nettoyées (N=limite) | `!urls 5` |
| `!lasturls [N]` | Liste les N dernières URLs nettoyées (par défaut 5) | `!lasturls 10` |
| `!dns [N]` ou `!dnsqueries [N]` | Liste les requêtes DNS effectuées | `!dns 5` |
| `!menu` | Affiche le menu complet | `!menu` |
| `!menu boire` | Affiche les boissons | `!menu boire` |
| `!menu manger` | Affiche la nourriture | `!menu manger` |
| `!addmenu <nom> <texte>` | Crée un menu personnalisé | `!addmenu plat Soupe de légumes` |
| `!listmenus [date\|name\|creator]` | Liste tous les menus personnalisés (avec options de tri) | `!listmenus date` |
| `!showmenu <nom>` | Affiche un menu personnalisé | `!showmenu plat` |
| `!delmenu <nom>` | Supprime un menu personnalisé | `!delmenu plat` |
| `!help` | Affiche l'aide | `!help` |

---

## 🧹 Nettoyage des URLs YouTube

### Fonctionnement

Le bot supprime tous les **paramètres de tracking** des URLs YouTube :
- `feature=...`
- `utm_source=...`
- `utm_medium=...`
- `utm_campaign=...`
- `fbclid=...`
- Et tous les autres paramètres superflus

### Exemples

| Entrée | Sortie |
|--------|--------|
| `https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=twitter` | `https://www.youtube.com/watch?v=dQw4w9WgXcQ` |
| `https://youtu.be/dQw4w9WgXcQ?t=10&feature=embed` | `https://www.youtube.com/watch?v=dQw4w9WgXcQ` |
| `https://www.youtube.com/watch?v=abc123` | `https://www.youtube.com/watch?v=abc123` |
| `https://www.youtube.com/embed/xyz456?autoplay=1` | `https://www.youtube.com/watch?v=xyz456` |

### Utilisation

Dans IRC :
```irc
<Toi> !clean https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share
<Bot> Toi: https://www.youtube.com/watch?v=dQw4w9WgXcQ [IP: 142.250.186.46]
```

> ✅ Chaque URL nettoyée affiche maintenant **son adresse IP**

### Historique des URLs nettoyées

Le bot peut stocker les URLs nettoyées dans PostgreSQL (si activé). Chaque entrée inclut l'adresse IP du domaine.

**Liste toutes les URLs nettoyées :**
```irc
<Toi> !urls
<Bot> 🔍 URLs nettoyées (25 total, 10 affichées) :
       1. https://youtu.be/abc123?track=1 → https://youtu... [IP:142.250.186.46] (par claire, 2026-11-03 20:15:00)
       2. https://youtu.be/xyz789?utm=... → https://youtu... [IP:142.250.186.46] (par bob, 2026-11-03 20:16:00)
       ...
```

**Liste les N dernières URLs :**
```irc
<Toi> !urls 5
<Bot> 🔍 URLs nettoyées (25 total, 5 affichées) :
       1. https://youtu.be/def456 → https://youtu... [IP:142.250.186.46] *(par alice, 2026-11-03 20:18:00)
       ...
```

**Affiche les 5 dernières URLs (par défaut) :**
```irc
<Toi> !lasturls
<Bot> 🔍 URLs nettoyées (25 total, 5 affichées) :
       1. https://youtu.be/def456 → https://youtu... [IP:142.250.186.46] *(par alice, 2026-11-03 20:18:00)
       2. https://youtu.be/ghi789 → https://youtu... [IP:142.250.186.46] *(par bob, 2026-11-03 20:17:00)
       ...
```

---

## 🔍 Requêtes DNS

Le bot effectue automatiquement des **requêtes DNS** pour chaque URL nettoyée et stocke les résultats dans PostgreSQL.

### Fonctionnement

Pour chaque URL nettoyée via `!clean`, le bot :
1. Extrait le domaine (ex: `www.youtube.com`)
2. Effectue une résolution DNS pour obtenir l'adresse IP
3. Mesure le temps de résolution
4. Sauvegarde le tout dans la table `dns_queries`

### Commandes

| Commande | Description | Exemple |
|----------|-------------|---------|
| `!dns [N]` | Liste les N dernières requêtes DNS | `!dns 10` |
| `!dnsqueries [N]` | Alias de `!dns` | `!dnsqueries 5` |

### Exemple de sortie

```irc
<Toi> !dns
<Bot> 🔍 Requêtes DNS (25 total, 10 affichées): | www.youtube.com->142.250.186.46[5ms](success) | youtu.be->142.250.186.46[3ms](success) | ...
```

**Explications :**
- Format : `domaine->IP[temps_en_ms](statut)`
- Le statut peut être : `success`, `failed`, `timeout`
- Les requêtes sont triées par date (du plus récent au plus ancien)

### Schéma de la table

Voir [dns_queries_schema.sql](dns_queries_schema.sql) pour la structure complète de la table.

### Informations stockées

| Champ | Description | Exemple |
|-------|-------------|---------|
| `domain` | Domaine interrogé | `www.youtube.com` |
| `ip_address` | Adresse IP résolue | `142.250.186.46` |
| `hostname` | Nom d'hôte inverse (PTR) | `par21s01-in-f14.1e100.net` |
| `resolved_at` | Date de résolution | `2026-11-03 20:15:00` |
| `query_time` | Temps de résolution (ms) | `5` |
| `status` | Statut de la requête | `success` |
| `requested_by` | Nick IRC | `claire` |

---

## 🍽️ Menu interactif

### Commandes

| Commande | Description |
|----------|-------------|
| `!menu` | Affiche le menu complet (boissons + nourriture) |
| `!menu boire` ou `!menu boissons` | Affiche seulement les boissons |
| `!menu manger` ou `!menu nourriture` | Affiche seulement la nourriture |

### Exemple de sortie

```
=== Menu ===

🥤 **BOISSONS** 🥤
1. Café - €2.50
2. Thé - €2.00
3. Jus d'orange - €3.00
4. Soda - €2.75
5. Eau - €1.50
6. Bière - €4.50
7. Vin - €6.00

🍔 **NOURRITURE** 🍔
1. Croissant - €3.00
2. Sandwich - €7.50
3. Salade - €8.00
4. Pizza - €12.00
5. Burger - €10.00
6. Frites - €4.00
7. Tarte aux pommes - €5.50

Utilisation: !menu [boire|manger|tout]
```

---

## 📋 Menus personnalisés

Le bot permet de créer, gérer et afficher des **menus personnalisés** avec horodatage automatique.

### Commandes disponibles

| Commande | Description | Exemple |
|----------|-------------|---------|
| `!addmenu <nom> <texte>` | Crée un nouveau menu personnalisé | `!addmenu plat_du_jour Soupe de légumes avec pain` |
| `!listmenus [date\|name\|creator]` | Liste tous les menus personnalisés (tri possible) | `!listmenus date` |
| `!showmenu <nom>` | Affiche un menu personnalisé avec son horodatage | `!showmenu plat_du_jour` |
| `!delmenu <nom>` | Supprime un menu personnalisé | `!delmenu plat_du_jour` |

#### Options de tri pour `!listmenus`

| Option | Description | Exemple |
|--------|-------------|---------|
| `!listmenus` | Affiche dans l'ordre d'insertion | `!listmenus` |
| `!listmenus date` | **Trie par date (du plus récent au plus ancien)** | `!listmenus date` |
| `!listmenus name` | Trie par nom (ordre alphabétique A-Z) | `!listmenus name` |
| `!listmenus creator` | Trie par créateur (ordre alphabétique A-Z) | `!listmenus creator` |

**Note** : `!listmenu` est un alias de `!listmenus` et accepte les mêmes options.

### Fonctionnalités

- **Horodatage automatique** : Chaque menu est automatiquement daté lors de sa création
- **Créateur identifié** : Le bot enregistre qui a créé le menu (avec le nick IRC)
- **Sauvegarde persistante** : Les menus sont sauvegardés dans un fichier ou en base PostgreSQL (selon la configuration)
- **Recherche insensible à la casse** : `!showmenu Plat` et `!showmenu plat` donnent le même résultat

### Exemples d'utilisation

**Créer un menu** :
```irc
<Alice> !addmenu dessert Tiramisu maison
<Bot> Alice: ✅ Menu 'dessert' créé avec succès ! (2024-11-03 14:30:25)
```

**Lister les menus** :
```irc
<Alice> !listmenus
<Bot> 📋 **Menus personnalisés** (2) : 1. **plat_du_jour** *(par Alice)* - 2024-11-03 14:30:25 | 2. **dessert** *(par Alice)* - 2024-11-03 14:35:25
```

**Lister les menus triés par date (du plus récent au plus ancien)** :
```irc
<Alice> !listmenus date
<Bot> 📋 **Menus personnalisés** (2) : 1. **dessert** *(par Alice)* - 2024-11-03 14:35:25 | 2. **plat_du_jour** *(par Alice)* - 2024-11-03 14:30:25
```

**Lister les menus triés par nom** :
```irc
<Alice> !listmenus name
<Bot> 📋 **Menus personnalisés** (2) : 1. **dessert** *(par Alice)* - 2024-11-03 14:35:25 | 2. **plat_du_jour** *(par Alice)* - 2024-11-03 14:30:25
```

**Afficher un menu spécifique** :
```irc
<Alice> !showmenu dessert
<Bot> [dessert] Tiramisu maison - Créé par Alice le 2024-11-03 14:30:25
```

**Supprimer un menu** :
```irc
<Alice> !delmenu dessert
<Bot> Alice: ✅ Menu 'dessert' supprimé
```

### Sauvegarde des menus

Les menus personnalisés peuvent être sauvegardés de deux manières :

#### 1. Fichier local (par défaut)
Les menus sont automatiquement sauvegardés dans `custom_menus.lua`.

#### 2. Base de données PostgreSQL (optionnel)
Si PostgreSQL est configuré et activé, les menus sont sauvegardés en base de données.
Voir [Configuration PostgreSQL](CONFIGURATION.md#-configuration-postgresql) pour plus de détails.

---

## ⏰ Date horaire automatique

### Fonctionnement

Le bot exécute automatiquement la commande `/exec -o date` **chaque heure ronde** (00:00, 01:00, 02:00, etc.).

### Exemple

À 14:00, le bot enverra :
```
/exec -o date
```

### Personnalisation

Pour modifier cette fonctionnalité, édite le fichier `irc_bot.lua` :

```lua
-- Désactiver la date horaire
local hourly_date_enabled = false

-- Ou modifier l'intervalle
function check_hourly_task()
    local now = os.date("*t")
    -- Chaque 30 minutes
    if now.min % 30 == 0 then
        send_irc_message(config.channel, "/exec -o date")
    end
end
```

---

## 🎯 Se connecter au bot

### Méthode 1 : Utiliser un client IRC (recommandé)

#### Installer HexChat

```bash
sudo apt install hexchat
```

#### Configuration

1. **Lance HexChat**
2. **Ajoute un serveur** :
   - Serveur : `irc.libera.chat`
   - Port : `6667` (ou `6697` pour SSL)
   - Nick : Ton nom d'utilisateur
3. **Rejoins le channel** où ton bot est connecté (par défaut : `#test`)
4. **Teste les commandes** :
   ```
   !clean https://youtu.be/test
   !menu
   !help
   ```

### Méthode 2 : Utiliser Irssi (en terminal)

```bash
# Installer
sudo apt install irssi

# Lancer
irssi

# Dans Irssi :
/connect irc.libera.chat
/join #test
```

### Méthode 3 : Utiliser WeeChat

```bash
# Installer
sudo apt install weechat

# Lancer
weechat

# Dans WeeChat :
/connect irc.libera.chat
/join #test
```

### Méthode 4 : Utiliser Telnet (basique)

```bash
# Pour tester rapidement (sans client IRC)
telnet irc.libera.chat 6667
```

*⚠️ Peu pratique pour une utilisation prolongée*

---

## 🌐 Serveurs IRC recommandés

| Serveur | Port | SSL | Channel de test recommandé | Notes |
|---------|------|-----|-----------------------------|-------|
| `irc.libera.chat` | 6667 | 6697 | `#test-bot-[ton-nom]` | Recommandé pour les bots |
| `irc.oftc.net` | 6667 | 6697 | `#test` | Bon pour les tests |
| `irc.freenode.net` | 6667 | 6697 | `#test` | Historique |

### Comment choisir un channel

1. **Évite les channels protégés** comme `#test`, `#bot`, etc.
2. **Crée ton propre channel** : `#mon-bot-test`
3. **Vérifie que le bot peut rejoindre** le channel (certains nécessitent une invitation)

---

## 📊 Exemples d'utilisation

### Scénario 1 : Nettoyer une URL YouTube

```irc
<Alice> !clean https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=facebook&utm_medium=social
<Bot> Alice: https://www.youtube.com/watch?v=dQw4w9WgXcQ
```

### Scénario 2 : Voir le menu

```irc
<Bob> !menu
<Bot> === Menu ===
      🥤 **BOISSONS** 🥤
      1. Café - €2.50
      2. Thé - €2.00
      ...
      🍔 **NOURRITURE** 🍔
      1. Croissant - €3.00
      ...

<Bob> !menu boire
<Bot> === Menu ===
      🥤 **BOISSONS** 🥤
      1. Café - €2.50
      2. Thé - €2.00
      ...
```

### Scénario 3 : Aide

```irc
<Charlie> !help
<Bot> Commandes disponibles: !clean <url> - nettoyer une URL YouTube | !menu [boire|manger] - afficher le menu | !help - afficher cette aide
```

---

## 🔄 Exécuter le bot en arrière-plan

### Méthode 1 : Utiliser `nohup`

```bash
nohup lua irc_bot.lua > bot.log 2>&1 &

# Voir les logs
cat bot.log

# Arrêter le bot
pkill -f "lua irc_bot.lua"
```

### Méthode 2 : Utiliser `screen`

```bash
# Démarrer
screen -S irc_bot lua irc_bot.lua

# Se reconnecter à la session
screen -r irc_bot

# Quitter (sans arrêter le bot)
Ctrl+A puis D

# Arrêter le bot
screen -X -S irc_bot quit
```

### Méthode 3 : Utiliser `tmux`

```bash
# Démarrer
tmux new-session -d -s irc_bot 'lua irc_bot.lua'

# Se connecter
tmux attach -t irc_bot

# Quitter (sans arrêter)
Ctrl+B puis D

# Arrêter
tmux kill-session -t irc_bot
```

### Méthode 4 : Créer un service systemd

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

# Arrêter
sudo systemctl stop irc_bot
```

---

## 📝 Journalisation (logs)

Pour activer la journalisation des messages :

1. **Édite `irc_bot.lua`**
2. **Ajoute ce code au début** :

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

3. **Voir les logs** :
```bash
tail -f bot.log
```

---

## 🛠️ Personnalisation rapide

### Changer le nom du bot

Dans `irc_bot.lua` :
```lua
config.nick = "MonNouveauNom"
```

### Changer le channel

```lua
config.channel = "#mon-nouveau-channel"
```

### Ajouter une nouvelle commande

Dans la fonction `handle_message` :
```lua
if message:match("!hello") then
    send_irc_message(target, "Salut " .. nick .. "!")
end
```

---

## 📚 Voir aussi

- [Installation](INSTALLATION.md)
- [Configuration](CONFIGURATION.md)
- [Dépannage](TROUBLESHOOTING.md)
