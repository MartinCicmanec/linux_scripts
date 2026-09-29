#!/bin/bash -e
# Clears the pacman and yay (AUR) package caches on Arch-based systems.
# Must be run as root (sudo). The yay cache of the invoking user ($SUDO_USER)
# is cleaned as well; use --user to target a different user.
#
# Default behaviour is conservative: keep the last 2 versions of every package
# and drop everything belonging to packages that are no longer installed.
# Use --all to wipe both caches completely (no downgrades possible afterwards).

KEEP=2
DRYRUN=0
ALL=0
TARGET_USER="${SUDO_USER:-root}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

  -k, --keep N    keep the last N versions of each package (default: $KEEP)
  -a, --all       remove everything from both caches (implies --keep 0)
  -n, --dry-run   only show what would be removed
  -u, --user U    user whose yay cache is cleaned (default: \$SUDO_USER)
  -h, --help      show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -k|--keep)    KEEP="$2"; shift 2 ;;
        -a|--all)     ALL=1; KEEP=0; shift ;;
        -n|--dry-run) DRYRUN=1; shift ;;
        -u|--user)    TARGET_USER="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
    echo "--keep expects a non-negative number, got: $KEEP" >&2
    exit 1
fi

if ! command -v paccache >/dev/null; then
    echo "paccache not found - install it with: pacman -S pacman-contrib" >&2
    exit 1
fi

PACMAN_CACHE=$(pacman-conf CacheDir | head -n1)
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    echo "Cannot resolve home directory of user: $TARGET_USER" >&2
    exit 1
fi
YAY_CACHE="$USER_HOME/.cache/yay"

size_of() {
    [ -d "$1" ] && du -sh "$1" 2>/dev/null | awk '{ print $1 }' || echo "-"
}

echo "pacman cache : $PACMAN_CACHE ($(size_of "$PACMAN_CACHE"))"
echo "yay cache    : $YAY_CACHE ($(size_of "$YAY_CACHE"))"
echo "keep versions: $KEEP"
[ "$DRYRUN" -eq 1 ] && echo "mode         : dry run (nothing is deleted)"
echo

PACCACHE_OPTS=(-r -v)
[ "$DRYRUN" -eq 1 ] && PACCACHE_OPTS=(-d -v)

echo "== pacman cache =="
if [ "$ALL" -eq 1 ] && [ "$DRYRUN" -eq 0 ]; then
    pacman -Scc --noconfirm
else
    # installed packages: keep the last $KEEP versions
    paccache "${PACCACHE_OPTS[@]}" -k "$KEEP" -c "$PACMAN_CACHE"
    # uninstalled packages: drop them all
    paccache "${PACCACHE_OPTS[@]}" -u -k 0 -c "$PACMAN_CACHE"
fi
echo

echo "== yay cache ($TARGET_USER) =="
if [ ! -d "$YAY_CACHE" ]; then
    echo "no yay cache found, skipping"
elif [ "$ALL" -eq 1 ]; then
    if [ "$DRYRUN" -eq 1 ]; then
        echo "would remove all contents of $YAY_CACHE"
    else
        # only the contents, so yay does not have to recreate the directory
        find "$YAY_CACHE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        echo "removed all contents of $YAY_CACHE"
    fi
else
    # yay stores built packages in one subdirectory per AUR package,
    # paccache does not recurse, so it is called per subdirectory
    while IFS= read -r dir; do
        paccache "${PACCACHE_OPTS[@]}" -k "$KEEP" -c "$dir"
    done < <(find "$YAY_CACHE" -mindepth 1 -maxdepth 1 -type d)
fi
echo

echo "== done =="
echo "pacman cache : $(size_of "$PACMAN_CACHE")"
echo "yay cache    : $(size_of "$YAY_CACHE")"
