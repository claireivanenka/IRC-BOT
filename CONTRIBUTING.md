# 🤝 Guide de contribution

Merci de vouloir contribuer au projet **IRC-BOT** ! 🎉

Toutes les contributions sont les bienvenues, que ce soit pour :
- ✅ Signaler des bugs
- ✅ Proposer des fonctionnalités
- ✅ Améliorer la documentation
- ✅ Écrire du code
- ✅ Traduire

---

## 📌 Code de conduite

En participant à ce projet, tu acceptes de respecter le [Code de conduite](CODE_OF_CONDUCT.md) (à créer).

**Soyez respectueux, bienveillant et constructif.**

---

## 🚀 Comment contribuer

### 1. Signaler un bug 🐛

Si tu trouves un bug, **ne l'ouvre pas directement sur GitHub** sans vérification :

#### Avant de signaler :
- ✅ Vérifie que tu utilises la dernière version
- ✅ Lis la [documentation](docs/)
- ✅ Consulte les [issues existantes](https://github.com/claireivanenka/IRC-BOT/issues)
- ✅ Teste avec les dernières dépendances

#### Pour signaler un bug :

1. **Va sur** : [https://github.com/claireivanenka/IRC-BOT/issues/new](https://github.com/claireivanenka/IRC-BOT/issues/new)

2. **Utilise le template** "Bug Report"

3. **Inclus** :
   - **Titre clair** : `[BUG] Description courte du problème`
   - **Version du bot** : `1.0.0` (ou commit hash)
   - **Système d'exploitation** : Ubuntu 22.04, Debian 11, etc.
   - **Version de Lua** : `lua -v`
   - **Version de lua-socket** : `lua -e "print(require('socket')._VERSION)"`
   - **Message d'erreur exact** (copie-colle)
   - **Étapes pour reproduire** (liste numérotée)
   - **Comportement attendu** vs **Comportement réel**

---

### 2. Proposer une fonctionnalité 💡

Tu as une idée pour améliorer le bot ?

#### Avant de proposer :
- ✅ Vérifie que la fonctionnalité n'existe pas déjà
- ✅ Consulte les [issues existantes](https://github.com/claireivanenka/IRC-BOT/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
- ✅ Réfléchis à l'implémentation

#### Pour proposer une fonctionnalité :

1. **Va sur** : [https://github.com/claireivanenka/IRC-BOT/issues/new](https://github.com/claireivanenka/IRC-BOT/issues/new)

2. **Utilise le template** "Feature Request"

3. **Inclus** :
   - **Titre clair** : `[FEATURE] Description de la fonctionnalité`
   - **Description détaillée**
   - **Cas d'utilisation** (pourquoi cette fonctionnalité est utile)
   - **Exemple d'implémentation** (si tu as une idée)

---

### 3. Contribuer au code 💻

#### Prérequis
- Git
- Lua 5.4+
- lua-socket
- Un éditeur de code

#### Étapes

1. **Fork le dépôt**
   
   Clique sur **"Fork"** en haut à droite sur :
   [https://github.com/claireivanenka/IRC-BOT](https://github.com/claireivanenka/IRC-BOT)

2. **Clone ton fork**
   ```bash
   git clone git@github.com:TON_NOM_DUTILISATEUR/IRC-BOT.git
   cd IRC-BOT
   ```

3. **Ajoute le dépôt original comme remote**
   ```bash
   git remote add upstream git@github.com:claireivanenka/IRC-BOT.git
   ```

4. **Crée une nouvelle branche**
   
   Utilise un nom descriptif :
   ```bash
   # Pour un bug
   git checkout -b fix-nom-du-bug
   
   # Pour une fonctionnalité
   git checkout -b feature-nom-de-la-fonctionnalite
   
   # Pour la documentation
   git checkout -b docs-mise-a-jour
   ```

5. **Fais tes modifications**
   
   - Code ta fonctionnalité ou corrige le bug
   - **Respecte les conventions de codage** (voir ci-dessous)
   - **Ajoute des tests** si applicable
   - **Met à jour la documentation** si nécessaire

6. **Teste tes modifications**
   ```bash
   # Exécute les tests
   lua test_functions.lua
   
   # Teste manuellement
   lua irc_bot.lua
   ```

7. **Commit tes modifications**
   
   Utilise des messages de commit clairs :
   ```bash
   git add .
   git commit -m "fix: correction du bug de nettoyage YouTube"
   git commit -m "feat: ajout de la commande !recherche"
   git commit -m "docs: mise à jour de la documentation"
   ```
   
   **Conventions pour les messages de commit** :
   - Utilise le préfixe `feat:` pour une nouvelle fonctionnalité
   - Utilise le préfixe `fix:` pour une correction de bug
   - Utilise le préfixe `docs:` pour la documentation
   - Utilise le préfixe `style:` pour les corrections de style
   - Utilise le préfixe `refactor:` pour le refactoring
   - Utilise le préfixe `test:` pour les tests
   - Utilise le préfixe `chore:` pour les tâches de maintenance

8. **Pousse vers ton fork**
   ```bash
   git push origin nom-de-ta-branche
   ```

9. **Crée une Pull Request**
   
   1. Va sur ton fork sur GitHub
   2. Clique sur **"Compare & pull request"**
   3. **Utilise le template** "Pull Request"
   4. **Décris tes modifications** :
      - Qu'as-tu changé ?
      - Pourquoi ?
      - Comment tester ?
   5. Clique sur **"Create pull request"**

10. **Attends la revue**
    
    Un mainteneur reviendra sur ta PR et te donnera des retours.
    Sois patient et réactif aux commentaires !

---

### 4. Contribuer à la documentation 📚

La documentation est tout aussi importante que le code !

#### Comment contribuer :

1. **Trouve un fichier à améliorer** dans le dossier [docs/](docs/)

2. **Fork et clone** comme pour le code

3. **Fais tes modifications** :
   - Corrige les fautes d'orthographe
   - Ajoute des exemples
   - Clarifie les explications
   - Ajoute des sections manquantes

4. **Teste les liens** :
   - Vérifie que tous les liens internes fonctionnent
   - Vérifie que les commandes sont correctes

5. **Commit et pousse** comme pour le code

---

## 🎨 Conventions de codage

### 1. Style Lua

- **Indentation** : 4 espaces (pas de tabulations)
- **Longueur des lignes** : Max 120 caractères
- **Nommage** :
  - Variables : `snake_case` (ex: `video_url`, `user_nick`)
  - Fonctions : `snake_case` (ex: `clean_youtube_url`)
  - Constantes : `UPPER_SNAKE_CASE` (ex: `MAX_RETRIES`)
  - Tables : `PascalCase` pour les modules (ex: `YouTubeCleaner`)
- **Commentaires** :
  - Utilise `--` pour les commentaires sur une ligne
  - Utilise `--[[ ... ]]` pour les commentaires multi-lignes
  - Documente les fonctions avec leur but et paramètres

### 2. Structure du code

- **Une fonction = une tâche**
- **Fonctions courtes** (max 50 lignes)
- **Évite la duplication** de code
- **Gère les erreurs** avec `pcall`

### 3. Exemple de code bien structuré

```lua
-- Nettoie une URL YouTube en supprimant les paramètres de tracking
-- @param url string : URL YouTube à nettoyer
-- @return string : URL nettoyée ou message d'erreur
function clean_youtube_url(url)
    -- Vérifie que c'est une URL YouTube valide
    if not is_youtube_url(url) then
        return "⚠️ Ce n'est pas une URL YouTube valide."
    end
    
    -- Extraire l'ID vidéo
    local video_id = extract_video_id(url)
    if not video_id then
        return url
    end
    
    -- Retourner l'URL propre
    return "https://www.youtube.com/watch?v=" .. video_id
end
```

---

## 🧪 Tests

### 1. Écrire des tests

- **Un test = une fonctionnalité**
- **Nomme clairement** tes tests
- **Teste les cas limites**
- **100% de couverture** si possible

### 2. Exécuter les tests

```bash
# Tous les tests
lua test_functions.lua

# Ou avec Make
make test
```

### 3. Exemple de test

```lua
-- Test de la fonction clean_youtube_url
function test_clean_youtube()
    -- Test avec trackers
    local url1 = clean_youtube_url("https://youtu.be/abc?feature=share")
    assert(url1 == "https://www.youtube.com/watch?v=abc", "Nettoyage youtu.be")
    
    -- Test sans trackers
    local url2 = clean_youtube_url("https://www.youtube.com/watch?v=xyz")
    assert(url2 == "https://www.youtube.com/watch?v=xyz", "URL sans trackers")
    
    -- Test URL invalide
    local url3 = clean_youtube_url("https://google.com")
    assert(url3:find("Ce n'est pas une URL YouTube"), "Détection URL invalide")
end
```

---

## 📝 Documentation

### 1. Documenter le code

- **Fonctions** : Décris ce qu'elles font, leurs paramètres et leur retour
- **Modules** : Décris leur but et leur utilisation
- **Complexe** : Explique les algorithmes complexes

### 2. Documenter les PR

Dans ta Pull Request :
- **Titre** : Clair et descriptif
- **Description** : Explique **quoi**, **pourquoi** et **comment**
- **Instructions de test** : Comment tester tes modifications
- **Screenshots** : Si applicable (pour les modifications UI)

---

## 🎯 Rôles et permissions

| Rôle | Permissions | Qui peut l'avoir |
|------|-------------|------------------|
| **Mainteneur** | Merge PR, gérer les issues, publier les releases | Contributeurs réguliers |
| **Collaborateur** | Push directement, créer des branches | Contributeurs de confiance |
| **Contributeur** | Fork, créer des PR | Tout le monde |

---

## 📅 Processus de release

### 1. Préparation
- ✅ Toutes les PR sont mergées
- ✅ Tous les tests passent
- ✅ La documentation est à jour
- ✅ Le changelog est mis à jour

### 2. Création de la release

1. **Mets à jour la version** dans `CHANGELOG.md`
2. **Crée un tag** :
   ```bash
   git tag -a v1.0.0 -m "Version 1.0.0"
   git push origin v1.0.0
   ```
3. **Crée une release sur GitHub** :
   - Va sur : [https://github.com/claireivanenka/IRC-BOT/releases/new](https://github.com/claireivanenka/IRC-BOT/releases/new)
   - Sélectionne le tag
   - Ajoute un titre et une description
   - Publie la release

---

## 🤝 Communauté

### Rejoins la discussion

- **Issues** : [https://github.com/claireivanenka/IRC-BOT/issues](https://github.com/claireivanenka/IRC-BOT/issues)
- **Discussions** : [https://github.com/claireivanenka/IRC-BOT/discussions](https://github.com/claireivanenka/IRC-BOT/discussions)

### Contributeurs actifs

Merci à tous ceux qui contribuent ! Voir :
[https://github.com/claireivanenka/IRC-BOT/graphs/contributors](https://github.com/claireivanenka/IRC-BOT/graphs/contributors)

---

## 🎁 Reconnaissances

Merci à tous ceux qui :
- ✅ Signalent des bugs
- ✅ Proposent des fonctionnalités
- ✅ Améliorent la documentation
- ✅ Partagent le projet
- ✅ Utilisent le bot

**Votre contribution est précieuse !** 💖

---

## 📚 Ressources utiles

- [Documentation Lua](https://www.lua.org/docs.html)
- [Lua-Socket](http://w3.impa.br/~diego/software/luasocket/)
- [Lua-Sec (SSL)](https://github.com/brimworks/lua-sec)
- [Semantic Versioning](https://semver.org/)
- [GitHub Guides](https://guides.github.com/)

---

**Bonne contribution !** 🚀
