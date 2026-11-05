// IRC-BOT Music Player
// Gère la lecture et l'affichage des pistes musicales

document.addEventListener('DOMContentLoaded', () => {
    // Éléments DOM
    const audioPlayer = document.getElementById('audio-player');
    const playPauseBtn = document.getElementById('play-pause-btn');
    const prevBtn = document.getElementById('prev-btn');
    const nextBtn = document.getElementById('next-btn');
    const progressBar = document.getElementById('progress-bar');
    const progress = document.getElementById('progress');
    const currentTimeDisplay = document.getElementById('current-time');
    const durationDisplay = document.getElementById('duration');
    const volumeBar = document.getElementById('volume-bar');
    const volume = document.getElementById('volume');
    const trackListContainer = document.getElementById('track-list-container');
    const searchInput = document.getElementById('search-input');
    const currentTitle = document.getElementById('current-title');
    const currentArtist = document.getElementById('current-artist');
    const currentAlbum = document.getElementById('current-album');
    const currentGenre = document.getElementById('current-genre');
    const currentYear = document.getElementById('current-year');
    const currentPlays = document.getElementById('current-plays');
    const filterBtns = document.querySelectorAll('.filter-btn');
    
    // État du player
    let tracks = [];
    let filteredTracks = [];
    let currentTrackIndex = -1;
    let currentFilter = 'all';
    let isPlaying = false;
    let isDragging = false;
    let isVolumeDragging = false;
    
    // Configuration
    const API_BASE = 'http://localhost:8081/music';
    const MUSIC_API = `${API_BASE}/api/tracks`;
    
    // Initialisation
    async function init() {
        try {
            await loadTracks();
            setupEventListeners();
            updateTrackList();
        } catch (error) {
            showError(`Erreur d'initialisation: ${error.message}`);
        }
    }
    
    // Charger les pistes depuis l'API
    async function loadTracks() {
        try {
            const response = await fetch(MUSIC_API);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            tracks = await response.json();
            filteredTracks = [...tracks];
            applyFilter();
        } catch (error) {
            showError(`Impossible de charger les pistes: ${error.message}`);
            // Créer des données de démonstration
            tracks = generateDemoTracks();
            filteredTracks = [...tracks];
        }
    }
    
    // Générer des pistes de démonstration
    function generateDemoTracks() {
        return [
            { id: 1, titre: 'Bohemian Rhapsody', artiste: 'Queen', album: 'A Night at the Opera', annee: 1975, genre: 'Rock', duree: 354, chemin_fichier: '/music/queen_bohemian.mp3', url_streaming: '/stream/1', nb_lectures: 42, hash_fichier: 'abc123', ajoute_par: 'claire', date_ajout: '2026-11-04T10:00:00Z' },
            { id: 2, titre: 'Hotel California', artiste: 'Eagles', album: 'Hotel California', annee: 1976, genre: 'Rock', duree: 391, chemin_fichier: '/music/eagles_hotel.mp3', url_streaming: '/stream/2', nb_lectures: 35, hash_fichier: 'def456', ajoute_par: 'claire', date_ajout: '2026-11-04T11:00:00Z' },
            { id: 3, titre: 'Stairway to Heaven', artiste: 'Led Zeppelin', album: 'Led Zeppelin IV', annee: 1971, genre: 'Rock', duree: 482, chemin_fichier: '/music/led_zeppelin_stairway.mp3', url_streaming: '/stream/3', nb_lectures: 28, hash_fichier: 'ghi789', ajoute_par: 'claire', date_ajout: '2026-11-04T12:00:00Z' },
            { id: 4, titre: 'Imagine', artiste: 'John Lennon', album: 'Imagine', annee: 1971, genre: 'Pop', duree: 183, chemin_fichier: '/music/lennon_imagine.mp3', url_streaming: '/stream/4', nb_lectures: 50, hash_fichier: 'jkl012', ajoute_par: 'claire', date_ajout: '2026-11-04T13:00:00Z' },
            { id: 5, titre: 'Smells Like Teen Spirit', artiste: 'Nirvana', album: 'Nevermind', annee: 1991, genre: 'Grunge', duree: 301, chemin_fichier: '/music/nirvana_teen_spirit.mp3', url_streaming: '/stream/5', nb_lectures: 45, hash_fichier: 'mno345', ajoute_par: 'claire', date_ajout: '2026-11-04T14:00:00Z' }
        ];
    }
    
    // Configurer les écouteurs d'événements
    function setupEventListeners() {
        // Boutons de contrôle
        playPauseBtn.addEventListener('click', togglePlayPause);
        prevBtn.addEventListener('click', playPrevious);
        nextBtn.addEventListener('click', playNext);
        
        // Barre de progression
        progressBar.addEventListener('click', (e) => {
            if (tracks.length === 0) return;
            const percent = e.offsetX / e.target.clientWidth;
            audioPlayer.currentTime = audioPlayer.duration * percent;
        });
        
        progressBar.addEventListener('mousedown', () => isDragging = true);
        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            const rect = progressBar.getBoundingClientRect();
            const percent = (e.clientX - rect.left) / rect.width;
            audioPlayer.currentTime = audioPlayer.duration * Math.max(0, Math.min(1, percent));
        });
        document.addEventListener('mouseup', () => isDragging = false);
        
        // Barre de volume
        volumeBar.addEventListener('click', (e) => {
            const percent = e.offsetX / e.target.clientWidth;
            audioPlayer.volume = Math.max(0, Math.min(1, percent));
            volume.style.width = `${percent * 100}%`;
        });
        
        volumeBar.addEventListener('mousedown', () => isVolumeDragging = true);
        document.addEventListener('mousemove', (e) => {
            if (!isVolumeDragging) return;
            const rect = volumeBar.getBoundingClientRect();
            const percent = (e.clientX - rect.left) / rect.width;
            audioPlayer.volume = Math.max(0, Math.min(1, percent));
            volume.style.width = `${percent * 100}%`;
        });
        document.addEventListener('mouseup', () => isVolumeDragging = false);
        
        // Événements de l'audio
        audioPlayer.addEventListener('timeupdate', updateProgress);
        audioPlayer.addEventListener('durationchange', updateDuration);
        audioPlayer.addEventListener('ended', playNext);
        audioPlayer.addEventListener('error', () => showError('Erreur de lecture audio'));
        
        // Recherche
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();
            if (searchTerm === '') {
                filteredTracks = [...tracks];
            } else {
                filteredTracks = tracks.filter(track => 
                    track.titre.toLowerCase().includes(searchTerm) ||
                    track.artiste.toLowerCase().includes(searchTerm) ||
                    track.album.toLowerCase().includes(searchTerm) ||
                    track.genre.toLowerCase().includes(searchTerm)
                );
            }
            applyFilter();
            updateTrackList();
        });
        
        // Filtres
        filterBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                filterBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentFilter = btn.dataset.filter;
                applyFilter();
                updateTrackList();
            });
        });
        
        // Événements clavier
        document.addEventListener('keydown', (e) => {
            if (e.code === 'Space') {
                e.preventDefault();
                togglePlayPause();
            } else if (e.code === 'ArrowLeft') {
                audioPlayer.currentTime = Math.max(0, audioPlayer.currentTime - 5);
            } else if (e.code === 'ArrowRight') {
                audioPlayer.currentTime = Math.min(audioPlayer.duration, audioPlayer.currentTime + 5);
            } else if (e.code === 'ArrowUp') {
                audioPlayer.volume = Math.min(1, audioPlayer.volume + 0.1);
                volume.style.width = `${audioPlayer.volume * 100}%`;
            } else if (e.code === 'ArrowDown') {
                audioPlayer.volume = Math.max(0, audioPlayer.volume - 0.1);
                volume.style.width = `${audioPlayer.volume * 100}%`;
            }
        });
    }
    
    // Appliquer le filtre actuel
    function applyFilter() {
        const now = new Date();
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        
        switch (currentFilter) {
            case 'recent':
                filteredTracks.sort((a, b) => new Date(b.date_ajout) - new Date(a.date_ajout));
                break;
            case 'popular':
                filteredTracks.sort((a, b) => b.nb_lectures - a.nb_lectures);
                break;
            default:
                filteredTracks.sort((a, b) => a.titre.localeCompare(b.titre));
        }
    }
    
    // Mettre à jour la liste des pistes
    function updateTrackList() {
        if (filteredTracks.length === 0) {
            trackListContainer.innerHTML = '<div class="loading"><p>Aucune piste trouvée</p></div>';
            return;
        }
        
        trackListContainer.innerHTML = filteredTracks.map((track, index) => `
            <div class="track-item ${currentTrackIndex === index ? 'playing' : ''}" 
                 data-index="${index}" 
                 data-id="${track.id}"
                 title="${track.titre} - ${track.artiste}">
                <span class="track-number">${index + 1}</span>
                <div class="track-details">
                    <div class="track-title">${escapeHtml(track.titre)}</div>
                    <div class="track-artist">${escapeHtml(track.artiste)} - ${escapeHtml(track.album)}</div>
                </div>
                <span class="track-duration">${formatDuration(track.duree)}</span>
                <span class="track-plays">🎧 ${track.nb_lectures}</span>
            </div>
        `).join('');
        
        // Ajouter les écouteurs aux éléments de la liste
        document.querySelectorAll('.track-item').forEach(item => {
            item.addEventListener('click', () => {
                const index = parseInt(item.dataset.index);
                playTrack(index);
            });
        });
    }
    
    // Lire une piste
    function playTrack(index) {
        if (index < 0 || index >= filteredTracks.length) return;
        
        currentTrackIndex = index;
        const track = filteredTracks[index];
        
        // Mettre à jour l'URL de l'audio
        audioPlayer.src = track.url_streaming || track.chemin_fichier;
        
        // Mettre à jour l'affichage
        currentTitle.textContent = track.titre;
        currentArtist.textContent = `Artiste: ${track.artiste}`;
        currentAlbum.textContent = `Album: ${track.album}`;
        currentGenre.textContent = `Genre: ${track.genre}`;
        currentYear.textContent = `Année: ${track.annee}`;
        currentPlays.textContent = `Lectures: ${track.nb_lectures}`;
        
        // Jouer la piste
        audioPlayer.load();
        isPlaying = true;
        playPauseBtn.textContent = '⏸';
        
        // Mettre à jour l'affichage de la liste
        updateTrackList();
        
        // Incrémenter le compteur de lectures
        incrementPlayCount(track.id);
    }
    
    // Incrémenter le compteur de lectures
    async function incrementPlayCount(trackId) {
        try {
            await fetch(`${MUSIC_API}/${trackId}/play`, { method: 'POST' });
        } catch (error) {
            console.error('Erreur lors de la mise à jour du compteur:', error);
        }
    }
    
    // Basculer entre lecture et pause
    function togglePlayPause() {
        if (filteredTracks.length === 0) return;
        
        if (currentTrackIndex === -1) {
            playTrack(0);
            return;
        }
        
        if (isPlaying) {
            audioPlayer.pause();
            playPauseBtn.textContent = '▶';
        } else {
            if (audioPlayer.src) {
                audioPlayer.play().catch(error => {
                    showError(`Erreur de lecture: ${error.message}`);
                });
            } else {
                playTrack(currentTrackIndex);
            }
            playPauseBtn.textContent = '⏸';
        }
        isPlaying = !isPlaying;
    }
    
    // Lire la piste précédente
    function playPrevious() {
        if (filteredTracks.length === 0) return;
        
        currentTrackIndex = (currentTrackIndex - 1 + filteredTracks.length) % filteredTracks.length;
        playTrack(currentTrackIndex);
    }
    
    // Lire la piste suivante
    function playNext() {
        if (filteredTracks.length === 0) return;
        
        currentTrackIndex = (currentTrackIndex + 1) % filteredTracks.length;
        playTrack(currentTrackIndex);
    }
    
    // Mettre à jour la barre de progression
    function updateProgress() {
        if (isDragging) return;
        
        const percent = (audioPlayer.currentTime / audioPlayer.duration) * 100;
        progress.style.width = `${percent}%`;
        
        currentTimeDisplay.textContent = formatTime(audioPlayer.currentTime);
    }
    
    // Mettre à jour la durée
    function updateDuration() {
        durationDisplay.textContent = formatTime(audioPlayer.duration);
    }
    
    // Formater le temps en MM:SS
    function formatTime(seconds) {
        if (isNaN(seconds)) return '0:00';
        
        const minutes = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }
    
    // Formater la durée en MM:SS
    function formatDuration(seconds) {
        if (isNaN(seconds)) return '0:00';
        
        const minutes = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }
    
    // Afficher une erreur
    function showError(message) {
        trackListContainer.innerHTML = `<div class="error">⚠️ ${message}</div>`;
    }
    
    // Échapper les caractères HTML
    function escapeHtml(text) {
        if (!text) return '';
        return text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }
    
    // Initialiser le player
    init();
});
