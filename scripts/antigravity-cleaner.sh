#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Antigravity Toolkit v3.0 — TUI Edition
#  Cross-platform cache cleaner, usage monitor, account switcher, network
#  fixer and browser backup for the Antigravity IDE.
#  Supports: Linux, macOS  (see .ps1 for Windows)
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Redirect stdin when executed via pipe (curl | bash) ─────────────────────
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

# Drain any buffered input so stale newlines don't trigger menu actions
read -r -t 0.1 -n 10000 _discard 2>/dev/null || true

# ─── Safe shell options (no set -e; TUI must never crash) ────────────────────
set +e

# ─── Paths ────────────────────────────────────────────────────────────────────
GEMINI_DIR="$HOME/.gemini"
ANTIGRAVITY_DIR="$GEMINI_DIR/antigravity"
BROWSER_PROFILE_DIR="$GEMINI_DIR/antigravity-browser-profile"
BACKUP_DIR="$GEMINI_DIR/backups"
PROFILES_DIR="$HOME/.antigravity-profiles"
ACTIVE_PROFILE_FILE="$PROFILES_DIR/.active"
VERSION="3.0"

# ─── CLI flags ────────────────────────────────────────────────────────────────
FLAG_QUICK=false
FLAG_DRY_RUN=false

# ═══════════════════════════════════════════════════════════════════════════════
#  Colors & Styles  (256-color safe; degrades gracefully)
# ═══════════════════════════════════════════════════════════════════════════════
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
# Foreground
CYAN='\033[38;5;81m'    # softer cyan
LCYAN='\033[38;5;123m'  # light cyan
MAGENTA='\033[38;5;205m'
PURPLE='\033[38;5;141m'
BLUE='\033[38;5;75m'
GREEN='\033[38;5;114m'
LGREEN='\033[38;5;156m'
YELLOW='\033[38;5;222m'
ORANGE='\033[38;5;209m'
RED='\033[38;5;203m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;246m'
DGRAY='\033[38;5;239m'
# Background
BG_HL='\033[48;5;236m'
BG_SEL='\033[48;5;238m'

# ─── Box characters ──────────────────────────────────────────────────────────
# Using rounded corners for a modern look
TL="╭" TR="╮" BL="╰" BR="╯" HZ="─" VT="│" LT="├" RT="┤" HD="┬" HU="┴"

# ─── Layout constants ────────────────────────────────────────────────────────
BOX_W=62

# ═══════════════════════════════════════════════════════════════════════════════
#  Low-level helpers
# ═══════════════════════════════════════════════════════════════════════════════
hide_cursor()  { printf '\033[?25l'; }
show_cursor()  { printf '\033[?25h'; }
on_exit()      { show_cursor; printf "${RST}"; }
trap on_exit EXIT INT TERM

# Read a single keystroke; trims whitespace; returns empty string on bare Enter
read_key() {
    show_cursor
    local input=""
    read -r input
    hide_cursor
    # Trim whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    printf '%s' "$input"
}

# bc wrapper with awk fallback
calc() { echo "$1" | bc 2>/dev/null || awk "BEGIN{printf \"%.1f\", $1}" 2>/dev/null || echo "?"; }

