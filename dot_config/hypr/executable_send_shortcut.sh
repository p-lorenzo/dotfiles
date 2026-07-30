#!/usr/bin/env bash

# Argomenti: $1 = Tasto (C, V, X, A, Z, S, T, W, Q, R, L)
KEY="$1"
TERMINAL="kitty"

# Recupera la classe della finestra attiva
CLASS=$(hyprctl activewindow -j | jq -r '.class')

# Shortcut specifici per Chrome: Cmd+T/R/L diventano Ctrl+T/R/L.
# Fuori da Chrome, Cmd+T continua ad aprire il terminale.
if [[ "$KEY" =~ ^(T|R|L)$ ]]; then
    if [[ "$CLASS" =~ ^(google-chrome|chromium|brave-browser|microsoft-edge)$ ]]; then
        hyprctl dispatch "hl.dsp.send_shortcut({ mods = 'CTRL', key = '$KEY', window = 'activewindow' })"
    elif [[ "$KEY" == "T" ]]; then
        hyprctl dispatch "hl.dsp.exec_cmd('$TERMINAL')"
    fi
    exit 0
fi

# Controlla se siamo in un terminale
if [[ "$CLASS" =~ ^(kitty|Alacritty|foot|konsole|gnome-terminal)$ ]]; then
    if [[ "$KEY" == "C" || "$KEY" == "V" ]]; then
        MODS="CTRL_SHIFT"
    else
        MODS="CTRL"
    fi
else
    # Per tutte le altre applicazioni standard
    if [[ "$KEY" == "Q" ]]; then
        MODS="ALT"
        KEY="F4"
    else
        MODS="CTRL"
    fi
fi

# Invia la scorciatoia asincrona tramite hyprctl
hyprctl dispatch "hl.dsp.send_shortcut({ mods = '$MODS', key = '$KEY', window = 'activewindow' })"
