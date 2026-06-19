#!/usr/bin/env bash

# Cartella degli sfondi
WP_DIR="/home/p-lorenzo/Pictures/Wallpapers"

# Gestione modalità daemon per la rotazione automatica (ogni 5 minuti)
if [ "$1" = "--daemon" ]; then
    # Uccide eventuali altre istanze daemon attive dello stesso script
    for pid in $(pgrep -f "rotate_wallpaper.sh --daemon"); do
        if [ "$pid" != "$$" ]; then
            kill "$pid" 2>/dev/null
        fi
    done
    
    while true; do
        "$0" --change # esegue la rotazione singola bypassando il controllo del daemon
        sleep 300
    done
fi

# Evita di rientrare in loop se chiamato come cambio singolo
if [ "$1" != "--change" ]; then
    # Se lo script viene eseguito normalmente, uccide la modalità daemon esistente
    # in modo che premendo SUPER+ALT+W si interrompa il timer e si cambi subito
    # (opzionale, ma utile per evitare che il timer scatti subito dopo un cambio manuale)
    # in questo caso lasciamo solo che la chiamata manuale cambi lo sfondo e il daemon continuerà dal suo sleep.
    :
fi

# Controlla se la cartella esiste e contiene file
if [ ! -d "$WP_DIR" ] || [ -z "$(ls -A "$WP_DIR")" ]; then
    echo "Nessuno sfondo trovato in $WP_DIR"
    exit 1
fi

# Seleziona uno sfondo casuale
WP_IMAGE=$(find "$WP_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | shuf -n 1)

if [ -z "$WP_IMAGE" ]; then
    echo "Impossibile trovare uno sfondo"
    exit 1
fi

# File temporanei per le due metà
LEFT_WP="/tmp/wp_split_0.png"
RIGHT_WP="/tmp/wp_split_1.png"
SPANNED_WP="/tmp/wp_spanned.png"

# Pulisce i file temporanei vecchi
rm -f "$LEFT_WP" "$RIGHT_WP" "$SPANNED_WP" /tmp/wp_split-*

# 1. Scala l'immagine mantenendo le proporzioni (cover fit) e ritaglia al centro per ottenere esattamente 3840x1080
magick "$WP_IMAGE" -resize 3840x1080^ -gravity center -extent 3840x1080 +repage "$SPANNED_WP"

# 2. Taglia lo sfondo a metà (in due immagini 1920x1080)
magick "$SPANNED_WP" -crop 1920x1080 +repage /tmp/wp_split.png

# Rinomina i file generati da ImageMagick
mv /tmp/wp_split-0.png "$LEFT_WP"
mv /tmp/wp_split-1.png "$RIGHT_WP"

# 3. Controlla se hyprpaper è attivo, altrimenti lo avvia
if ! pgrep -x "hyprpaper" >/dev/null; then
    hyprpaper &
    sleep 0.8 # Aspetta che si avvii ed esegua l'init dell'IPC
fi

# 4. Invia i comandi a hyprpaper via IPC
hyprctl hyprpaper wallpaper "DP-2,$LEFT_WP"
hyprctl hyprpaper wallpaper "DP-1,$RIGHT_WP"

