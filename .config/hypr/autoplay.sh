#!/bin/bash
# SUPER+T single press: start mpv if stopped, otherwise toggle play/pause.
# SUPER+T double press (within DOUBLE_PRESS_MS): stop mpv entirely.

PLAY="$HOME/Music/"
FIRST_RUN="/tmp/autoplay_first_run"
WATCHER_PID="/tmp/autoplay_watcher_pid"
LAST_PRESS_FILE="/tmp/autoplay_last_press"
DOUBLE_PRESS_MS=400

start_watcher() {
    (
        PREV=""
        while pgrep -x mpv > /dev/null; do
            CURRENT=$(playerctl --player=mpv metadata title 2>/dev/null)
            if [ -n "$CURRENT" ] && [ "$CURRENT" != "$PREV" ]; then
                notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "Now Playing:$CURRENT"
                PREV="$CURRENT"
            fi
            sleep 2
        done
    ) &
    echo $! > "$WATCHER_PID"
}

stop_mpv() {
    killall mpv 2>/dev/null
    [ -f "$WATCHER_PID" ] && kill "$(cat "$WATCHER_PID")" 2>/dev/null && rm -f "$WATCHER_PID"
    notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "Stopped"
}

start_mpv() {
    mpv --loop-playlist --no-video --volume=60 --input-ipc-server=/tmp/mpvsocket "$PLAY" &

    # wait for mpv's MPRIS name to actually register on dbus before
    # anything downstream (this watcher, the shell's playerctl follow)
    # tries to query it — avoids the ambiguous/nondeterministic window
    # right after launch
    for i in $(seq 1 20); do
        playerctl --player=mpv status &>/dev/null && break
        sleep 0.1
    done

    if [ ! -f "$FIRST_RUN" ]; then
        touch "$FIRST_RUN"
    else
        notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "Playing"
    fi
    start_watcher
}

# ── double-press detection ──────────────────────────────────────────────
NOW_MS=$(($(date +%s%N) / 1000000))
LAST_MS=$(cat "$LAST_PRESS_FILE" 2>/dev/null || echo 0)
DIFF=$((NOW_MS - LAST_MS))
echo "$NOW_MS" > "$LAST_PRESS_FILE"

if [ "$LAST_MS" -ne 0 ] && [ "$DIFF" -lt "$DOUBLE_PRESS_MS" ]; then
    stop_mpv
    exit 0
fi

# ── single press ─────────────────────────────────────────────────────────
if pgrep -x "mpv" > /dev/null; then
    playerctl --player=mpv play-pause
    STATUS=$(playerctl --player=mpv status 2>/dev/null)
    notify-send -h string:x-dunst-stack-tag:music-now-playing "Music" "$STATUS"
else
    start_mpv
fi
