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

# Legge i monitor attivi: nome, posizione e dimensione logica (tiene conto dello scale)
MONITORS=$(hyprctl monitors -j | jq -r '.[] | "\(.name) \(.x) \(.y) \((.width / .scale) | round) \((.height / .scale) | round) \(.width) \(.height)"')

if [ -z "$MONITORS" ]; then
    echo "Nessun monitor trovato"
    exit 1
fi

# Calcola il riquadro che contiene tutti i monitor
read -r MIN_X MIN_Y MAX_X MAX_Y < <(echo "$MONITORS" | awk '
    NR==1 { minx=$2; miny=$3; maxx=$2+$4; maxy=$3+$5 }
    { if ($2<minx) minx=$2; if ($3<miny) miny=$3;
      if ($2+$4>maxx) maxx=$2+$4; if ($3+$5>maxy) maxy=$3+$5 }
    END { print minx, miny, maxx, maxy }')
TOTAL_W=$((MAX_X - MIN_X))
TOTAL_H=$((MAX_Y - MIN_Y))

SPANNED_WP="/tmp/wp_spanned.png"

# Pulisce i file temporanei vecchi
rm -f "$SPANNED_WP" /tmp/wp_split_*.png /tmp/wp_split-*

# 1. Scala l'immagine mantenendo le proporzioni (cover fit) e ritaglia al centro per coprire tutto il desktop
magick "$WP_IMAGE" -resize "${TOTAL_W}x${TOTAL_H}^" -gravity center -extent "${TOTAL_W}x${TOTAL_H}" +repage "$SPANNED_WP"

# 2. Ritaglia la porzione di ogni monitor in base alla sua posizione
declare -A MON_WP
while read -r NAME X Y W H PW PH; do
    OUT="/tmp/wp_split_${NAME}.png"
    magick "$SPANNED_WP" -crop "${W}x${H}+$((X - MIN_X))+$((Y - MIN_Y))" +repage -resize "${PW}x${PH}!" "$OUT"
    MON_WP[$NAME]="$OUT"
done <<< "$MONITORS"

# 3. Controlla se hyprpaper è attivo, altrimenti lo avvia
if ! pgrep -x "hyprpaper" >/dev/null; then
    hyprpaper &
    sleep 0.8 # Aspetta che si avvii ed esegua l'init dell'IPC
fi

# 4. Invia i comandi a hyprpaper via IPC
for NAME in "${!MON_WP[@]}"; do
    hyprctl hyprpaper wallpaper "$NAME,${MON_WP[$NAME]}"
done
