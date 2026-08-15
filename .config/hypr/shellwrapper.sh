#!/usr/bin/env bash
#shellwrapper.sh
export QT_QPA_PLATFORMTHEME=kde
source ~/.bashrc

# One-time system tweaks — guarded, runs once ever. Backgrounded and
# timeout-wrapped: this needs sudo, and autostart has no terminal for a
# password prompt to land on. Without the timeout, a hung sudo prompt here
# blocks this entire script forever — no qs -d, no wallpaper, nothing below
# this point ever runs.
if [ ! -f "$HOME/.cache/logind-tweaks.done" ]; then
    ( timeout 10 bash ~/.config/hypr/tweaks.sh </dev/null && touch "$HOME/.cache/logind-tweaks.done" ) &
fi

# Per-session unlock token for quickshell
if [ -n "$XDG_RUNTIME_DIR" ]; then
    TOKEN_FILE="$XDG_RUNTIME_DIR/lock-unlock-token"
    if openssl rand -hex 32 > "$TOKEN_FILE"; then
        chmod 600 "$TOKEN_FILE"
    fi
fi

dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# Portals — backgrounded, nothing downstream blocks on these actually
# finishing, only on them eventually existing.
/usr/lib/xdg-desktop-portal-hyprland &
( sleep 1; /usr/lib/xdg-desktop-portal & ) &
# Polkit agent is launched from hyprland.lua's own autostart block.

WALLPAPER="/home/mallya/Pictures/Wallpapers/anime-moon-landscape.jpg"

# WallpaperState.qml only needs this JSON to exist with SOME valid content
# to paint something on first frame — it doesn't need wal's color
# generation or theming to have finished first. Write it immediately,
# synchronously, cheap and fast, so qs can start painting the wallpaper
# the instant it launches instead of waiting on the color pipeline below.
~/.config/hypr/write-wallpaper-state.sh "$WALLPAPER"

# Launch the shell NOW. Everything below this line is cosmetic/secondary
# and runs concurrently instead of gating the compositor's first paint.
qs -d &

# ---- Everything past this point runs in the background, in parallel ----

(
    # Color generation + theming — genuinely slow (wal itself, two python
    # scripts, gsettings, dbus-send x6, qdbus loops in apply-theme.sh) but
    # nothing the user sees on login depends on it completing first; the
    # wallpaper image is already showing via the JSON write above.
    wal -s -i "$WALLPAPER"
    bash ~/.config/hypr/apply-theme.sh "$(cat ~/.cache/quickshell/theme_mode 2>/dev/null || echo dark)"
    ln -sf ~/.cache/wal/gtk.css ~/.config/gtk-3.0/gtk.css
    sed -i 's/rgb(\([^)]*\))/rgb(\L\1)/g' ~/.cache/wal/hyprland-colours.lua
) &

(
    killall dolphin 2>/dev/null
    dolphin &
) &

wl-paste --watch cliphist --max-items 10 store &
