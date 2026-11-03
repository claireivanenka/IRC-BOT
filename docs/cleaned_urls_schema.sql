-- =====================================================================
-- Schéma pour la table cleaned_urls (URLs YouTube nettoyées)
-- =====================================================================

-- Créer la table pour les URLs nettoyées
CREATE TABLE IF NOT EXISTS cleaned_urls (
    id SERIAL PRIMARY KEY,
    original_url TEXT NOT NULL,
    cleaned_url TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    cleaned_by VARCHAR(100) NOT NULL,
    UNIQUE(original_url)  -- Éviter les doublons de la même URL
);

-- Index pour accélérer les recherches
CREATE INDEX IF NOT EXISTS idx_cleaned_urls_created_at ON cleaned_urls(created_at);
CREATE INDEX IF NOT EXISTS idx_cleaned_urls_cleaned_by ON cleaned_urls(cleaned_by);

-- Commentaires sur les colonnes
COMMENT ON TABLE cleaned_urls IS 'Table pour stocker les URLs YouTube nettoyées par le bot';
COMMENT ON COLUMN cleaned_urls.id IS 'Identifiant unique auto-incrémenté';
COMMENT ON COLUMN cleaned_urls.original_url IS 'URL YouTube originale avec paramètres de tracking';
COMMENT ON COLUMN cleaned_urls.cleaned_url IS 'URL YouTube nettoyée (sans trackers)';
COMMENT ON COLUMN cleaned_urls.created_at IS 'Date et heure du nettoyage';
COMMENT ON COLUMN cleaned_urls.cleaned_by IS 'Nick IRC de la personne qui a demandé le nettoyage';

-- =====================================================================
-- Exemple d'insertion
-- =====================================================================

-- INSERT INTO cleaned_urls (original_url, cleaned_url, cleaned_by)
-- VALUES (
--     'https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&utm_source=twitter',
--     'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
--     'claire'
-- );

-- =====================================================================
-- Grant des permissions
-- =====================================================================

-- GRANT ALL PRIVILEGES ON TABLE cleaned_urls TO irc_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO irc_user;
