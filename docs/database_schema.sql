-- =====================================================================
-- Schéma de la base de données PostgreSQL pour IRC-BOT
-- =====================================================================

-- Créer la table pour les menus personnalisés
CREATE TABLE IF NOT EXISTS custom_menus (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL
);

-- Index pour accélérer les recherches par nom
CREATE INDEX IF NOT EXISTS idx_custom_menus_name ON custom_menus(name);

-- Commentaires sur les colonnes
COMMENT ON TABLE custom_menus IS 'Table pour stocker les menus personnalisés du bot IRC';
COMMENT ON COLUMN custom_menus.id IS 'Identifiant unique auto-incrémenté';
COMMENT ON COLUMN custom_menus.name IS 'Nom unique du menu';
COMMENT ON COLUMN custom_menus.content IS 'Contenu textuel du menu';
COMMENT ON COLUMN custom_menus.created_at IS 'Date et heure de création';
COMMENT ON COLUMN custom_menus.created_by IS 'Créateur du menu (nick IRC)';

-- =====================================================================
-- Exemple d'insertion de données
-- =====================================================================

-- Exemple : Insérer un menu manuellement
-- INSERT INTO custom_menus (name, content, created_by)
-- VALUES ('patate', 'sauté avec des oignons', 'claire');

-- =====================================================================
-- Grant des permissions à un utilisateur
-- =====================================================================

-- Remplacez 'irc_user' et 'irc_bot' par vos valeurs
-- GRANT ALL PRIVILEGES ON TABLE custom_menus TO irc_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO irc_user;
