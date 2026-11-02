# IRC Bot en Lua

Un bot IRC écrit en Lua avec les fonctionnalités suivantes :

- 🧹 **Nettoyage des URLs YouTube** : Supprime tous les paramètres de tracking
- 🍽️ **Menu interactif** : Affiche un menu de boissons et nourriture
- ⏰ **Date horaire** : Exécute `/exec -o date` à chaque heure ronde

## Prérequis

### Installer les dépendances (Debian/Ubuntu)

```bash
# Lua 5.4 et lua-socket (nécessaires)
sudo apt update
sudo apt install lua5.4 lua-socket

# Optionnel : pour SSL (si vous voulez utiliser le port 6697)
sudo apt install lua-sec
```

### Vérifier l'installation

```bash
lua -v
# Doit afficher: Lua 5.4.x

lua -e "require('socket')"
# Pas d'erreur = lua-socket est installé
```

## Configuration

Éditez le fichier `irc_bot.lua` et modifiez la section de configuration :

```lua
local config = {
    server = "irc.libera.chat",     -- Serveur IRC
    port = 6667,                     -- Port (6697 pour SSL)
    nick = "YouTubeCleanBot",        -- Nom du bot
    user = "youtube_clean_bot",     -- Identifiant utilisateur
    realname = "Bot de nettoyage YouTube et Menu",
    channel = "#test",               -- Channel principal
    use_ssl = false,                 -- Activer SSL (port 6697)
}
```

### Exemple de configuration pour Libera.Chat (SSL)

```lua
local config = {
    server = "irc.libera.chat",
    port = 6697,
    nick = "MonBot",
    user = "monbot",
    realname = "Mon Bot Personnel",
    channel = "#monchannel",
    use_ssl = true,
}
```

## Utilisation

### Démarrer le bot

```bash
cd /home/claire/IRC-BOT
lua irc_bot.lua
```

### Commandes disponibles dans IRC

| Commande | Description |
|----------|-------------|
| `!clean <url>` | Nettoie une URL YouTube des trackers |
| `!menu` | Affiche le menu complet (boissons + nourriture) |
| `!menu boire` | Affiche seulement les boissons |
| `!menu manger` | Affiche seulement la nourriture |
| `!help` ou `!aide` | Affiche l'aide |

### Exemples

```irc
<utilisateur> !clean https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=twitter
<YouTubeCleanBot> utilisateur: https://www.youtube.com/watch?v=dQw4w9WgXcQ

<utilisateur> !menu boire
<YouTubeCleanBot> === Menu === 
🥤 **BOISSONS** 🥤
1. Café - €2.50
2. Thé - €2.00
3. Jus d'orange - €3.00
...

<utilisateur> !menu
<YouTubeCleanBot> === Menu === 
🥤 **BOISSONS** 🥤
1. Café - €2.50
...
🍔 **NOURRITURE** 🍔
1. Croissant - €3.00
...
```

## Fonctionnalités détaillées

### 1. Nettoyage des URLs YouTube

Le bot supprime tous les paramètres de tracking courants :
- `feature=...`
- `utm_source=...`
- `utm_medium=...`
- `utm_campaign=...`
- `fbclid=...`
- Et tout autre paramètre après le `v=`

**Exemples :**
- Entrée : `https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=twitter`
- Sortie : `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

- Entrée : `https://youtu.be/dQw4w9WgXcQ?t=10&feature=embed`
- Sortie : `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

### 2. Menu

Le menu propose une sélection de boissons et nourritures avec leurs prix.

**Boissons :**
- Café : €2.50
- Thé : €2.00
- Jus d'orange : €3.00
- Soda : €2.75
- Eau : €1.50
- Bière : €4.50
- Vin : €6.00

**Nourriture :**
- Croissant : €3.00
- Sandwich : €7.50
- Salade : €8.00
- Pizza : €12.00
- Burger : €10.00
- Frites : €4.00
- Tarte aux pommes : €5.50

### 3. Date horaire automatique

À chaque heure ronde (ex: 14:00, 15:00, etc.), le bot envoie automatiquement :
```
/exec -o date
```

## Personnalisation

### Modifier le menu

Éditez la section `menu` dans `irc_bot.lua` :

```lua
local menu = {
    boissons = {
        {"Café", 2.50},
        {"Thé", 2.00},
        -- Ajoutez vos propres items
    },
    nourriture = {
        {"Croissant", 3.00},
        -- Ajoutez vos propres items
    }
}
```

### Ajouter des commandes

Ajoutez de nouvelles conditions dans la fonction `handle_message` :

```lua
-- Exemple : commande !hello
if message:match("!hello") then
    send_irc_message(target, "Salut " .. nick .. "!")
end
```

## Exécution en arrière-plan

Pour exécuter le bot en arrière-plan (détaché du terminal) :

```bash
# Méthode 1 : avec nohup
nohup lua irc_bot.lua > bot.log 2>&1 &

# Méthode 2 : avec screen
t_screen -dmS irc_bot lua irc_bot.lua

# Pour arrêter avec screen :
screen -X -S irc_bot quit
```

## Dépannage

### "module not found: socket"

Installer lua-socket :
```bash
sudo apt install lua-socket
```

### "module not found: ssl"

Installer lua-sec :
```bash
sudo apt install lua-sec
```

### Erreur de connexion

Vérifiez :
1. Le serveur IRC est correct
2. Le port est correct (6667 pour non-SSL, 6697 pour SSL)
3. Le nom du bot n'est pas déjà utilisé
4. Votre connexion internet fonctionne

### Le bot ne répond pas

Vérifiez que :
1. Le bot a bien rejoint le channel (vérifiez dans le terminal)
2. Vous êtes dans le bon channel
3. Le bot a les droits nécessaires (certains channels nécessitent l'invitation)

## Serveurs IRC populaires

- **Libera.Chat** : `irc.libera.chat` (port 6667 ou 6697 pour SSL)
- **Freenode** : `irc.freenode.net` (port 6667 ou 6697)
- **OFTC** : `irc.oftc.net` (port 6667 ou 6697)
- **Undernet** : `irc.undernet.org` (port 6667)

## Contribuer

N'hésitez pas à :
- Rapports de bugs
- Suggestions de nouvelles fonctionnalités
- Pull requests

## Licence

Ce projet est sous licence MIT.
