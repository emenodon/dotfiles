#!/usr/bin/env bash
# Ultra Fast Cleaner v4
# Universal + Parallel + tmpfs-accelerator + distro-aware orphan removal
#
# Usage:
#   sudo cleaner.sh [--aggressive] [--dry-run] [--max-cache-size=MB] [--yes]
#
# Examples:
#   sudo cleaner.sh
#   sudo cleaner.sh --aggressive --max-cache-size=512 --yes
#   sudo cleaner.sh --dry-run

set -euo pipefail
IFS=$'\n\t'

# -------------------------
# Defaults and flags
# -------------------------
AGGRESSIVE=false
DRY_RUN=false
YES=false
MAX_CACHE_MB=1024   # default max for tmpfs accelerator
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --aggressive) AGGRESSIVE=true ;;
        --dry-run) DRY_RUN=true ;;
        --yes|--force) YES=true ;;
        --max-cache-size=*) MAX_CACHE_MB="${arg#*=}" ;;
        *) ARGS+=("$arg") ;;
    esac
done

# small helpers
log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
run() {
    if $DRY_RUN; then
        printf "DRYRUN: %s\n" "$*"
    else
        eval "$@"
    fi
}
exists() { command -v "$1" &>/dev/null; }

if [ "$EUID" -ne 0 ]; then
    err "Please run with sudo or as root."
    exit 2
fi

START_TS=$(date +%s)
CPU_THREADS=$(nproc --all || echo 1)
LOAD_OK=true

# -------------------------
# System load / priority
# Skip heavy operations if load > threads
# -------------------------
loadavg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
load_int=${loadavg%.*}
if [ -n "$load_int" ] && [ "$load_int" -ge "$CPU_THREADS" ]; then
    log "System load (${loadavg}) >= CPU threads (${CPU_THREADS}). Heavy ops will be skipped."
    LOAD_OK=false
fi

