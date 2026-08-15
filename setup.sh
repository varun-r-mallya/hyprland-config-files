#!/usr/bin/env bash
# setup.sh — deploy this dotfiles repo onto a fresh Arch Linux machine.
#
# Usage:
#   git clone <this repo>
#   cd hyprquickshellsx
#   ./setup.sh
#
# What it does:
#   1. Installs everything available in Arch's official repos (pacman).
#   2. Pulls the real wallpaper/font files out of Git LFS.
#   3. Copies .config/* into ~/.config (backs up anything already there first).
#   4. Installs the bundled fonts and wallpapers.
#   5. Compiles the volume-osd helper.
#   6. Generates an initial pywal theme so the shell isn't unstyled on first login.
#
# What it does NOT do:
#   - Run the one-time logind tweaks (lid-switch/power-key behavior) — that
#     needs your sudo password interactively, run it yourself when ready:
#       bash ~/.config/hypr/tweaks.sh && touch ~/.cache/logind-tweaks.done
#   - Install AUR-only packages (see the AUR section below) — install
#     those yourself with yay/paru if you want them.
#   - Set your SDDM/login-manager session to Hyprland — do that in your
#     display manager's session picker.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }

if ! command -v pacman &>/dev/null; then
    warn "This script targets Arch Linux (pacman not found)."
    warn "See README.md section 20 for Fedora/other-distro package names."
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Official-repo packages
# ---------------------------------------------------------------------------
log "Installing packages from Arch's official repos (needs sudo)..."

PACMAN_PACKAGES=(
    hyprland quickshell hyprshot xdg-desktop-portal-hyprland xdg-desktop-portal
    hyprpolkitagent
    rofi ghostty dolphin konsole kdeconnect
    wireplumber pipewire-pulse playerctl mpv
    networkmanager bluez bluez-utils rfkill
    grim wl-clipboard cliphist
    imagemagick librsvg inkscape
    tuned at wayvnc
    jq openssl brightnessctl socat gcc
    python-pywal khal vdirsyncer
    papirus-icon-theme breeze-icons breeze-gtk
    git-lfs
)

sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

# ---------------------------------------------------------------------------
# 2. AUR-only packages — not installed automatically, just flagged
# ---------------------------------------------------------------------------
if ! pacman -Qi bibata-cursor-theme &>/dev/null; then
    warn "bibata-cursor-theme isn't in Arch's official repos (AUR-only)."
    warn "Install it yourself if you want the cursor theme this config expects:"
    warn "    yay -S bibata-cursor-theme-bin"
fi

# ---------------------------------------------------------------------------
# 3. Git LFS — the real wallpaper/font files, not pointer stubs
# ---------------------------------------------------------------------------
log "Pulling Git LFS content (wallpapers, fonts)..."
cd "$REPO_DIR"
git lfs install --local
git lfs pull

# ---------------------------------------------------------------------------
# 4. Back up and deploy .config
# ---------------------------------------------------------------------------
BACKUP_DIR="$HOME/.config-backup-pre-dotfiles-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for d in hypr quickshell rofi gtk-3.0 gtk-4.0 khal wal icons sounds fontconfig; do
    if [ -e "$HOME/.config/$d" ]; then
        cp -a "$HOME/.config/$d" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done
log "Backed up any pre-existing config to $BACKUP_DIR"

log "Deploying .config/ (existing files not tracked by this repo are left alone)..."
rsync -a "$REPO_DIR/.config/" "$HOME/.config/"
chmod +x "$HOME/.config/hypr/"*.sh 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Fonts
# ---------------------------------------------------------------------------
log "Installing bundled fonts..."
mkdir -p "$HOME/.local/share/fonts"
for zip in "$REPO_DIR"/fonts/*.zip; do
    [ -f "$zip" ] || continue
    name="$(basename "${zip%.zip}")"
    mkdir -p "$HOME/.local/share/fonts/$name"
    unzip -o -q "$zip" -d "$HOME/.local/share/fonts/$name"
done
# Anything in fonts/ that isn't a zip (already-extracted fonts) — copy as-is.
find "$REPO_DIR/fonts" -maxdepth 1 -type f ! -name '*.zip' -exec cp -n {} "$HOME/.local/share/fonts/" \;
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1

# ---------------------------------------------------------------------------
# 6. Wallpapers
# ---------------------------------------------------------------------------
log "Installing wallpapers to ~/Pictures/Wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$REPO_DIR"/wallpapers/*.* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Compile the volume OSD helper
# ---------------------------------------------------------------------------
if [ -f "$HOME/.config/hypr/volume-osd.c" ]; then
    log "Compiling volume-osd..."
    gcc -O2 -Wall -o "$HOME/.config/hypr/volume-osd" "$HOME/.config/hypr/volume-osd.c"
fi

# ---------------------------------------------------------------------------
# 8. Generate an initial pywal theme
# ---------------------------------------------------------------------------
DEFAULT_WALLPAPER="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | sort | head -1)"
if [ -n "$DEFAULT_WALLPAPER" ]; then
    log "Generating initial theme from $(basename "$DEFAULT_WALLPAPER")..."
    sed -i "s|^WALLPAPER=.*|WALLPAPER=\"$DEFAULT_WALLPAPER\"|" "$HOME/.config/hypr/shellwrapper.sh"
    wal -s -i "$DEFAULT_WALLPAPER" -q
    bash "$HOME/.config/hypr/apply-theme.sh" dark || true
    ln -sf "$HOME/.cache/wal/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
    sed -i 's/rgb(\([^)]*\))/rgb(\L\1)/g' "$HOME/.cache/wal/hyprland-colours.lua" 2>/dev/null || true
    "$HOME/.config/hypr/write-wallpaper-state.sh" "$DEFAULT_WALLPAPER" 2>/dev/null || true
else
    warn "No wallpaper found to generate an initial theme from — run wal manually later."
fi

log "Done."
cat <<'EOF'

Next steps:
  1. Select "Hyprland" as your session in your login manager (SDDM/GDM/etc.)
     and log in.
  2. Optional one-time system tweaks (lid-switch -> suspend, power-key ->
     poweroff) need your sudo password interactively, so run this yourself:
       bash ~/.config/hypr/tweaks.sh && touch ~/.cache/logind-tweaks.done
  3. If you skipped bibata-cursor-theme above, install it via an AUR helper
     or edit XCURSOR_THEME in ~/.config/hypr/hyprland.lua to a theme you have.
  4. SUPER+SHIFT+W to pick a wallpaper from ~/Pictures/Wallpapers whenever
     you want to change the theme.

See ~/.config/hypr/HYPRLAND_README.md and README.md for full details.
EOF
