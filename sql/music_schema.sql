-- Schema de la base de données musicale pour IRC-BOT
-- Version: 1.0.0
-- Description: Table pour stocker les pistes musicales avec leurs métadonnées

-- Table principale des pistes
CREATE TABLE IF NOT EXISTS tracks (
    id SERIAL PRIMARY KEY,
    titre VARCHAR(255) NOT NULL,
    artiste VARCHAR(255),
    album VARCHAR(255),
    annee INTEGER,
    genre VARCHAR(100),
    duree INTEGER NOT NULL,  -- Durée en secondes
    bitrate INTEGER,          -- Bitrate en kbps
    chemin_fichier TEXT,      -- Chemin local du fichier
    url_streaming VARCHAR(512), -- URL de streaming si applicable
    hash_fichier CHAR(64) UNIQUE, -- SHA-256 du fichier pour dédoublonnage
    ajoute_par VARCHAR(255) NOT NULL, -- Nick IRC de la personne qui a ajouté
    date_ajout TIMESTAMP DEFAULT NOW(),
    nb_lectures INTEGER DEFAULT 0, -- Compteur de lectures
    date_derniere_lecture TIMESTAMP
);

-- Index pour optimiser les recherches
CREATE INDEX IF NOT EXISTS idx_tracks_titre ON tracks USING gin (to_tsvector('french', titre));
CREATE INDEX IF NOT EXISTS idx_tracks_artiste ON tracks USING gin (to_tsvector('french', artiste));
CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks USING gin (to_tsvector('french', album));
CREATE INDEX IF NOT EXISTS idx_tracks_genre ON tracks (genre);
CREATE INDEX IF NOT EXISTS idx_tracks_hash ON tracks (hash_fichier);
CREATE INDEX IF NOT EXISTS idx_tracks_ajoute_par ON tracks (ajoute_par);
CREATE INDEX IF NOT EXISTS idx_tracks_nb_lectures ON tracks (nb_lectures DESC);
CREATE INDEX IF NOT EXISTS idx_tracks_date_ajout ON tracks (date_ajout DESC);

-- Commentaire sur la table
COMMENT ON TABLE tracks IS 'Table principale des pistes musicales avec métadonnées et compteur de lectures';

COMMENT ON COLUMN tracks.hash_fichier IS 'Hash SHA-256 du fichier pour éviter les doublons';
COMMENT ON COLUMN tracks.nb_lectures IS 'Nombre total de lectures/streaming de cette piste';
COMMENT ON COLUMN tracks.duree IS 'Durée de la piste en secondes';

-- Fonction pour incrémenter le compteur de lectures
CREATE OR REPLACE FUNCTION increment_play_count(track_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE tracks SET nb_lectures = nb_lectures + 1, date_derniere_lecture = NOW()
    WHERE id = track_id;
END;
$$ LANGUAGE plpgsql;

-- Vue pour obtenir les statistiques
CREATE OR REPLACE VIEW music_stats AS
SELECT 
    id,
    titre,
    artiste,
    nb_lectures,
    date_ajout,
    date_derniere_lecture
FROM tracks
ORDER BY nb_lectures DESC;