# Cross-platform stat mtime (epoch seconds)
file_mtime() {
    if [[ "$OSTYPE" == darwin* ]]; then
        stat -f %m "$1" 2>/dev/null || echo 0
    else
        stat -c %Y "$1" 2>/dev/null || echo 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Box-drawing primitives  (consistent BOX_W-wide boxes)
# ═══════════════════════════════════════════════════════════════════════════════
_pad() { printf '%*s' "$1" ''; }

box_top() {
    local w=${1:-$BOX_W} c="${2:-$DGRAY}"
    printf "  ${c}${TL}"; printf '%*s' "$((w-2))" '' | tr ' ' "$HZ"; printf "${TR}${RST}\n"
}
box_bot() {
    local w=${1:-$BOX_W} c="${2:-$DGRAY}"
    printf "  ${c}${BL}"; printf '%*s' "$((w-2))" '' | tr ' ' "$HZ"; printf "${BR}${RST}\n"
}
box_sep() {
    local w=${1:-$BOX_W} c="${2:-$DGRAY}"
    printf "  ${c}${LT}"; printf '%*s' "$((w-2))" '' | tr ' ' "$HZ"; printf "${RT}${RST}\n"
}
box_empty() {
    local w=${1:-$BOX_W} c="${2:-$DGRAY}"
    printf "  ${c}${VT}${RST}%*s${c}${VT}${RST}\n" "$((w-2))" ''
}
# Print a line inside a box. $1=text (may contain ANSI), $2=width, $3=border color
# We compute the visible length by stripping ANSI, then pad accordingly.
box_line() {
    local text="$1" w=${2:-$BOX_W} bc="${3:-$DGRAY}"
    local vis; vis=$(printf '%b' "$text" | sed $'s/\033\[[0-9;]*m//g')
    local inner=$((w - 4))
    local pad=$((inner - ${#vis}))
    (( pad < 0 )) && pad=0
    printf "  ${bc}${VT}${RST} %b%*s ${bc}${VT}${RST}\n" "$text" "$pad" ''
}
# Section header inside a box
box_title() {
    local title="$1" w=${2:-$BOX_W} bc="${3:-$DGRAY}"
    local dashes=$(( (w - 6 - ${#title}) ))
    (( dashes < 2 )) && dashes=2
    printf "  ${bc}${LT}${HZ}${RST} ${CYAN}${BOLD}%s${RST} ${bc}" "$title"
    printf '%*s' "$dashes" '' | tr ' ' "$HZ"
    printf "${RT}${RST}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Utility functions
# ═══════════════════════════════════════════════════════════════════════════════
get_size()       { [ -d "$1" ] && du -sh "$1" 2>/dev/null | cut -f1 || echo "0B"; }
get_size_bytes() { [ -d "$1" ] && du -sb "$1" 2>/dev/null | cut -f1 || echo "0"; }

fmt_size() {
    local s="$1"
    local u="${s//[0-9.]/}"
    case "$u" in
        G*) printf "${RED}${BOLD}%s${RST}" "$s" ;;
        M*) printf "${ORANGE}%s${RST}" "$s" ;;
        K*) printf "${YELLOW}%s${RST}" "$s" ;;
        *)  printf "${GREEN}%s${RST}" "$s" ;;
    esac
}

fmt_bytes() {
    local b=$1
    if   (( b >= 1073741824 )); then printf "${RED}${BOLD}%s GB${RST}"  "$(calc "$b/1073741824")"
    elif (( b >= 1048576 ));    then printf "${ORANGE}%s MB${RST}" "$(calc "$b/1048576")"
    elif (( b >= 1024 ));       then printf "${YELLOW}%s KB${RST}" "$(calc "$b/1024")"
    else                             printf "${GREEN}%d B${RST}"  "$b"
    fi
}

count_items() {
    local d="$1" type="${2:--type f}"
    [ -d "$d" ] && find "$d" $type 2>/dev/null | wc -l | tr -d ' ' || echo "0"
}

# ─── Status line helpers ─────────────────────────────────────────────────────
info_()  { printf "  ${BLUE}●${RST}  %s\n" "$1"; }
ok_()    { printf "  ${GREEN}✓${RST}  ${GREEN}%s${RST}\n" "$1"; }
warn_()  { printf "  ${YELLOW}!${RST}  ${YELLOW}%s${RST}\n" "$1"; }
err_()   { printf "  ${RED}✗${RST}  ${RED}%s${RST}\n" "$1"; }

wait_key() {
    printf "\n  ${DGRAY}Press Enter to continue…${RST} "
    show_cursor; read -r; hide_cursor
}

# ─── Clean a directory ───────────────────────────────────────────────────────
clean_dir() {
    local dir="$1" desc="$2"
    if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
        local sz; sz=$(get_size "$dir")
        if $FLAG_DRY_RUN; then
            printf "  ${YELLOW}DRY${RST}  Would clean ${WHITE}%s${RST} — " "$desc"
            fmt_size "$sz"; printf "\n"
            return 0
        fi
        printf "  ${DGRAY}…${RST}   Cleaning %s" "$desc"
        rm -rf "${dir:?}"/* 2>/dev/null
        sleep 0.15
        printf "\r  ${GREEN}✓${RST}   ${WHITE}%s${RST} ${DGRAY}—${RST} " "$desc"
        fmt_size "$sz"; printf " ${GREEN}freed${RST}\n"
    else
        printf "  ${DGRAY}–${RST}   ${DIM}%s is empty${RST}\n" "$desc"
    fi
}

# ─── Progress bar ────────────────────────────────────────────────────────────
progress_bar() {
    local cur=$1 tot=$2 w=${3:-36}
    (( tot <= 0 )) && tot=1
    local pct=$(( cur * 100 / tot ))
    local fill=$(( cur * w / tot ))
    (( fill > w )) && fill=$w
    local empty=$(( w - fill ))
    printf "${DGRAY}[${GREEN}"
    (( fill > 0 )) && printf '%*s' "$fill" '' | tr ' ' '█'
    printf "${DGRAY}"
    (( empty > 0 )) && printf '%*s' "$empty" '' | tr ' ' '░'
    printf "] ${WHITE}%3d%%${RST}" "$pct"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Header / Banner
# ═══════════════════════════════════════════════════════════════════════════════
draw_header() {
    clear
    hide_cursor
    local w=$BOX_W
    printf "\n"
    box_top "$w" "$DGRAY"
    box_empty "$w"
    box_line "${MAGENTA}${BOLD}  A N T I G R A V I T Y${RST}" "$w"
    box_line "${CYAN}${BOLD}  T O O L K I T${RST}" "$w"
    box_empty "$w"
    box_line "${DGRAY}  v${VERSION}  •  Cache Cleaner & System Toolkit${RST}" "$w"
    box_empty "$w"
    box_bot "$w" "$DGRAY"
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Cache Status
# ═══════════════════════════════════════════════════════════════════════════════
draw_cache_status() {
    local w=$BOX_W
    local entries=(
        "$ANTIGRAVITY_DIR/brain|Brain (artifacts)"
        "$ANTIGRAVITY_DIR/browser_recordings|Browser Recordings"
        "$ANTIGRAVITY_DIR/conversations|Conversations"
        "$ANTIGRAVITY_DIR/context_state|Context State"
        "$ANTIGRAVITY_DIR/code_tracker|Code Tracker"
        "$ANTIGRAVITY_DIR/implicit|Implicit Memory"
        "$BROWSER_PROFILE_DIR|Browser Profile"
    )

    box_top "$w" "$DGRAY"
    box_title "Cache Status" "$w"
    box_empty "$w"

    local total_bytes=0
    for entry in "${entries[@]}"; do
        local dir="${entry%%|*}" name="${entry##*|}"
        local sb; sb=$(get_size_bytes "$dir"); total_bytes=$((total_bytes + sb))
        local sz; sz=$(get_size "$dir")
        local sz_colored; sz_colored=$(fmt_size "$sz")
        # right-align the size
        box_line "  ${WHITE}${name}${RST}$(printf '%*s' "$((36 - ${#name}))" '')${sz_colored}" "$w"
    done

    box_sep "$w"
    local total_colored; total_colored=$(fmt_bytes "$total_bytes")
    box_line "  ${WHITE}${BOLD}TOTAL${RST}$(printf '%*s' 31 '')${total_colored}" "$w"
    box_bot "$w" "$DGRAY"
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Cache Cleaner
# ═══════════════════════════════════════════════════════════════════════════════
menu_cleaner() {
    while true; do
        draw_header
        draw_cache_status

        local w=$BOX_W
        box_top "$w" "$DGRAY"
        box_title "Clean Options" "$w"
        box_empty "$w"
        box_line "  ${CYAN}[${WHITE}1${CYAN}]${RST}  Browser Recordings" "$w"
        box_line "  ${CYAN}[${WHITE}2${CYAN}]${RST}  Conversations" "$w"
        box_line "  ${CYAN}[${WHITE}3${CYAN}]${RST}  Brain Artifacts" "$w"
        box_line "  ${CYAN}[${WHITE}4${CYAN}]${RST}  Context State" "$w"
        box_line "  ${CYAN}[${WHITE}5${CYAN}]${RST}  Code Tracker" "$w"
        box_line "  ${CYAN}[${WHITE}6${CYAN}]${RST}  Implicit Memory" "$w"
        box_line "  ${CYAN}[${WHITE}7${CYAN}]${RST}  Browser Profile" "$w"
        box_empty "$w"
        box_line "  ${BG_SEL}${CYAN}[${WHITE}${BOLD}8${CYAN}]${RST}${BG_SEL}  ${LGREEN}Clean ALL cache ${GREEN}(recommended)${RST}" "$w"
        box_line "  ${CYAN}[${RED}9${CYAN}]${RST}  ${RED}Deep clean (everything)${RST}" "$w"
        box_empty "$w"
        box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back to main menu${RST}" "$w"
        box_empty "$w"
        box_bot "$w" "$DGRAY"

        printf "\n"
        printf "  ${CYAN}›${RST} "
        local ch; ch=$(read_key)

        # Empty input = redraw
        [[ -z "$ch" ]] && continue

        printf "\n"
        case "$ch" in
            1) clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser Recordings"; wait_key ;;
            2) clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"; wait_key ;;
            3) clean_dir "$ANTIGRAVITY_DIR/brain" "Brain Artifacts"; wait_key ;;
            4) clean_dir "$ANTIGRAVITY_DIR/context_state" "Context State"; wait_key ;;
            5) clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code Tracker"; wait_key ;;
            6) clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit Memory"; wait_key ;;
            7) clean_dir "$BROWSER_PROFILE_DIR" "Browser Profile"; wait_key ;;
            8)
                clean_dir "$ANTIGRAVITY_DIR/brain" "Brain Artifacts"
                clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser Recordings"
                clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
                clean_dir "$ANTIGRAVITY_DIR/context_state" "Context State"
                clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code Tracker"
                clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit Memory"
                printf "\n"; ok_ "All cache cleaned."
                wait_key
                ;;
            9)
                printf "  ${YELLOW}${BOLD}WARNING${RST}: Deep clean removes ALL data including browser profile.\n"
                printf "  Continue? ${DGRAY}[${GREEN}y${DGRAY}/${RED}N${DGRAY}]${RST} "
                local yn; yn=$(read_key)
                if [[ "$yn" =~ ^[Yy]$ ]]; then
                    printf "\n"
                    clean_dir "$ANTIGRAVITY_DIR/brain" "Brain Artifacts"
                    clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser Recordings"
                    clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
                    clean_dir "$ANTIGRAVITY_DIR/context_state" "Context State"
                    clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code Tracker"
                    clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit Memory"
                    clean_dir "$BROWSER_PROFILE_DIR" "Browser Profile"
                    printf "\n"; ok_ "Deep clean complete."
                else
                    printf "\n"; warn_ "Cancelled."
                fi
                wait_key
                ;;
            b|B) return ;;
            *) continue ;;   # invalid → just redraw
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Usage Dashboard
# ═══════════════════════════════════════════════════════════════════════════════
menu_usage() {
    draw_header
    local w=$BOX_W

    local conv_n; conv_n=$(count_items "$ANTIGRAVITY_DIR/conversations" "-mindepth 1 -maxdepth 1 -type d")
    local brain_n; brain_n=$(count_items "$ANTIGRAVITY_DIR/brain" "-type f")
    local rec_n; rec_n=$(count_items "$ANTIGRAVITY_DIR/browser_recordings" "-mindepth 1 -maxdepth 1 -type d")
    local ctx_n; ctx_n=$(count_items "$ANTIGRAVITY_DIR/context_state" "-type f")
    local code_n; code_n=$(count_items "$ANTIGRAVITY_DIR/code_tracker" "-type f")

    local conv_b; conv_b=$(get_size_bytes "$ANTIGRAVITY_DIR/conversations")
    local brain_b; brain_b=$(get_size_bytes "$ANTIGRAVITY_DIR/brain")
    local rec_b; rec_b=$(get_size_bytes "$ANTIGRAVITY_DIR/browser_recordings")
    local ctx_b; ctx_b=$(get_size_bytes "$ANTIGRAVITY_DIR/context_state")
    local prof_b; prof_b=$(get_size_bytes "$BROWSER_PROFILE_DIR")
    local total_b=$(( conv_b + brain_b + rec_b + ctx_b + prof_b ))

    box_top "$w" "$DGRAY"
    box_title "Usage Dashboard" "$w"
    box_empty "$w"
    box_line "  ${WHITE}Conversations${RST}            ${WHITE}${BOLD}${conv_n}${RST} sessions" "$w"
    box_line "  ${WHITE}Brain Artifacts${RST}          ${WHITE}${BOLD}${brain_n}${RST} files" "$w"
    box_line "  ${WHITE}Browser Recordings${RST}       ${WHITE}${BOLD}${rec_n}${RST} sessions" "$w"
    box_line "  ${WHITE}Context Snapshots${RST}        ${WHITE}${BOLD}${ctx_n}${RST} files" "$w"
    box_line "  ${WHITE}Code Tracker${RST}             ${WHITE}${BOLD}${code_n}${RST} files" "$w"
    box_sep "$w"
    local tb; tb=$(fmt_bytes "$total_b")
    box_line "  ${WHITE}${BOLD}Total Cache${RST}              ${tb}" "$w"
    box_bot "$w" "$DGRAY"

    # ── Activity this month ──────────────────────────────────────────────
    local now; now=$(date +%s)
    local today_n=0 week_n=0 month_n=0

    if [ -d "$ANTIGRAVITY_DIR/conversations" ]; then
        for d in "$ANTIGRAVITY_DIR/conversations"/*/; do
            [ -d "$d" ] || continue
            local mt; mt=$(file_mtime "$d")
            local age=$(( now - mt ))
            (( age < 86400   )) && (( today_n++ ))
            (( age < 604800  )) && (( week_n++ ))
            (( age < 2592000 )) && (( month_n++ ))
        done
    fi

    printf "\n"
    box_top "$w" "$DGRAY"
    box_title "Activity" "$w"
    box_empty "$w"
    box_line "  ${CYAN}Today${RST}          ${WHITE}${BOLD}${today_n}${RST} sessions" "$w"
    box_line "  ${CYAN}This week${RST}      ${WHITE}${BOLD}${week_n}${RST} sessions" "$w"
    box_line "  ${CYAN}This month${RST}     ${WHITE}${BOLD}${month_n}${RST} sessions" "$w"
    box_bot "$w" "$DGRAY"

    # ── Size breakdown ───────────────────────────────────────────────────
    if (( total_b > 0 )); then
        printf "\n"
        box_top "$w" "$DGRAY"
        box_title "Size Breakdown" "$w"
        box_empty "$w"

        local items=("Conversations:$conv_b" "Brain:$brain_b" "Recordings:$rec_b" "Context:$ctx_b" "Browser Profile:$prof_b")
        for item in "${items[@]}"; do
            local name="${item%%:*}" bytes="${item##*:}"
            local pct=$(( bytes * 100 / total_b ))
            local bw=$(( bytes * 28 / total_b ))
            (( bw > 28 )) && bw=28
            local ew=$(( 28 - bw ))
            local bar=""
            (( bw > 0 )) && bar+=$(printf '%*s' "$bw" '' | tr ' ' '█')
            (( ew > 0 )) && bar+=$(printf '%*s' "$ew" '' | tr ' ' '░')
            box_line "  ${WHITE}$(printf '%-16s' "$name")${RST} ${GREEN}${bar}${RST} ${DGRAY}${pct}%%${RST}" "$w"
        done

        box_empty "$w"
        box_bot "$w" "$DGRAY"
    fi

    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Reset Timer
# ═══════════════════════════════════════════════════════════════════════════════
menu_reset() {
    draw_header
    local w=$BOX_W

    local year; year=$(date +%Y)
    local month; month=$(date +%m)
    local day_raw; day_raw=$(date +%d)
    local day=${day_raw#0}
    local month_name; month_name=$(date +%B)

    # Days in current month
    local dim
    if [[ "$OSTYPE" == darwin* ]]; then
        dim=$(date -v1d -v+1m -v-1d +%d 2>/dev/null || echo 30)
    else
        dim=$(date -d "${year}-${month}-01 +1 month -1 day" +%d 2>/dev/null || echo 30)
    fi
    dim=${dim#0}

    # Next month name
    local next_month
    if [[ "$OSTYPE" == darwin* ]]; then
        next_month=$(date -v+1m "+%B %Y" 2>/dev/null || echo "Next Month")
    else
        next_month=$(date -d "+1 month" "+%B %Y" 2>/dev/null || echo "Next Month")
    fi

    local remaining=$(( dim - day ))
    local pbar; pbar=$(progress_bar "$day" "$dim" 32)

    box_top "$w" "$DGRAY"
    box_title "Usage Reset Timer" "$w"
    box_empty "$w"
    box_line "  ${WHITE}Current Cycle${RST}       ${WHITE}${BOLD}${month_name} ${year}${RST}" "$w"
    box_line "  ${WHITE}Reset Date${RST}          ${WHITE}${BOLD}${next_month} 1${RST}" "$w"
    box_line "  ${WHITE}Days Remaining${RST}      ${WHITE}${BOLD}${remaining}${RST} days" "$w"
    box_empty "$w"
    box_line "  ${pbar}" "$w"
    box_empty "$w"
    box_bot "$w" "$DGRAY"

    # ── Monthly stats ────────────────────────────────────────────────────
    local now; now=$(date +%s)
    local mc=0
    if [ -d "$ANTIGRAVITY_DIR/conversations" ]; then
        for d in "$ANTIGRAVITY_DIR/conversations"/*/; do
            [ -d "$d" ] || continue
            local mt; mt=$(file_mtime "$d")
            (( (now - mt) < 2592000 )) && (( mc++ ))
        done
    fi

    printf "\n"
    box_top "$w" "$DGRAY"
    box_title "Cycle Statistics" "$w"
    box_empty "$w"
    box_line "  ${CYAN}Sessions this cycle${RST}    ${WHITE}${BOLD}${mc}${RST}" "$w"

    if (( day > 0 )); then
        local rate; rate=$(calc "$mc / $day")
        local proj; proj=$(calc "$rate * $dim / 1")
        # strip decimal from projected
        proj=${proj%%.*}
        box_line "  ${CYAN}Avg per day${RST}            ${WHITE}${BOLD}${rate}${RST}" "$w"
        box_line "  ${CYAN}Projected this month${RST}   ${WHITE}${BOLD}${proj:-0}${RST}" "$w"
    fi

    box_empty "$w"
    box_line "  ${DGRAY}Usage typically resets on the 1st of each month.${RST}" "$w"
    box_empty "$w"
    box_bot "$w" "$DGRAY"

    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Account Switcher
# ═══════════════════════════════════════════════════════════════════════════════
get_active_profile() {
    [ -f "$ACTIVE_PROFILE_FILE" ] && cat "$ACTIVE_PROFILE_FILE" 2>/dev/null | tr -d '\n' || echo "default"
}

menu_accounts() {
    while true; do
        draw_header
        local w=$BOX_W
        local active; active=$(get_active_profile)

        mkdir -p "$PROFILES_DIR" 2>/dev/null

        box_top "$w" "$DGRAY"
        box_title "Account Switcher" "$w"
        box_empty "$w"
        box_line "  ${GREEN}●${RST}  Active: ${WHITE}${BOLD}${active}${RST}" "$w"
        box_empty "$w"

        # Gather profiles
        local profiles=()
        local idx=1
        if [ -d "$PROFILES_DIR" ]; then
            for pdir in "$PROFILES_DIR"/*/; do
                [ -d "$pdir" ] || continue
                local pname; pname=$(basename "$pdir")
                profiles+=("$pname")
                local mark=""
                [[ "$pname" == "$active" ]] && mark=" ${GREEN}★${RST}"
                local psz; psz=$(get_size "$pdir")
                box_line "  ${CYAN}[${WHITE}${idx}${CYAN}]${RST}  $(printf '%-20s' "$pname") ${DGRAY}${psz}${RST}${mark}" "$w"
                (( idx++ ))
            done
        fi

        if [ ${#profiles[@]} -eq 0 ]; then
            box_line "  ${DGRAY}No saved profiles yet.${RST}" "$w"
        fi

        box_empty "$w"
        box_sep "$w"
        box_empty "$w"
        box_line "  ${CYAN}[${WHITE}s${CYAN}]${RST}  Save current as new profile" "$w"
        box_line "  ${CYAN}[${RED}d${CYAN}]${RST}  ${RED}Delete a profile${RST}" "$w"
        box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back to main menu${RST}" "$w"
        box_empty "$w"
        box_bot "$w" "$DGRAY"

        printf "\n  ${CYAN}›${RST} "
        local ch; ch=$(read_key)
        [[ -z "$ch" ]] && continue
        printf "\n"

        case "$ch" in
            s|S)
                printf "  Profile name: "
                local pname; pname=$(read_key)
                pname=$(echo "$pname" | tr -cd 'a-zA-Z0-9_-')
                if [ -z "$pname" ]; then err_ "Invalid name (use letters, numbers, - or _)."; wait_key; continue; fi

                if [ -d "$PROFILES_DIR/$pname" ]; then
                    printf "  Profile '${pname}' exists. Overwrite? ${DGRAY}[y/N]${RST} "
                    local yn; yn=$(read_key)
                    [[ "$yn" =~ ^[Yy]$ ]] || { warn_ "Cancelled."; wait_key; continue; }
                    rm -rf "${PROFILES_DIR:?}/$pname"
                fi

                info_ "Saving current session as '${pname}'…"
                mkdir -p "$PROFILES_DIR/$pname"
                [ -d "$GEMINI_DIR" ] && cp -a "$GEMINI_DIR/." "$PROFILES_DIR/$pname/" 2>/dev/null
                echo "$pname" > "$ACTIVE_PROFILE_FILE"
                ok_ "Saved profile '${pname}'."
                wait_key
                ;;

            d|D)
                if [ ${#profiles[@]} -eq 0 ]; then warn_ "No profiles to delete."; wait_key; continue; fi
                printf "  Profile number to delete: "
                local dn; dn=$(read_key)
                if [[ "$dn" =~ ^[0-9]+$ ]] && (( dn >= 1 && dn <= ${#profiles[@]} )); then
                    local tgt="${profiles[$((dn-1))]}"
                    if [[ "$tgt" == "$active" ]]; then
                        err_ "Cannot delete the active profile. Switch first."
                    else
                        rm -rf "${PROFILES_DIR:?}/$tgt"
                        ok_ "Deleted profile '${tgt}'."
                    fi
                else
                    err_ "Invalid selection."
                fi
                wait_key
                ;;

            b|B) return ;;

            [0-9]*)
                local num=$ch
                if (( num >= 1 && num <= ${#profiles[@]} )); then
                    local tgt="${profiles[$((num-1))]}"
                    if [[ "$tgt" == "$active" ]]; then info_ "Already on '${tgt}'."; wait_key; continue; fi

                    warn_ "Switching will close any running Antigravity session."
                    printf "  Switch to '${tgt}'? ${DGRAY}[y/N]${RST} "
                    local yn; yn=$(read_key)
                    [[ "$yn" =~ ^[Yy]$ ]] || { warn_ "Cancelled."; wait_key; continue; }

                    printf "\n"
                    info_ "Saving current session as '${active}'…"
                    mkdir -p "$PROFILES_DIR/$active" 2>/dev/null
                    [ -d "$GEMINI_DIR" ] && { rm -rf "${PROFILES_DIR:?}/$active"; mv "$GEMINI_DIR" "$PROFILES_DIR/$active"; }

                    info_ "Restoring profile '${tgt}'…"
                    mv "$PROFILES_DIR/$tgt" "$GEMINI_DIR"

                    echo "$tgt" > "$ACTIVE_PROFILE_FILE"
                    ANTIGRAVITY_DIR="$GEMINI_DIR/antigravity"
                    BROWSER_PROFILE_DIR="$GEMINI_DIR/antigravity-browser-profile"
                    BACKUP_DIR="$GEMINI_DIR/backups"
                    ok_ "Switched to '${tgt}'."
                    wait_key
                else
                    err_ "Invalid selection."
                    wait_key
                fi
                ;;
            *) continue ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Network Fixer
# ═══════════════════════════════════════════════════════════════════════════════
menu_network() {
    draw_header
    local w=$BOX_W

    box_top "$w" "$DGRAY"
    box_title "Network Fixer" "$w"
    box_empty "$w"

    # DNS
    printf "  ${DGRAY}${VT}${RST}  ${CYAN}DNS${RST}  Flushing cache… " >&2
    local dns_ok=false
    if [[ "$OSTYPE" == darwin* ]]; then
        sudo killall -HUP mDNSResponder 2>/dev/null && dns_ok=true
    else
        { resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || nscd -i hosts 2>/dev/null; } && dns_ok=true
    fi
    $dns_ok && printf "${GREEN}Done${RST}\n" || printf "${YELLOW}Skipped${RST}\n"

    # Google
    printf "  ${DGRAY}${VT}${RST}  ${CYAN}NET${RST}  google.com… "
    if curl -sL --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com 2>/dev/null | grep -q "200"; then
        printf "${GREEN}OK${RST}\n"
    else
        printf "${RED}Unreachable${RST}\n"
    fi

    # Gemini
    printf "  ${DGRAY}${VT}${RST}  ${CYAN}NET${RST}  gemini.google.com… "
    local code; code=$(curl -sL --max-time 5 -o /dev/null -w '%{http_code}' https://gemini.google.com 2>/dev/null)
    if [[ "$code" =~ ^(200|301|302|303)$ ]]; then
        printf "${GREEN}OK${RST}\n"
    else
        printf "${RED}Unreachable (${code:-timeout}) — check region/VPN${RST}\n"
    fi

    # Alkalimetal API
    printf "  ${DGRAY}${VT}${RST}  ${CYAN}API${RST}  alkalimetal endpoint… "
    local code2; code2=$(curl -sL --max-time 5 -o /dev/null -w '%{http_code}' https://alkalimetal-pa.clients6.google.com 2>/dev/null)
    if [[ "$code2" =~ ^[234] ]]; then
        printf "${GREEN}Reachable${RST}\n"
    else
        printf "${RED}Blocked${RST}\n"
    fi

    box_empty "$w"
    box_sep "$w"
    box_line "  ${YELLOW}${BOLD}Common 403 Fixes${RST}" "$w"
    box_empty "$w"
    box_line "  ${DGRAY}1.${RST} Restart Antigravity after DNS flush" "$w"
    box_line "  ${DGRAY}2.${RST} Clear browser profile (Cleaner > 7)" "$w"
    box_line "  ${DGRAY}3.${RST} Disable VPN / proxy if active" "$w"
    box_line "  ${DGRAY}4.${RST} Try switching Google account" "$w"
    box_empty "$w"
    box_bot "$w" "$DGRAY"

    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Browser Backup
# ═══════════════════════════════════════════════════════════════════════════════
menu_backup() {
    draw_header
    local w=$BOX_W
    mkdir -p "$BACKUP_DIR" 2>/dev/null

    # Detect browsers
    declare -A browsers
    if [[ "$OSTYPE" == darwin* ]]; then
        [ -d "$HOME/Library/Application Support/Google/Chrome" ]              && browsers[chrome]="$HOME/Library/Application Support/Google/Chrome"
        [ -d "$HOME/Library/Application Support/Chromium" ]                   && browsers[chromium]="$HOME/Library/Application Support/Chromium"
        [ -d "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ] && browsers[brave]="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
        [ -d "$HOME/Library/Application Support/Microsoft Edge" ]             && browsers[edge]="$HOME/Library/Application Support/Microsoft Edge"
        [ -d "$HOME/Library/Application Support/com.operasoftware.Opera" ]    && browsers[opera]="$HOME/Library/Application Support/com.operasoftware.Opera"
        [ -d "$HOME/Library/Application Support/Firefox/Profiles" ]           && browsers[firefox]="$HOME/Library/Application Support/Firefox/Profiles"
        [ -d "$HOME/Library/Application Support/Arc" ]                        && browsers[arc]="$HOME/Library/Application Support/Arc"
    else
        [ -d "$HOME/.config/google-chrome" ]               && browsers[chrome]="$HOME/.config/google-chrome"
        [ -d "$HOME/.config/chromium" ]                    && browsers[chromium]="$HOME/.config/chromium"
        [ -d "$HOME/.config/BraveSoftware/Brave-Browser" ] && browsers[brave]="$HOME/.config/BraveSoftware/Brave-Browser"
        [ -d "$HOME/.config/microsoft-edge" ]              && browsers[edge]="$HOME/.config/microsoft-edge"
        [ -d "$HOME/.config/opera" ]                       && browsers[opera]="$HOME/.config/opera"
        [ -d "$HOME/.mozilla/firefox" ]                    && browsers[firefox]="$HOME/.mozilla/firefox"
        [ -d "$HOME/.config/vivaldi" ]                     && browsers[vivaldi]="$HOME/.config/vivaldi"
    fi
    [ -d "$BROWSER_PROFILE_DIR" ] && browsers[antigravity]="$BROWSER_PROFILE_DIR"

    box_top "$w" "$DGRAY"
    box_title "Browser Backup" "$w"
    box_empty "$w"

    if [ ${#browsers[@]} -eq 0 ]; then
        box_line "  ${YELLOW}No browsers detected.${RST}" "$w"
        box_empty "$w"
        box_bot "$w" "$DGRAY"
        wait_key; return
    fi

    local keys=("${!browsers[@]}")
    local idx=1
    for name in "${keys[@]}"; do
        local sz; sz=$(get_size "${browsers[$name]}")
        box_line "  ${CYAN}[${WHITE}${idx}${CYAN}]${RST}  $(printf '%-22s' "$name") ${DGRAY}${sz}${RST}" "$w"
        (( idx++ ))
    done

    box_empty "$w"
    box_line "  ${CYAN}[${WHITE}a${CYAN}]${RST}  Backup ALL detected browsers" "$w"
    box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back to main menu${RST}" "$w"
    box_empty "$w"
    box_bot "$w" "$DGRAY"

    printf "\n  ${CYAN}›${RST} "
    local ch; ch=$(read_key)
    [[ -z "$ch" ]] && return
    printf "\n"

    _backup_one() {
        local name="$1" path="$2"
        local ts; ts=$(date +%Y%m%d_%H%M%S)
        local out="$BACKUP_DIR/${name}_backup_${ts}.tar.gz"
        printf "  ${DGRAY}…${RST}  Backing up ${WHITE}%s${RST}" "$name"
        tar -czf "$out" -C "$(dirname "$path")" "$(basename "$path")" \
            --exclude="Cache" --exclude="Code Cache" --exclude="GPUCache" \
            --exclude="Service Worker" 2>/dev/null || true
        printf "\r  ${GREEN}✓${RST}  ${WHITE}%s${RST} ${DGRAY}→${RST} %s\n" "$name" "$(basename "$out")"
    }

    case "$ch" in
        a|A)
            for name in "${keys[@]}"; do _backup_one "$name" "${browsers[$name]}"; done
            printf "\n"; ok_ "All backups saved to $BACKUP_DIR"
            wait_key
            ;;
        b|B) return ;;
        [0-9]*)
            if (( ch >= 1 && ch <= ${#keys[@]} )); then
                _backup_one "${keys[$((ch-1))]}" "${browsers[${keys[$((ch-1))]}]}"
                printf "\n"; ok_ "Backup saved to $BACKUP_DIR"
            else
                err_ "Invalid selection."
            fi
            wait_key
            ;;
        *) ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Quick mode (non-interactive)
# ═══════════════════════════════════════════════════════════════════════════════
run_quick() {
    printf "\n  ${CYAN}${BOLD}Antigravity Quick Clean${RST}\n\n"
    $FLAG_DRY_RUN && { warn_ "DRY RUN — no files will be deleted."; printf "\n"; }
    clean_dir "$ANTIGRAVITY_DIR/brain" "Brain Artifacts"
    clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser Recordings"
    clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
    clean_dir "$ANTIGRAVITY_DIR/context_state" "Context State"
    clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code Tracker"
    clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit Memory"
    printf "\n"
    $FLAG_DRY_RUN || ok_ "All cache cleaned."
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Main Menu
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        draw_header
        local w=$BOX_W

        box_top "$w" "$DGRAY"
        box_title "Main Menu" "$w"
        box_empty "$w"
        box_line "  ${CYAN}[${WHITE}1${CYAN}]${RST}  ${WHITE}Cache Cleaner${RST}          ${DGRAY}Clean cache${RST}" "$w"
        box_line "  ${CYAN}[${WHITE}2${CYAN}]${RST}  ${WHITE}Usage Dashboard${RST}         ${DGRAY}View statistics${RST}" "$w"
        box_line "  ${CYAN}[${WHITE}3${CYAN}]${RST}  ${WHITE}Reset Timer${RST}             ${DGRAY}Next usage reset${RST}" "$w"
        box_line "  ${CYAN}[${WHITE}4${CYAN}]${RST}  ${WHITE}Account Switcher${RST}        ${DGRAY}Manage profiles${RST}" "$w"
        box_line "  ${CYAN}[${WHITE}5${CYAN}]${RST}  ${WHITE}Network Fixer${RST}           ${DGRAY}Fix DNS & 403s${RST}" "$w"
        box_line "  ${CYAN}[${WHITE}6${CYAN}]${RST}  ${WHITE}Browser Backup${RST}          ${DGRAY}Backup browsers${RST}" "$w"
        box_empty "$w"
        box_line "  ${CYAN}[${DGRAY}0${CYAN}]${RST}  ${DGRAY}Exit${RST}" "$w"
        box_empty "$w"
        box_bot "$w" "$DGRAY"

        printf "\n  ${CYAN}›${RST} "
        local choice; choice=$(read_key)

        # Empty input (bare Enter) → just redraw, no exit
        [[ -z "$choice" ]] && continue

        case "$choice" in
            1) menu_cleaner ;;
            2) menu_usage ;;
            3) menu_reset ;;
            4) menu_accounts ;;
            5) menu_network ;;
            6) menu_backup ;;
            0|q|Q)
                show_cursor
                printf "\n  ${CYAN}Goodbye!${RST}\n\n"
                exit 0
                ;;
            *) continue ;;   # unknown input → redraw
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  CLI argument parsing
# ═══════════════════════════════════════════════════════════════════════════════
show_help() {
cat <<'HELP'
Antigravity Toolkit v3.0

Usage:  antigravity-cleaner.sh [OPTIONS]

Options:
  -q, --quick      Non-interactive mode — clean all cache safely
  -d, --dry-run    Preview what would be deleted (pair with -q)
  -h, --help       Show this help

Interactive mode (default):
  Launch the full TUI with cleaner, usage dashboard, reset timer,
  account switcher, network fixer, and browser backup.

One-liner:
  curl -sL https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.sh | bash
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quick)   FLAG_QUICK=true; shift ;;
        -d|--dry-run) FLAG_DRY_RUN=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        *)            printf "Unknown option: %s\n" "$1"; show_help; exit 1 ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
#  Entry
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -d "$GEMINI_DIR" ]; then
    printf "\n  ${RED}Antigravity cache directory not found at %s${RST}\n" "$GEMINI_DIR"
    printf "  ${DGRAY}Is Antigravity installed?${RST}\n\n"
    exit 1
fi

if $FLAG_QUICK; then
    run_quick
else
    main_menu
fi