# -------------------------
# Detect disk type
# -------------------------
is_ssd() {
    for dev in /sys/block/*/queue/rotational; do
        [ -f "$dev" ] || continue
        if [ "$(cat "$dev")" -eq 0 ]; then
            return 0
        fi
    done
    return 1
}
DISK_TYPE=HDD
is_ssd && DISK_TYPE=SSD
log "Disk type detected: $DISK_TYPE"

# -------------------------
# Pre-scan targets (build list)
# -------------------------
HOME_CACHE="$HOME/.cache"
CACHE_TARGETS=(
    "$HOME/.cache/thumbnails"
    "$HOME/.cache/fontconfig"
    "$HOME/.cache/mozilla"
    "$HOME/.cache/chromium"
    "$HOME/.cache/google-chrome"
)

[ -d "$HOME_CACHE" ] || HOME_CACHE=""

if $AGGRESSIVE; then
    # only add full ~/.cache in aggressive mode
    CACHE_TARGETS+=("$HOME_CACHE")
fi

# Electron detection
mapfile -t ELECTRON_DIRS < <(find "$HOME/.config" -maxdepth 1 -type d -name "*-electron*" 2>/dev/null || true)

# Compute total size to delete (KB)
total_kb=0
for d in "${CACHE_TARGETS[@]}"; do
    [ -z "$d" ] && continue
    if [ -e "$d" ]; then
        size_kb=$(du -sk "$d" 2>/dev/null | awk '{print $1}' || echo 0)
        total_kb=$((total_kb + size_kb))
    fi
done
# add electron caches sizes
for d in "${ELECTRON_DIRS[@]}"; do
    for sub in Cache GPUCache; do
        if [ -e "$d/$sub" ]; then
            s=$(du -sk "$d/$sub" 2>/dev/null | awk '{print $1}' || echo 0)
            total_kb=$((total_kb + s))
        fi
    done
done

total_mb=$(( (total_kb + 1023) / 1024 ))
log "Pre-scan: total candidate cache size = ${total_mb} MB"

# -------------------------
# tmpfs accelerator decision
# -------------------------
USE_TMPFS=false
# available RAM in MB
avail_kB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
avail_mb=$(( (avail_kB + 1023) / 1024 ))
# safe threshold: half of available RAM
threshold_mb=$(( avail_mb / 2 ))
if [ "$threshold_mb" -lt 64 ]; then
    threshold_mb=64
fi
# allow tmpfs if size < threshold and < MAX_CACHE_MB and not dry-run
if ! $DRY_RUN && [ "$total_mb" -gt 0 ] && [ "$total_mb" -le "$threshold_mb" ] && [ "$total_mb" -le "$MAX_CACHE_MB" ]; then
    USE_TMPFS=true
fi

log "Available RAM: ${avail_mb}MB - tmpfs threshold: ${threshold_mb}MB - tmpfs usable: ${USE_TMPFS}"

# -------------------------
# deletion functions
# -------------------------
delete_parallel() {
    # args: list of paths
    # uses xargs -P with CPU_THREADS
    local paths=("$@")
    [ "${#paths[@]}" -eq 0 ] && return 0
    # filter existing
    local existing=()
    for p in "${paths[@]}"; do
        [ -e "$p" ] && existing+=("$p")
    done
    [ "${#existing[@]}" -eq 0 ] && return 0

    # create newline separated and use xargs
    printf '%s\0' "${existing[@]}" | xargs -0 -n1 -P "$CPU_THREADS" -I{} bash -c 'rm -rf "$1" 2>/dev/null' _ {}
}

# tmpfs move: move contents into /dev/shm/cleaner_tmp and then unmount to free memory.
tmpfs_cleanup() {
    local tmp_mount="/dev/shm/cleaner_tmp"
    mkdir -p "$tmp_mount"
    # move each path into tmp_mount/<basename>/
    for src in "$@"; do
        [ -e "$src" ] || continue
        base=$(basename "$src")
        dest="$tmp_mount/$base"
        if $DRY_RUN; then
            echo "DRYRUN: would move $src -> $dest"
        else
            mv -f "$src" "$dest" 2>/dev/null || ( cp -a "$src" "$dest" 2>/dev/null && rm -rf "$src" 2>/dev/null )
        fi
    done
    if $DRY_RUN; then
        echo "DRYRUN: tmpfs would be unmounted to free memory"
    else
        # sync and drop caches then remove tmp_mount content (unmount is not necessary for /dev/shm)
        sync
        rm -rf "$tmp_mount"/*
    fi
}

# -------------------------
# PACKAGE MANAGERS (safe)
# -------------------------
log "Cleaning package manager caches (if present)..."

if exists pacman; then
    log " - pacman cache"
    run "pacman -Sc --noconfirm"
    if $AGGRESSIVE; then
        if $YES; then
            orphans=$(pacman -Qdtq 2>/dev/null || true)
            if [ -n "$orphans" ]; then
                log "   pacman orphan list: (will remove)"
                run "pacman -Rns --noconfirm $orphans"
            else
                log "   no pacman orphans found"
            fi
        else
            log "   (skipped pacman orphan removal; pass --yes to allow)"
        fi
    fi
    exists yay && run "yay -Sc --clean --noconfirm"
    exists paru && run "paru -Sc --clean --noconfirm"
fi

if exists apt; then
    log " - apt cache"
    run "apt clean"
    if $AGGRESSIVE; then
        if $YES; then
            run "apt autoremove -y"
        else
            log "   (skipped apt autoremove; pass --yes to allow)"
        fi
    fi
fi

if exists dnf; then
    log " - dnf cache"
    run "dnf clean all"
    if $AGGRESSIVE && $YES; then
        run "dnf autoremove -y || true"
    fi
fi

if exists zypper; then
    log " - zypper cache"
    run "zypper clean --all"
fi

if exists xbps-remove; then
    log " - xbps cache"
    run "xbps-remove -O"
    if $AGGRESSIVE && $YES; then
        run "xbps-remove -oR"
    fi
fi

if exists apk; then
    log " - apk cache"
    run "apk cache clean"
fi

# -------------------------
# Language runtimes
# -------------------------
log "Cleaning language runtime caches..."

exists pip  && run "pip cache purge"
exists npm  && run "npm cache clean --force"
[ -d "$HOME/.cargo" ] && run "rm -rf \"$HOME/.cargo/registry\" \"$HOME/.cargo/git\""

# -------------------------
# Browser DB VACUUM (if sqlite3 present)
# -------------------------
if exists sqlite3; then
    # common sqlite DBs (places, cookies, History)
    declare -a BROWSER_DBS=(
        "$HOME/.config/google-chrome/Default/History"
        "$HOME/.config/google-chrome/Default/Cookies"
        "$HOME/.config/chromium/Default/History"
        "$HOME/.config/chromium/Default/Cookies"
        "$HOME/.mozilla/firefox"   # firefox profiles handled below
    )
    for db in "${BROWSER_DBS[@]}"; do
        if [[ "$db" == *firefox ]]; then
            # find firefox sqlite DBs inside profiles
            for ffdb in $(find "$HOME/.mozilla/firefox" -type f -name "places.sqlite" -o -name "cookies.sqlite" 2>/dev/null || true); do
                if $DRY_RUN; then
                    echo "DRYRUN: sqlite3 $ffdb 'VACUUM;'"
                else
                    sqlite3 "$ffdb" "VACUUM;" 2>/dev/null || true
                fi
            done
        else
            if [ -f "$db" ]; then
                if $DRY_RUN; then
                    echo "DRYRUN: sqlite3 $db 'VACUUM;'"
                else
                    sqlite3 "$db" "VACUUM;" 2>/dev/null || true
                fi
            fi
        fi
    done
fi

# -------------------------
# Delete caches: tmpfs accelerator when safe
# -------------------------
log "Preparing deletion list..."
DELETE_LIST=()

for p in "${CACHE_TARGETS[@]}"; do
    [ -n "$p" ] && [ -e "$p" ] && DELETE_LIST+=("$p")
done

for d in "${ELECTRON_DIRS[@]}"; do
    [ -n "$d" ] || continue
    [ -e "$d/Cache" ] && DELETE_LIST+=("$d/Cache")
    [ -e "$d/GPUCache" ] && DELETE_LIST+=("$d/GPUCache")
done

# nothing to delete?
if [ "${#DELETE_LIST[@]}" -eq 0 ]; then
    log "No cache targets found to delete."
else
    log "Targets to delete: ${#DELETE_LIST[@]} entries (total ${total_mb} MB)"

    if $USE_TMPFS && $LOAD_OK; then
        log "Using tmpfs accelerator (/dev/shm) to speed deletion..."
        if $DRY_RUN; then
            for item in "${DELETE_LIST[@]}"; do
                echo "DRYRUN: would move $item to /dev/shm/cleaner_tmp and free"
            done
        else
            tmpfs_cleanup "${DELETE_LIST[@]}"
        fi
    else
        log "Deleting directly (parallel)..."
        if $DRY_RUN; then
            for item in "${DELETE_LIST[@]}"; do
                echo "DRYRUN: would rm -rf $item"
            done
        else
            delete_parallel "${DELETE_LIST[@]}"
        fi
    fi
fi

# -------------------------
# Aggressive extra: full ~/.cache purge and history compaction
# -------------------------
if $AGGRESSIVE; then
    log "Aggressive mode extras..."
    if $YES; then
        if [ -d "$HOME/.cache" ]; then
            run "rm -rf \"$HOME/.cache\"/*"
        fi
        # shell history: write and then optionally clear older entries (no auto clear here)
        run "history -w"
    else
        log "  (skipped destructive aggressive actions; pass --yes to allow)"
    fi
fi

# -------------------------
# Systemd journal trimming (safe)
# -------------------------
if exists journalctl; then
    run "journalctl --vacuum-size=200M"
    if $AGGRESSIVE; then
        run "journalctl --vacuum-size=50M"
    fi
fi

END_TS=$(date +%s)
RUNTIME=$((END_TS - START_TS))
log "✔ Ultra Fast Cleaner v4 finished in ${RUNTIME}s"

exit 0