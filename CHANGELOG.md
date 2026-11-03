# 📜 Changelog du Bot IRC

Toutes les modifications apportées au projet sont documentées dans ce fichier.

---

## 📌 Format des versions

Nous utilisons le [Semantic Versioning](https://semver.org/) :
- **MAJOR** : Changements incompatibles
- **MINOR** : Ajouts de fonctionnalités rétrocompatibles
- **PATCH** : Corrections de bugs rétrocompatibles

---

## 🚀 [1.0.0] - 2024-11-02

### ✨ Première version stable

#### Ajouté
- **Fonctionnalité de nettoyage YouTube** : Suppression automatique des paramètres de tracking (`feature`, `utm_*`, `fbclid`, etc.)
- **Menu interactif** : Affiche une liste de boissons et nourritures avec prix
- **Tâche horaire** : Exécute `/exec -o date` chaque heure ronde (00:00, 01:00, etc.)
- **Commande d'aide** : `!help` affiche toutes les commandes disponibles

#### Commandes disponibles
| Commande | Description |
|----------|-------------|
| `!clean <url>` | Nettoie une URL YouTube |
| `!menu [boire\|manger]` | Affiche le menu (boissons, nourriture ou complet) |
| `!help` | Affiche l'aide |

#### Fichiers créés
- `irc_bot.lua` : Script principal du bot
- `config.lua` : Configuration par défaut
- `start_bot.sh` : Script de lancement
- `Makefile` : Automatisation (install, run, test)
- `test_functions.lua` : 44 tests unitaires
- `README.md` : Documentation générale

#### Dépendances
- Lua 5.4+
- lua-socket (paquet Debian : `lua-socket`)
- lua-sec (optionnel, pour SSL)

#### Serveurs IRC supportés
- Libera.Chat (recommandé)
- OFTC
- Freenode
- Undernet

---

## 🚀 [1.1.0] - 2024-11-03

### ✨ Menus personnalisés et sauvegarde PostgreSQL

#### Ajouté
- **Menus personnalisés** : Les utilisateurs peuvent créer des menus personnalisés avec `!addmenu <nom> <texte>`
- **Gestion complète des menus** : `!listmenus`, `!showmenu <nom>`, `!delmenu <nom>`
- **Horodatage automatique** : Chaque menu personnalisé est daté lors de sa création
- **Sauvegarde PostgreSQL** : Option de sauvegarde des menus dans une base PostgreSQL
- **Fallback automatique** : Si PostgreSQL n'est pas disponible, le bot utilise la sauvegarde par fichier
- **Documentation PostgreSQL** : Guide complet pour configurer et utiliser PostgreSQL

#### Commandes ajoutées
| Commande | Description |
|----------|-------------|
| `!addmenu <nom> <texte>` | Crée un nouveau menu personnalisé avec horodatage |
| `!listmenus` | Liste tous les menus personnalisés créés |
| `!showmenu <nom>` | Affiche un menu personnalisé spécifique |
| `!delmenu <nom>` | Supprime un menu personnalisé |

#### Configuration PostgreSQL
Nouvelle section dans `config.lua` :
```lua
database = {
    enabled = true,          -- Activer PostgreSQL
    host = "localhost",      -- Hôte PostgreSQL
    port = 5432,             -- Port PostgreSQL
    database = "irc_bot",    -- Nom de la base
    user = "irc_user",       -- Utilisateur
    password = "password",   -- Mot de passe
    menus_table = "custom_menus", -- Table pour les menus
}
```

#### Dépendances supplémentaires
- luasql-postgres (optionnel, pour PostgreSQL)
- PostgreSQL (optionnel, serveur de base de données)

#### Schéma de la base de données
Voir [docs/database_schema.sql](docs/database_schema.sql)

---

## 🚀 [1.2.0] - 2024-11-03

### ✨ Tri des menus personnalisés

#### Ajouté
- **Tri des menus par horodatage** : La commande `!listmenus` accepte maintenant des options de tri
- **Options de tri multiples** : Tri par date (du plus récent au plus ancien), par nom (alphabétique), ou par créateur
- **Affichage compact** : Les menus sont maintenant affichés sur une seule ligne avec séparateurs "|"

#### Commandes améliorées
| Commande | Description |
|----------|-------------|
| `!listmenus` | Liste les menus dans l'ordre d'insertion |
| `!listmenus date` | Liste les menus du plus récent au plus ancien |
| `!listmenus name` | Liste les menus par ordre alphabétique |
| `!listmenus creator` | Liste les menus par créateur (A-Z) |

#### Exemple d'utilisation
```irc
!listmenus date      # Affiche les menus les plus récents en premier
!listmenus name      # Affiche les menus dans l'ordre alphabétique
!listmenu creator    # Alias de !listmenus creator
```

---

## 🔄 [Non sorti]

### À venir (Roadmap)

#### Fonctionnalités prévues
- **Système de plugins** : Charger des fonctionnalités dynamiquement
- **Base de données** : Stocker les préférences des utilisateurs (SQLite)
- **Interface Web** : Contrôler le bot via une interface web
- **Support multi-canaux** : Gérer plusieurs canaux simultanément
- **Commandes personnalisées** : Permettre aux utilisateurs de créer leurs propres commandes
- **Système de permissions** : Niveaux d'accès (admin, modérateur, utilisateur)
- **Statistiques** : Suivre l'utilisation du bot
- **Modération automatique** : Détection de spam, flood, etc.
- **Support de plus de services** : Nettoyage des URLs Twitter, Vimeo, etc.

#### Améliorations prévues
- Meilleure gestion des erreurs
- Interface de configuration plus intuitive
- Documentation plus complète
- Localisation (traduction en plusieurs langues)
- Support de IPv6

---

## 📝 Comment contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les règles de contribution.

---

## 🎯 Comparaison des versions

| Version | Date | Fonctionnalités | Statut |
|---------|------|------------------|--------|
| 1.0.0 | 2024-11-02 | Nettoyage YouTube, Menu, Date horaire | ✅ Stable |
| 0.1.0 | 2024-11-01 | Version initiale (non publiée) | ❌ Déprécié |

---

## 📚 Documentation des versions

Chaque version a sa propre documentation :
- **1.0.0** : Voir [README.md](README.md) et [docs/](docs/)

---

## 🔍 Historique des commits

Pour voir l'historique complet des commits :
```bash
git log --oneline --graph --all
```

Ou sur GitHub :
[https://github.com/claireivanenka/IRC-BOT/commits/main](https://github.com/claireivanenka/IRC-BOT/commits/main)

---

## 📧 Signaler un bug

Si tu trouves un bug, ouvre une **Issue** sur GitHub :
[https://github.com/claireivanenka/IRC-BOT/issues/new](https://github.com/claireivanenka/IRC-BOT/issues/new)

Inclus :
- La version du bot
- La version de Lua
- La version de lua-socket
- Le message d'erreur exact
- Les étapes pour reproduire

---

**Fin du Changelog**
