-- =====================================================================
-- Schéma pour la table dns_queries (Requêtes DNS pour les URLs)
-- =====================================================================

-- Créer la table pour les requêtes DNS
CREATE TABLE IF NOT EXISTS dns_queries (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL,        -- Domaine interrogé (ex: www.youtube.com)
    ip_address VARCHAR(45) NOT NULL,     -- Adresse IP résolue (IPv4 ou IPv6)
    hostname VARCHAR(255),             -- Nom d'hôte inverse (PTR record)
    resolved_at TIMESTAMP NOT NULL DEFAULT NOW(),  -- Date de la résolution
    query_time INTERVAL,               -- Temps pris pour la résolution (en ms)
    status VARCHAR(20) DEFAULT 'success', -- Statut: success, failed, timeout
    requested_by VARCHAR(100) NOT NULL, -- Nick IRC qui a déclenché la requête
    UNIQUE(domain, ip_address)        -- Éviter les doublons domaine+IP
);

-- Index pour accélérer les recherches
CREATE INDEX IF NOT EXISTS idx_dns_queries_domain ON dns_queries(domain);
CREATE INDEX IF NOT EXISTS idx_dns_queries_ip ON dns_queries(ip_address);
CREATE INDEX IF NOT EXISTS idx_dns_queries_resolved_at ON dns_queries(resolved_at);
CREATE INDEX IF NOT EXISTS idx_dns_queries_requested_by ON dns_queries(requested_by);

-- Commentaires sur les colonnes
COMMENT ON TABLE dns_queries IS 'Table pour stocker les résultats des requêtes DNS effectuées par le bot';
COMMENT ON COLUMN dns_queries.id IS 'Identifiant unique auto-incrémenté';
COMMENT ON COLUMN dns_queries.domain IS 'Nom de domaine interrogé';
COMMENT ON COLUMN dns_queries.ip_address IS 'Adresse IP obtenue par résolution DNS';
COMMENT ON COLUMN dns_queries.hostname IS 'Nom d hote obtenu par resolution inverse (PTR)';
COMMENT ON COLUMN dns_queries.resolved_at IS 'Date et heure de la résolution DNS';
COMMENT ON COLUMN dns_queries.query_time IS 'Temps écoulé pour la résolution (en millisecondes)';
COMMENT ON COLUMN dns_queries.status IS 'Statut de la requête: success, failed, timeout';
COMMENT ON COLUMN dns_queries.requested_by IS 'Nick IRC de la personne qui a déclenché la requête';

-- =====================================================================
-- Exemple d'insertion
-- =====================================================================

-- INSERT INTO dns_queries (domain, ip_address, hostname, query_time, requested_by)
-- VALUES (
--     'www.youtube.com',
--     '142.250.186.46',
--     'par21s01-in-f14.1e100.net',
--     '00:00:00.050',
--     'claire'
-- );

-- =====================================================================
-- Grant des permissions
-- =====================================================================

-- GRANT ALL PRIVILEGES ON TABLE dns_queries TO irc_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO irc_user;
