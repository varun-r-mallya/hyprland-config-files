# hyprquickshellsx
Lightweight configs targeting efficiency

## Structure

```
.config/
├── quickshell/     # Quickshell/QML shell — bar, all popups, widgets, screenshot tool, notifications
├── fontconfig/     # Font rendering config
├── gtk-3.0/        # GTK3 theme (pywal-driven)
├── gtk-4.0/        # GTK4 theme
├── Kvantum/        # Kvantum theme, generated from pywal colors (generate-kvantum-theme.py)
├── hypr/           # Hyprland config (Lua, hyprland.lua), hyprlock, scripts
├── icons/          # Custom bar icons (battery, wifi, bluetooth, etc.)
├── rofi/           # Rofi launcher, powermenu, wallpaper selector
├── sounds/         # Battery alert sounds
└── wal/            # Pywal templates and colorschemes
```

## Required Tools

### WM / Display
- `hyprland` — **0.55**, Lua-based config (`hyprland.lua`), not the classic `hyprland.conf` syntax
- `hyprexpo` plugin — `/usr/lib64/hyprland/libhyprexpo.so` (built and wired up, currently disabled in config)
- `xwayland`

### Bar / Shell
- `quickshell` — launched as `qs -d`, controlled at runtime via `qs ipc call <target> <action>`. Not in Fedora's official repos — needs a COPR (e.g. `errornointernet/quickshell`) or a source build.
- Required QML modules: `Quickshell.Hyprland`, `Quickshell.Io`, `Quickshell.Wayland`, `Quickshell.Services.Notifications`, `Quickshell.Services.Pam` (needs `linux-pam` at build time — powers the lock screen's PAM auth)
- Qt6 runtime: `QtQuick`, `QtQuick.Controls`, `QtQuick.Effects`, `QtQuick.Layouts`, `QtQuick.Shapes`, `QtQml`, `QtQml.Models`, `Qt5Compat.GraphicalEffects` (blur/shadow/motion-blur effects used throughout the popups and toasts)

### Notifications
- `quickshell` — built-in notification service; toast popups (`ToastWindow.qml`) and the notification center replace the old daemon-based approach
- `notify-send` (`libnotify`) — still required as the client-side sender for apps that emit notifications

### App Launcher
- `rofi` (Wayland build)

### Audio
- `pipewire` + `wireplumber` — provides `wpctl`
- `pipewire-pulse` — provides `pactl`, `paplay`
- `playerctl` — media keys, now-playing toasts, drives Quickshell's `MusicPlayerService.qml`

### Display / Input
- `brightnessctl`
- `udevadm` — brightness monitoring (part of systemd)

### Network
- `networkmanager` — provides `nmcli`
- `bluez` — provides `bluetoothctl`, also queried directly over D-Bus (`org.bluez`)
- `rfkill` — airplane-mode / bluetooth toggle
- `dbus-monitor` — bluetooth state monitoring

### Battery
- No external tools required — battery state is read directly from `/sys/class/power_supply/BAT0/`, plain file reads with no subprocess overhead per poll cycle
- If your battery path differs, update the `BAT=` path in the relevant Quickshell battery service

### Power Management
- `tuned` + `tuned-adm`
- CPU governor — direct `/sys` writes via sudo (no extra package)
- `sysctl` — lazy mode (part of procps-ng)
- `systemctl` — shutdown/suspend/reboot
- `systemd-inhibit` — lock-before-suspend daemon, listens for the `PrepareForSleep` D-Bus signal

### Theming
- `pywal` — command: `wal`, installed via pip (not a Fedora package)
- `generate-kvantum-theme.py` — generates a Kvantum theme from pywal's `colors.json`; overwrites a single `pywal.kvconfig` in place so `QFileSystemWatcher` triggers live repaints in already-open apps without a restart

### Wallpaper
- `swaybg`
- `mpvpaper` — optional, only needed for live wallpapers
- `imagemagick` — `convert` / `magick`, used for wallpaper thumbnails + icon cache
- `librsvg2-tools` — `rsvg-convert`, SVG icon conversion (optional but recommended)

### Clipboard
- `wl-clipboard` — provides `wl-paste`, `wl-copy`
- `cliphist`

### Screenshots
- `grim` — called directly from Quickshell's `CaptureBackend.qml`, not shelled out through a wrapper script
- Selection and annotation are handled natively in Quickshell (`SelectionOverlay`, `ShapeLayer`, `BlurLayer`, `FreehandLayer`, `TextLayer` under `Canvas/`) — `slurp` is no longer required
- `kdeconnect-cli` — optional, powers the screenshot tool's "share to phone" button

### Music
- `mpv` — background music player, driven over `--input-ipc-server`

### KDE/Qt integration layer
Runs underneath Hyprland without Plasma itself installed:
- `kdeglobals`, Breeze / Breeze-Dark GTK color scheme — regenerated on theme toggle
- `qdbus`, `dbus-send` — reload Konsole profiles / signal Breeze & KWin to reparse
- `gsettings` — GTK light/dark preference
- KSyntaxHighlighting theme generation (`~/.local/share/org.kde.syntax-highlighting/themes/`)
- `kdeconnectd`, `kded`, `kglobalaccel6`, `kdeconnect-indicator` — autostarted daemons

### Scheduling
- `at` + `atd` daemon — used for scheduled shutdown/suspend/reboot
- Enable the daemon: `sudo systemctl enable --now atd`

### VNC (optional)
- `wayvnc` — toggled with `Alt+V`

### Polkit
- `polkit-mate-authentication-agent-1` — required for authentication, cannot be bypassed

### Terminal / File Manager
- `konsole` (primary, with a fallback chain: kitty → alacritty → wezterm → foot → xterm)
- `dolphin`

### Calendar Widget
- `python3-holidays` — public holiday data (region hardcoded to `IN` — change if that's not your locale)
- Calendar popup is native Quickshell QML, using `FileView` for live reads instead of an `inotifywait`-based watcher
- Plain date grid only — no event sync backend is wired up (previously used khal/vdirsyncer against Google Calendar; removed for a from-scratch setup with zero personal-account config)

### Misc
- `jq`, `openssl`, `dbus-monitor`, `dbus-update-activation-environment`, `ping`
- `inotify-tools` — provides `inotifywait`, still used for the turbo/governor/tuned toggle triggers (no longer needed for the calendar widget)
- `bash`, `python3`, `awk`, `sed`, `grep`, `find` — standard
- `python3-gobject`, `gtk4`, `libadwaita`, `socat`
- `plasma-integration`
- `kde-cli-tools`
- `qt6ct` (installed but not used — kept for reference)

---

# Sudo / Permissions
Several scripts in this config interact with system-level files — things like switching CPU governors, toggling turbo boost (for Intel CPUs), changing tuned profiles, and modifying `/etc/sysctl.conf`. These require sudo access.

## Step 1 — Add your user to the wheel group
`wheel` is the group that grants sudo access on Fedora/RHEL-based systems. On Debian/Ubuntu, the equivalent group is `sudo`.

```bash
sudo usermod -aG wheel YOUR_USERNAME
```

Log out and back in for the group change to take effect.

## Step 2 — Configure sudoers via visudo
`visudo` is the only safe way to edit the sudoers file — it validates syntax before saving, so you can't accidentally lock yourself out.

```bash
sudo visudo
```

A typical Fedora sudoers file looks like this:

```
## Sudoers allows particular users to run various commands as
## the root user, without needing the root password.
##
## This file must be edited with the 'visudo' command.

## Allow root to run any commands anywhere
root    ALL=(ALL)       ALL

## Allows people in group wheel to run all commands
%wheel  ALL=(ALL)       ALL

## Same thing without a password
# %wheel        ALL=(ALL)       NOPASSWD: ALL

## Read drop-in files from /etc/sudoers.d
#includedir /etc/sudoers.d
```

## Step 3 — Add the NOPASSWD rules for this config
At the bottom of the sudoers file, add this line (replace `YOUR_USERNAME` with your actual username):

```
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend, /usr/bin/systemctl poweroff, /usr/bin/systemctl reboot, /usr/bin/tuned-adm profile *, /usr/bin/tee, /sys/devices/system/cpu/intel_pstate/no_turbo, /usr/sbin/sysctl, /usr/bin/sed, /usr/bin/at, /usr/bin/atrm
```

This allows the Quickshell scripts to toggle turbo boost, switch CPU governors, change tuned profiles, and apply sysctl settings without prompting for a password every time.

> Always use `visudo` — never edit `/etc/sudoers` directly. A syntax error will break sudo entirely.

---

# Lazy Mode
Lazy Mode is a battery saving toggle that appears in the battery popup menu. It works by commenting/uncommenting `vm.dirty_writeback_centisecs` in `/etc/sysctl.conf`. This value controls how often the Linux kernel flushes dirty pages (pending writes) from RAM to disk. By increasing this interval, the disk wakes up less frequently — which saves power, especially on battery.

## When does it appear?
The battery popup shows either Turbo Mode or Lazy Mode — never both at the same time:

- **Turbo Mode** appears when the system supports Intel pstate Turbo Boost — detected by the presence of `/sys/devices/system/cpu/intel_pstate/no_turbo`. This is Intel-specific and won't exist on AMD systems or systems without pstate support.
- **Lazy Mode** appears when Turbo Boost control is not available — i.e. the file above doesn't exist. This makes it useful on AMD systems, older Intel systems, or any machine where Turbo control isn't exposed.

The reason they're mutually exclusive is that Intel's Turbo Boost management already handles power states — running Lazy Mode on top of it would be redundant and can break the performance flow.

## What it does under the hood

**ON** — uncomments the line in `/etc/sysctl.conf` and applies it live:
```
vm.dirty_writeback_centisecs = 750
```
The kernel flushes dirty pages every 7.5 seconds instead of the default 5 seconds. Fewer disk wakeups, slightly better battery life.

**OFF** — comments the line out and reverts the kernel to the default:
```
vm.dirty_writeback_centisecs = 500
```
Changes are applied live via `sysctl` without a reboot.

---

# Notes
- Run `chmod +x` on all `.sh` script files before use.
- A code exists as a .c file. This needs to be compiled with gcc.(Example: `gcc -O2 -Wall -o ~/.config/hypr/volume-osd volume-osd.c`) 
- `setup.sh` deploys everything to `$HOME` automatically — no hardcoded usernames left to edit.
- Wallpaper path is set in `~/.config/hypr/shellwrapper.sh`.
- Icons must be PNG only and a fixed size. Place them in `~/.config/icons/`.
- You can use any font you have installed — just update the font name in the config. The font used in this setup is included.
- This config is not Fedora-exclusive — it works on any distro with the required tools available.
- `hyprexpo` is fully set up (plugin built, `hyprpm` permission granted) but disabled in config — remove the comment markers in `hyprland.lua` if you want it active.

---

# Battery Saving (For Intel Systems)

These tweaks reduce CPU wakeups and improve battery life on Intel laptops.

## Audio codec power management

Run once to create the config:

```bash
echo 'options snd_hda_intel power_save=1' | sudo tee /etc/modprobe.d/audio_powersave.conf
```

Takes effect on next reboot. This alone can noticeably reduce idle wakeups on Intel systems.

## Dirty writeback interval

Open `/etc/sysctl.conf`:

```bash
sudo nano /etc/sysctl.conf
```

Add this line (commented out by default — managed automatically by Lazy Mode):

```
# vm.dirty_writeback_centisecs = 750
```

Apply without rebooting:

```bash
sudo sysctl -p
```

## Changes done to the battery widget

Battery state is read directly from `/sys/class/power_supply/BAT0/` using kernel sysfs instead of `upower`. Reads are plain file reads against kernel memory, so there is no subprocess overhead per poll cycle.

If your battery is not at `BAT0`, check with:

```bash
ls /sys/class/power_supply/
```

Then update the battery path in the corresponding Quickshell battery service.
