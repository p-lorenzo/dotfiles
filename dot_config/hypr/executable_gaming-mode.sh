#!/usr/bin/env bash

set -Eeuo pipefail

readonly WAYBAR_SIGNAL=8
readonly RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp}"
readonly INSTANCE="${HYPRLAND_INSTANCE_SIGNATURE:-no-hyprland-session}"
readonly STATE_DIR="${RUNTIME_BASE}/hypr-gaming-mode-${UID}"
readonly STATE_FILE="${STATE_DIR}/${INSTANCE}"

notify_mode() {
    local title=$1
    local body=$2

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Gaming mode" "$title" "$body" >/dev/null 2>&1 || true
    fi
}

refresh_waybar() {
    pkill "-RTMIN+${WAYBAR_SIGNAL}" -x waybar >/dev/null 2>&1 || true
}

require_hyprland() {
    if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        printf 'Gaming mode: nessuna sessione Hyprland attiva.\n' >&2
        exit 1
    fi

    if ! command -v hyprctl >/dev/null 2>&1; then
        printf 'Gaming mode: hyprctl non trovato.\n' >&2
        exit 1
    fi
}

is_enabled() {
    [[ -f $STATE_FILE ]]
}

apply_profile() {
    local output

    if ! output=$(hyprctl eval 'hl.config({
        animations = { enabled = false },
        decoration = {
            blur = { enabled = false },
            shadow = { enabled = false },
            rounding = 0,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 0,
        },
    })' 2>&1); then
        printf 'Gaming mode: applicazione del profilo fallita: %s\n' "$output" >&2
        return 1
    fi

    if [[ $output != ok ]] || ! hyprctl getoption animations:enabled | grep -qx 'bool: false'; then
        printf 'Gaming mode: Hyprland non ha applicato il profilo: %s\n' "$output" >&2
        return 1
    fi
}

enable_mode() {
    require_hyprland
    mkdir -p "$STATE_DIR"
    apply_profile
    printf 'enabled_at=%s\ninstance=%s\n' "$(date --iso-8601=seconds)" "$INSTANCE" >"${STATE_FILE}.tmp"
    mv -f "${STATE_FILE}.tmp" "$STATE_FILE"
    refresh_waybar
    notify_mode "Gaming mode attiva" "Effetti desktop ridotti. I giochi Steam si apriranno flottanti e a schermo intero."
}

disable_mode() {
    require_hyprland

    if ! is_enabled; then
        refresh_waybar
        return 0
    fi

    local output
    if ! output=$(hyprctl reload config-only 2>&1) || [[ $output != ok ]]; then
        printf 'Gaming mode: ripristino della configurazione fallito: %s\n' "$output" >&2
        return 1
    fi

    rm -f "$STATE_FILE"
    refresh_waybar
    notify_mode "Gaming mode disattivata" "Ripristinati tiling ed effetti della configurazione normale."
}

print_status() {
    if is_enabled && [[ $INSTANCE != no-hyprland-session ]]; then
        printf '%s\n' '{"text":" GAME","tooltip":"Gaming mode: attiva\nEffetti desktop ridotti; giochi Steam fuori dal tiling e fullscreen.\nClick: disattiva · Destro: libreria Steam · Centrale: Big Picture\nScorciatoia: Super+Ctrl+G","class":"on"}'
    else
        printf '%s\n' '{"text":"","tooltip":"Gaming mode: disattiva\nClick: attiva · Destro: attiva e apri Steam · Centrale: attiva e apri Big Picture\nScorciatoia: Super+Ctrl+G","class":"off"}'
    fi
}

launch_steam_uri() {
    local uri=$1
    local steam_bin

    if ! steam_bin=$(command -v steam); then
        notify_mode "Steam non trovato" "Installa Steam prima di usare questo comando."
        return 127
    fi

    if ! is_enabled; then
        enable_mode
    fi

    if command -v uwsm >/dev/null 2>&1; then
        uwsm app -S both -- "$steam_bin" "$uri" >/dev/null 2>&1 &
    else
        nohup "$steam_bin" "$uri" >/dev/null 2>&1 &
    fi
}

case "${1:-status}" in
    on | enable)
        enable_mode
        ;;
    off | disable)
        disable_mode
        ;;
    toggle)
        if is_enabled; then
            disable_mode
        else
            enable_mode
        fi
        ;;
    status)
        print_status
        ;;
    steam)
        launch_steam_uri "steam://open/games"
        ;;
    bigpicture)
        launch_steam_uri "steam://open/bigpicture"
        ;;
    *)
        printf 'Uso: %s {on|off|toggle|status|steam|bigpicture}\n' "$0" >&2
        exit 2
        ;;
esac
