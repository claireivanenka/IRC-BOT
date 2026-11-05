# CreamRoad Module - Documentation

## Overview

The CreamRoad module integrates with the IRC bot to provide music file management, search, and streaming capabilities. It indexes audio files from the CreamRoad directory and provides commands to search, play, and manage music files.

## Configuration

### Database Setup

The module requires PostgreSQL. Ensure the following tables exist (they are created automatically on first run):

```sql
-- See sql/creamroad_schema.sql for the complete schema
CREATE TABLE creamroad_files (
    id SERIAL PRIMARY KEY,
    file_path VARCHAR(1024) NOT NULL UNIQUE,
    filename VARCHAR(512) NOT NULL,
    file_size BIGINT NOT NULL,
    file_type VARCHAR(50),
    -- Track metadata (ID3/FLAC/Vorbis tags)
    title VARCHAR(512),
    artist VARCHAR(512),
    album VARCHAR(512),
    genre VARCHAR(255),
    year INTEGER,
    track_number INTEGER,
    duration INTEGER, -- in seconds
    bitrate INTEGER,  -- in kbps
    -- Playback tracking
    play_count INTEGER DEFAULT 0,
    last_played TIMESTAMP,
    added_by VARCHAR(255) NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    hash VARCHAR(64) UNIQUE
);

CREATE INDEX idx_creamroad_title ON creamroad_files(title);
CREATE INDEX idx_creamroad_artist ON creamroad_files(artist);
CREATE INDEX idx_creamroad_album ON creamroad_files(album);
CREATE INDEX idx_creamroad_play_count ON creamroad_files(play_count);
CREATE INDEX idx_creamroad_added_at ON creamroad_files(added_at);
```

### Bot Configuration

Add to your `config_custom.lua`:

```lua
creamroad = {
    enabled = true,                    -- Enable/disable CreamRoad module
    root_path = "/path/to/CreamRoad",  -- Path to CreamRoad directory
    scan_depth = 3,                     -- Subdirectory scan depth
    auto_index = true,                  -- Auto-index new files
    db_table = "creamroad_files",       -- PostgreSQL table name
    nginx = {
        server_name = "localhost",
        port = 80,
        root = "/path/to/CreamRoad",
    }
}
```

### Nginx Configuration

Deploy the nginx configuration from `deploy/nginx_creamroad.conf`:

```bash
sudo cp deploy/nginx_creamroad.conf /etc/nginx/sites-available/creamroad
sudo ln -s /etc/nginx/sites-available/creamroad /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

This enables:
- Direct file access at `http://your-server/creamroad/`
- Streaming support for audio files
- CORS headers for web-based players

## Usage

### IRC Commands

#### Administration
- `!creamroad` - Display CreamRoad module status and statistics
- `!creamroad stats` - Show detailed statistics (total files, play counts, etc.)

#### Search and Discovery
- `!creamroad search <query>` - Search for files by title, artist, album, or filename
- `!creamroad search artist:<name>` - Search by artist
- `!creamroad search album:<name>` - Search by album
- `!creamroad search genre:<name>` - Search by genre
- `!creamroad search year:<year>` - Search by year

#### Playback
- `!creamroad play <query>` - Play a file matching the query
- `!creamroad play <ID>` - Play a specific file by ID
- `!creamroad random [N]` - Play N random files (default: 1)
- `!creamroad recent [N]` - Show N most recently added files (default: 5)

#### Statistics
- `!creamroad mostplayed [N]` - Show N most played files (default: 10)
- `!creamroad leastplayed [N]` - Show N least played files (default: 10)
- `!creamroad longest [N]` - Show N longest tracks (default: 10)
- `!creamroad byartist <artist> [N]` - Show N tracks by a specific artist (default: 10)

### Examples

