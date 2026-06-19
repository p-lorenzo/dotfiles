#!/usr/bin/env bash

# Argomenti: $1 = Tasto (C, V, X, A, Z, S, T, W, Q)
KEY="$1"

# Recupera la classe della finestra attiva
CLASS=$(hyprctl activewindow -j | jq -r '.class')

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
