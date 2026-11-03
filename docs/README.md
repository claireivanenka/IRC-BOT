# 📚 Documentation du Bot IRC en Lua

Bienvenue dans la documentation complète du **Bot IRC en Lua** !

Ce bot permet de nettoyer les URLs YouTube, afficher un menu interactif, et exécuter des tâches planifiées sur un serveur IRC.

---

## 📖 Table des matières

| Section | Description | Public |
|---------|-------------|--------|
| [📥 Installation](INSTALLATION.md) | Guide pour installer le bot et ses dépendances | Débutants |
| [⚙️ Configuration](CONFIGURATION.md) | Comment configurer le bot selon tes besoins | Utilisateurs |
| [🎮 Utilisation](USAGE.md) | Comment utiliser le bot et ses commandes | Utilisateurs |
| [🚨 Dépannage](TROUBLESHOOTING.md) | Solutions aux problèmes courants | Tous |
| [👨‍💻 Développement](DEVELOPMENT.md) | Comment étendre et contribuer au bot | Développeurs |

---

## 🚀 Démarrage rapide

Si tu veux **démarrer immédiatement**, suis ces étapes :

### 1️⃣ Installe les dépendances
```bash
sudo apt install lua5.4 lua-socket lua-sec
```

### 2️⃣ Clone le dépôt
```bash
git clone https://github.com/claireivanenka/IRC-BOT.git
cd IRC-BOT
```

### 3️⃣ Configure le bot
Édite `irc_bot.lua` et modifie :
```lua
config = {
    server = "irc.libera.chat",
    nick = "MonBot",
    channel = "#mon-channel",
}
```

### 4️⃣ Démarre le bot
```bash
lua irc_bot.lua
```

### 5️⃣ Teste dans IRC
```irc
!clean https://youtu.be/xyz?feature=share
!menu
!help
```

---

## 🎯 Fonctionnalités principales

| Fonctionnalité | Commande | Description |
|----------------|----------|-------------|
| 🧹 Nettoyage YouTube | `!clean <url>` | Supprime les trackers des URLs YouTube |
| 🍽️ Menu interactif | `!menu [boire\|manger]` | Affiche un menu de boissons et nourriture |
| 📋 Menus personnalisés | `!addmenu`, `!delmenu`, `!listmenus` | Crée et gère des menus personnalisés avec horodatage |
| 🗄️ Sauvegarde PostgreSQL | Automatique | Sauvegarde des menus dans une base PostgreSQL |
| ⏰ Date horaire | Automatique | Exécute `/exec -o date` chaque heure ronde |
| 📚 Documentation | `!help` | Affiche l'aide |

---

## 📁 Structure de la documentation

```
docs/
├── README.md              # Ce fichier - Index de la documentation
├── INSTALLATION.md        # Guide d'installation complète
├── CONFIGURATION.md       # Configuration détaillée
├── USAGE.md               # Guide d'utilisation
├── TROUBLESHOOTING.md     # Dépannage et solutions
└── DEVELOPMENT.md         # Guide pour les développeurs
```

---

## 🔍 Comment utiliser cette documentation

### Tu es **débutant** ?
→ Commence par [Installation](INSTALLATION.md)

### Tu veux **configurer** le bot ?
→ Va sur [Configuration](CONFIGURATION.md)

### Tu veux **utiliser** le bot ?
→ Lis [Utilisation](USAGE.md)

### Tu as un **problème** ?
→ Consulte [Dépannage](TROUBLESHOOTING.md)

### Tu veux **contribuer** ou **étendre** le bot ?
→ Explore [Développement](DEVELOPMENT.md)

---

## 📌 Conseils utiles

### 1. Teste toujours localement
Avant de déployer sur un serveur, teste le bot localement :
```bash
lua test_functions.lua  # Teste les fonctions de base
```

### 2. Utilise des canaux de test
Ne teste pas dans des canaux publics. Crée ton propre canal :
```irc
/join #mon-bot-test
```

### 3. Surveille les logs
Active la journalisation pour déboguer :
```bash
tail -f bot.log
```

### 4. Contribue !
Si tu trouves un bug ou veux ajouter une fonctionnalité :
- Ouvre une **Issue** : [https://github.com/claireivanenka/IRC-BOT/issues](https://github.com/claireivanenka/IRC-BOT/issues)
- Crée une **Pull Request** : [https://github.com/claireivanenka/IRC-BOT/pulls](https://github.com/claireivanenka/IRC-BOT/pulls)

---

## 📝 Changelog

| Version | Date | Modifications |
|---------|------|---------------|
| 1.0.0 | 2024-11-02 | Version initiale avec nettoyage YouTube, menu et date horaire |

*(Voir [CHANGELOG.md](../CHANGELOG.md) pour plus de détails)*

---

## 🤝 Contribuer à la documentation

Tu peux aider à améliorer cette documentation :

1. **Corrige les erreurs** que tu trouves
2. **Ajoute des exemples** concrets
3. **Traduis** en d'autres langues
4. **Propose de nouvelles sections**

Pour contribuer :
1. Fork le dépôt
2. Crée une branche `docs-...`
3. Fais tes modifications dans le dossier `docs/`
4. Ouvre une Pull Request

---

## 📧 Contact et support

### Questions générales
- Ouvre une **Issue** sur GitHub : [Issues](https://github.com/claireivanenka/IRC-BOT/issues)

### Bugs
- Signale-les avec :
  - La version de Lua
  - La version de lua-socket
  - Le message d'erreur exact
  - Les étapes pour reproduire

### Suggestions
- Partage tes idées sur les **Issues** ou crée une **Discussion**

---

## 🎉 Remerciements

Merci à tous ceux qui contribuent au projet, signalent des bugs, ou suggèrent des améliorations !

---

**Bonne lecture et bon développement !** 🚀
