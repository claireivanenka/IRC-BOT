-- =====================================================================
-- Schéma de la base de données pour CreamRoad
-- Table pour stocker les fichiers audio avec leurs métadonnées
-- =====================================================================

-- Table principale des fichiers CreamRoad
CREATE TABLE IF NOT EXISTS creamroad_files (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(512) NOT NULL,
    artist VARCHAR(255),
    album VARCHAR(255),
    title VARCHAR(255),
    comment TEXT,
    year INTEGER,
    track INTEGER,
    file_type VARCHAR(50) NOT NULL, -- audio, video, cover, etc.
    file_path VARCHAR(512) NOT NULL, -- Chemin relatif dans CreamRoad
    file_size BIGINT DEFAULT 0, -- Taille en octets
    hash CHAR(64), -- SHA-256 du fichier
    duration INTEGER DEFAULT 0, -- Durée en secondes (pour audio/vidéo)
    resolution VARCHAR(50), -- Résolution (pour vidéo)
    format VARCHAR(50), -- Format du fichier (mp3, flac, jpg, etc.)
    license VARCHAR(255), -- License (CC-BY-NC-SA, etc.)
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour la recherche
CREATE INDEX IF NOT EXISTS idx_creamroad_artist ON creamroad_files(artist);
CREATE INDEX IF NOT EXISTS idx_creamroad_album ON creamroad_files(album);
CREATE INDEX IF NOT EXISTS idx_creamroad_filename ON creamroad_files(filename);
CREATE INDEX IF NOT EXISTS idx_creamroad_file_type ON creamroad_files(file_type);
CREATE INDEX IF NOT EXISTS idx_creamroad_year ON creamroad_files(year);
CREATE INDEX IF NOT EXISTS idx_creamroad_hash ON creamroad_files(hash);

-- Table pour les statistiques et métadonnées
CREATE TABLE IF NOT EXISTS creamroad_stats (
    id SERIAL PRIMARY KEY,
    stat_name VARCHAR(100) NOT NULL UNIQUE,
    stat_value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table pour les catégories ou tags
CREATE TABLE IF NOT EXISTS creamroad_tags (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES creamroad_files(id) ON DELETE CASCADE,
    tag VARCHAR(100) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_creamroad_tags ON creamroad_tags(tag);

-- Table pour les playlists
CREATE TABLE IF NOT EXISTS creamroad_playlists (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS creamroad_playlist_items (
    id SERIAL PRIMARY KEY,
    playlist_id INTEGER REFERENCES creamroad_playlists(id) ON DELETE CASCADE,
    file_id INTEGER REFERENCES creamroad_files(id) ON DELETE CASCADE,
    position INTEGER DEFAULT 0,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fonction pour mettre à jour le timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Déclencher pour creamroad_files
DROP TRIGGER IF EXISTS update_creamroad_files_timestamp ON creamroad_files;
CREATE TRIGGER update_creamroad_files_timestamp
    BEFORE UPDATE ON creamroad_files
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Déclencher pour creamroad_playlists
DROP TRIGGER IF EXISTS update_creamroad_playlists_timestamp ON creamroad_playlists;
CREATE TRIGGER update_creamroad_playlists_timestamp
    BEFORE UPDATE ON creamroad_playlists
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Commentaires sur les tables
COMMENT ON TABLE creamroad_files IS 'Contient tous les fichiers du projet CreamRoad avec leurs métadonnées';
COMMENT ON TABLE creamroad_stats IS 'Statistiques globales sur la collection CreamRoad';
COMMENT ON TABLE creamroad_tags IS 'Tags associés aux fichiers pour faciliter la recherche';
COMMENT ON TABLE creamroad_playlists IS 'Playlists personnalisées';
COMMENT ON TABLE creamroad_playlist_items IS 'Éléments des playlists';

-- Données initiales pour les stats
INSERT INTO creamroad_stats (stat_name, stat_value) VALUES 
    ('total_files', '0'),
    ('total_audio', '0'),
    ('total_video', '0'),
    ('total_covers', '0'),
    ('last_updated', CURRENT_TIMESTAMP)
ON CONFLICT (stat_name) DO NOTHING;
