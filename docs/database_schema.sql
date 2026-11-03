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
-- Table pour les URLs nettoyées (avec IPs)
-- =====================================================================

CREATE TABLE IF NOT EXISTS cleaned_urls (
    id SERIAL PRIMARY KEY,
    original_url TEXT NOT NULL,
    cleaned_url TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    cleaned_by VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45)
);

CREATE INDEX IF NOT EXISTS idx_cleaned_urls_created_at ON cleaned_urls(created_at);
CREATE INDEX IF NOT EXISTS idx_cleaned_urls_cleaned_by ON cleaned_urls(cleaned_by);

COMMENT ON TABLE cleaned_urls IS 'Table pour stocker les URLs YouTube nettoyées par le bot';
COMMENT ON COLUMN cleaned_urls.id IS 'Identifiant unique auto-incrémenté';
COMMENT ON COLUMN cleaned_urls.original_url IS 'URL originale avec les trackers';
COMMENT ON COLUMN cleaned_urls.cleaned_url IS 'URL nettoyée sans les trackers';
COMMENT ON COLUMN cleaned_urls.created_at IS 'Date et heure du nettoyage';
COMMENT ON COLUMN cleaned_urls.cleaned_by IS 'Nick IRC de la personne qui a demandé le nettoyage';
COMMENT ON COLUMN cleaned_urls.ip_address IS 'Adresse IP du domaine extrait de l''URL';

-- =====================================================================
-- Table pour les requêtes DNS
-- =====================================================================

CREATE TABLE IF NOT EXISTS dns_queries (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    hostname VARCHAR(255),
    resolved_at TIMESTAMP NOT NULL DEFAULT NOW(),
    query_time INTEGER,
    status VARCHAR(20) DEFAULT 'success',
    requested_by VARCHAR(100) NOT NULL,
    UNIQUE(domain, ip_address)
);

CREATE INDEX IF NOT EXISTS idx_dns_queries_domain ON dns_queries(domain);
CREATE INDEX IF NOT EXISTS idx_dns_queries_ip ON dns_queries(ip_address);
CREATE INDEX IF NOT EXISTS idx_dns_queries_resolved_at ON dns_queries(resolved_at);
CREATE INDEX IF NOT EXISTS idx_dns_queries_requested_by ON dns_queries(requested_by);

COMMENT ON TABLE dns_queries IS 'Table pour stocker les résultats des requêtes DNS effectuées par le bot';
COMMENT ON COLUMN dns_queries.id IS 'Identifiant unique auto-incrémenté';
COMMENT ON COLUMN dns_queries.domain IS 'Nom de domaine interrogé';
COMMENT ON COLUMN dns_queries.ip_address IS 'Adresse IP obtenue par résolution DNS';
COMMENT ON COLUMN dns_queries.hostname IS 'Nom d''hôte obtenu par résolution inverse (PTR)';
COMMENT ON COLUMN dns_queries.resolved_at IS 'Date et heure de la résolution DNS';
COMMENT ON COLUMN dns_queries.query_time IS 'Temps écoulé pour la résolution (en millisecondes)';
COMMENT ON COLUMN dns_queries.status IS 'Statut de la requête: success, failed, timeout';
COMMENT ON COLUMN dns_queries.requested_by IS 'Nick IRC de la personne qui a déclenché la requête';

-- =====================================================================
-- Grant des permissions à un utilisateur
-- =====================================================================

-- Remplacez 'irc_user' et 'irc_bot' par vos valeurs
-- GRANT ALL PRIVILEGES ON TABLE custom_menus TO irc_user;
-- GRANT ALL PRIVILEGES ON TABLE cleaned_urls TO irc_user;
-- GRANT ALL PRIVILEGES ON TABLE dns_queries TO irc_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO irc_user;