```irc
<user> !creamroad search sabaton
<bot> 🎵 Résultats CreamRoad pour "sabaton" (3 résultats) :
       1. [ID:42] Sabaton - The Last Stand (Album: The Last Stand, 3:54) [Played: 15x]
       2. [ID:123] Sabaton - Ghost Division (Album: The Art of War, 3:50) [Played: 8x]
       3. [ID:456] Sabaton - Prussian Blue (Album: The Last Stand, 4:28) [Played: 12x]
       Utilisez !creamroad play <ID> pour jouer

<user> !creamroad play 42
<bot> 🎵 [JOUER] Sabaton - The Last Stand (3:54) [Requête #12345]
       URL: https://your-server/creamroad/sabaton/the_last_stand.mp3
       IP: 192.168.1.100

<user> !creamroad random 3
<bot> 🎵 [RANDOM] 3 fichiers aléatoires :
       1. [ID:789] Metallica - Enter Sandman (5:32)
       2. [ID:101] Iron Maiden - Fear of the Dark (7:28)
       3. [ID:202] Judas Priest - Painkiller (6:06)
       Utilisez !creamroad play <ID> pour jouer

<user> !creamroad mostplayed 5
<bot> 🏆 Top 5 CreamRoad :
       1. [ID:42] Sabaton - The Last Stand (15x)
       2. [ID:456] Sabaton - Prussian Blue (12x)
       3. [ID:888] Rammstein - Du Hast (10x)
       4. [ID:123] Sabaton - Ghost Division (8x)
       5. [ID:999] Nightwish - Ghost Love Score (8x)
```

## File Indexing

The module automatically indexes audio files on startup if `auto_index` is enabled. It scans:

- MP3 files (with ID3v1/v2 tag support)
- FLAC files (with Vorbis comment support)
- OGG files (with Vorbis comment support)
- M4A files (with iTunes metadata support)
- WAV files (basic metadata)

### Supported Metadata

- Title
- Artist
- Album
- Genre
- Year
- Track number
- Duration
- Bitrate
- Album art (URL only, not embedded)

### File Naming Conventions

For best results, use consistent file naming:
```
Artist - Title.mp3
Artist/Album/Track Number - Title.mp3
```

## Music Module Integration

The CreamRoad module works alongside the music module:

- **Music Module**: Manages a curated library with playlists and advanced features
- **CreamRoad Module**: Provides search and playback for existing CreamRoad files

Both modules can be used simultaneously.

## Web Player

A simple web player is available at `http://your-server/creamroad/player/` (if nginx is configured with the provided configuration).

### Features

- Browse all indexed files
- Search and filter
- Play files directly in the browser
- View metadata
- Track playback statistics

## API (Internal)

The module provides the following internal functions for integration:

```lua
-- Initialize the module
creamroad_manager.init(config)

-- Index a file
creamroad_manager.index_file(file_path)

-- Index all files in the directory
creamroad_manager.index_directory()

-- Search files
creamroad_manager.search(query, limit, offset)

-- Get file info
creamroad_manager.get_file_info(file_id)

-- Increment play count
creamroad_manager.increment_play_count(file_id)

-- Get statistics
creamroad_manager.get_stats()
```

## Performance Considerations

- Indexing large libraries may take several minutes on first run
- Set `scan_depth` appropriately for your directory structure
- Use `auto_index = false` and manually trigger indexing if you have a very large library

## Troubleshooting

### Common Issues

1. **Connection Failed**: Verify PostgreSQL is running and credentials are correct
2. **No Files Found**: Check `root_path` and ensure files have supported extensions
3. **Metadata Missing**: Some files may not have complete ID3 tags
4. **Nginx Errors**: Verify nginx configuration and restart nginx

### Debug Mode

Enable debug logging in `config_custom.lua`:

```lua
logging = {
    enabled = true,
    filename = "irc_bot.log",
    level = "debug",
    max_size = 10 * 1024 * 1024,
    max_files = 5
}
```

### Log Files

Check the following log files:
- `irc_bot.log` - Bot and module logs
- `/var/log/nginx/error.log` - Nginx errors
- PostgreSQL logs (typically `/var/log/postgresql/postgresql-*.log`)

## Security

- The CreamRoad directory should not be world-writable
- Nginx should run as a dedicated user
- Database credentials should use limited privileges
- Consider setting up HTTPS for nginx

## Dependencies

- Lua 5.1+
- LuaSocket
- LuaSQL-PostgreSQL
- PostgreSQL 9.5+
- Nginx (optional, for web access)

## License

This module is part of the IRC-BOT project and inherits its license (GPL-3.0).
