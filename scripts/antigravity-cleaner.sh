#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Antigravity Toolkit v3.1 — TUI Edition
#  Complete system toolkit for the Antigravity IDE.
#  Supports: Linux (Arch, Ubuntu, Fedora, etc.), macOS
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Redirect stdin when piped (curl | bash) ─────────────────────────────────
if [ ! -t 0 ]; then exec < /dev/tty; fi
read -r -t 0.1 -n 10000 _discard 2>/dev/null || true
set +e

# ─── Paths ────────────────────────────────────────────────────────────────────
GEMINI_DIR="$HOME/.gemini"
AG_DIR="$GEMINI_DIR/antigravity"
BP_DIR="$GEMINI_DIR/antigravity-browser-profile"
BP_DEF="$BP_DIR/Default"
BACKUP_DIR="$GEMINI_DIR/backups"
PROFILES_DIR="$HOME/.antigravity-profiles"
ACTIVE_FILE="$PROFILES_DIR/.active"
VERSION="3.1"

FLAG_QUICK=false
FLAG_DRY_RUN=false

# ═══════════════════════════════════════════════════════════════════════════════
#  Colors
# ═══════════════════════════════════════════════════════════════════════════════
RST='\033[0m' BOLD='\033[1m' DIM='\033[2m'
CYAN='\033[38;5;81m'  LCYAN='\033[38;5;123m' MAGENTA='\033[38;5;205m'
BLUE='\033[38;5;75m'  GREEN='\033[38;5;114m' LGREEN='\033[38;5;156m'
YELLOW='\033[38;5;222m' ORANGE='\033[38;5;209m' RED='\033[38;5;203m'
WHITE='\033[38;5;255m' GRAY='\033[38;5;246m' DGRAY='\033[38;5;239m'
BG_SEL='\033[48;5;238m'

# ─── Box drawing ──────────────────────────────────────────────────────────────
TL="╭" TR="╮" BL="╰" BR="╯" HZ="─" VT="│" LT="├" RT="┤"
W=62 # box width

# ═══════════════════════════════════════════════════════════════════════════════
#  Low-level helpers
# ═══════════════════════════════════════════════════════════════════════════════
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
trap 'show_cursor; printf "${RST}"' EXIT INT TERM

read_key() {
    show_cursor; local i=""; read -r i; hide_cursor
    i="${i#"${i%%[![:space:]]*}"}"; i="${i%"${i##*[![:space:]]}"}"
    printf '%s' "$i"
}

calc() { echo "$1" | bc 2>/dev/null || awk "BEGIN{printf \"%.1f\", $1}" 2>/dev/null || echo "?"; }

file_mtime() {
    [[ "$OSTYPE" == darwin* ]] && stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# ─── Distro detection ────────────────────────────────────────────────────────
detect_distro() {
    if [[ "$OSTYPE" == darwin* ]]; then echo "macos"; return; fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|garuda) echo "arch" ;;
            ubuntu|debian|pop|linuxmint|elementary) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            opensuse*|sles) echo "suse" ;;
            *) echo "linux" ;;
        esac
    else
        echo "linux"
    fi
}
DISTRO=$(detect_distro)

# ═══════════════════════════════════════════════════════════════════════════════
#  Box-drawing primitives
# ═══════════════════════════════════════════════════════════════════════════════
box_top()   { printf "  ${DGRAY}${TL}"; printf '%*s' "$((W-2))" '' | tr ' ' "$HZ"; printf "${TR}${RST}\n"; }
box_bot()   { printf "  ${DGRAY}${BL}"; printf '%*s' "$((W-2))" '' | tr ' ' "$HZ"; printf "${BR}${RST}\n"; }
box_sep()   { printf "  ${DGRAY}${LT}"; printf '%*s' "$((W-2))" '' | tr ' ' "$HZ"; printf "${RT}${RST}\n"; }
box_empty() { printf "  ${DGRAY}${VT}${RST}%*s${DGRAY}${VT}${RST}\n" "$((W-2))" ''; }
box_line() {
    local text="$1"
    local vis; vis=$(printf '%b' "$text" | sed $'s/\033\[[0-9;]*m//g')
    local pad=$(( W - 4 - ${#vis} )); (( pad < 0 )) && pad=0
    printf "  ${DGRAY}${VT}${RST} %b%*s ${DGRAY}${VT}${RST}\n" "$text" "$pad" ''
}
box_title() {
    local t="$1" d=$(( W - 6 - ${#1} )); (( d < 2 )) && d=2
    printf "  ${DGRAY}${LT}${HZ}${RST} ${CYAN}${BOLD}%s${RST} ${DGRAY}" "$t"
    printf '%*s' "$d" '' | tr ' ' "$HZ"; printf "${RT}${RST}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Utility functions
# ═══════════════════════════════════════════════════════════════════════════════
get_size()       { [ -d "$1" ] && du -sh "$1" 2>/dev/null | cut -f1 || echo "0B"; }
get_size_bytes() { [ -d "$1" ] && du -sb "$1" 2>/dev/null | cut -f1 || echo "0"; }

fmt_size() {
    local u="${1//[0-9.]/}"
    case "$u" in G*) printf "${RED}${BOLD}%s${RST}" "$1";; M*) printf "${ORANGE}%s${RST}" "$1";;
                  K*) printf "${YELLOW}%s${RST}" "$1";; *) printf "${GREEN}%s${RST}" "$1";; esac
}
fmt_bytes() {
    local b=$1
    if   (( b >= 1073741824 )); then printf "${RED}${BOLD}%s GB${RST}" "$(calc "$b/1073741824")"
    elif (( b >= 1048576 ));    then printf "${ORANGE}%s MB${RST}" "$(calc "$b/1048576")"
    elif (( b >= 1024 ));       then printf "${YELLOW}%s KB${RST}" "$(calc "$b/1024")"
    else printf "${GREEN}%d B${RST}" "$b"; fi
}
count_items() { [ -d "$1" ] && find "$1" $2 2>/dev/null | wc -l | tr -d ' ' || echo "0"; }

ok_()   { printf "  ${GREEN}✓${RST}  ${GREEN}%s${RST}\n" "$1"; }
err_()  { printf "  ${RED}✗${RST}  ${RED}%s${RST}\n" "$1"; }
warn_() { printf "  ${YELLOW}!${RST}  ${YELLOW}%s${RST}\n" "$1"; }
info_() { printf "  ${BLUE}●${RST}  %s\n" "$1"; }
wait_key() { printf "\n  ${DGRAY}Press Enter to continue…${RST} "; show_cursor; read -r; hide_cursor; }

progress_bar() {
    local cur=$1 tot=$2 w=${3:-32}; (( tot<=0 )) && tot=1
    local pct=$(( cur*100/tot )) fill=$(( cur*w/tot )); (( fill>w )) && fill=$w
    local empty=$((w-fill))
    printf "${DGRAY}[${GREEN}"; (( fill>0 )) && printf '%*s' "$fill" '' | tr ' ' '█'
    printf "${DGRAY}"; (( empty>0 )) && printf '%*s' "$empty" '' | tr ' ' '░'
    printf "] ${WHITE}%3d%%${RST}" "$pct"
}

clean_dir() {
    local dir="$1" desc="$2"
    if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
        local sz; sz=$(get_size "$dir")
        if $FLAG_DRY_RUN; then printf "  ${YELLOW}DRY${RST}  Would clean %s — " "$desc"; fmt_size "$sz"; printf "\n"; return 0; fi
        printf "  ${DGRAY}…${RST}   Cleaning %s" "$desc"
        rm -rf "${dir:?}"/* 2>/dev/null; sleep 0.1
        printf "\r  ${GREEN}✓${RST}   ${WHITE}%s${RST} ${DGRAY}—${RST} " "$desc"; fmt_size "$sz"; printf " ${GREEN}freed${RST}\n"
    else printf "  ${DGRAY}–${RST}   ${DIM}%s is empty${RST}\n" "$desc"; fi
}

clean_file() {
    local f="$1" desc="$2"
    if [ -f "$f" ]; then
        if $FLAG_DRY_RUN; then printf "  ${YELLOW}DRY${RST}  Would remove %s\n" "$desc"; return; fi
        rm -f "$f" 2>/dev/null
        printf "  ${GREEN}✓${RST}   ${WHITE}%s${RST} removed\n" "$desc"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Header
# ═══════════════════════════════════════════════════════════════════════════════
draw_header() {
    clear; hide_cursor; printf "\n"
    box_top
    box_empty
    box_line "${MAGENTA}${BOLD}  A N T I G R A V I T Y${RST}"
    box_line "${CYAN}${BOLD}  T O O L K I T${RST}"
    box_empty
    box_line "${DGRAY}  v${VERSION}  •  ${DISTRO}  •  Complete System Toolkit${RST}"
    box_empty
    box_bot
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  1. Cache Cleaner
# ═══════════════════════════════════════════════════════════════════════════════
menu_cleaner() {
    while true; do
        draw_header
        # Show sizes
        box_top; box_title "Cache Status"; box_empty
        local dirs=(
            "$AG_DIR/brain|Brain (artifacts/plans)"
            "$AG_DIR/conversations|Conversations"
            "$AG_DIR/browser_recordings|Browser Recordings"
            "$AG_DIR/context_state|Context State"
            "$AG_DIR/code_tracker|Code Tracker"
            "$AG_DIR/implicit|Implicit Memory"
            "$AG_DIR/annotations|Annotations"
            "$AG_DIR/knowledge|Knowledge Base"
            "$AG_DIR/playground|Playground"
            "$AG_DIR/scratch|Scratch Space"
            "$BP_DIR|Browser Profile (full)"
        )
        local tb=0
        for e in "${dirs[@]}"; do
            local d="${e%%|*}" n="${e##*|}" sb; sb=$(get_size_bytes "$d"); tb=$((tb+sb))
            local sz; sz=$(get_size "$d"); local sc; sc=$(fmt_size "$sz")
            box_line "  ${WHITE}$(printf '%-30s' "$n")${RST}${sc}"
        done
        box_sep
        local tc; tc=$(fmt_bytes "$tb")
        box_line "  ${WHITE}${BOLD}$(printf '%-30s' "TOTAL")${RST}${tc}"
        box_bot; printf "\n"

        box_top; box_title "Clean Options"; box_empty
        box_line "  ${CYAN}[${WHITE}1${CYAN}]${RST}  Browser Recordings"
        box_line "  ${CYAN}[${WHITE}2${CYAN}]${RST}  Conversations"
        box_line "  ${CYAN}[${WHITE}3${CYAN}]${RST}  Brain Artifacts"
        box_line "  ${CYAN}[${WHITE}4${CYAN}]${RST}  Context State"
        box_line "  ${CYAN}[${WHITE}5${CYAN}]${RST}  Code Tracker + Annotations"
        box_line "  ${CYAN}[${WHITE}6${CYAN}]${RST}  Implicit Memory + Knowledge"
        box_line "  ${CYAN}[${WHITE}7${CYAN}]${RST}  Playground + Scratch"
        box_empty
        box_line "  ${BG_SEL}${CYAN}[${WHITE}${BOLD}8${CYAN}]${RST}${BG_SEL}  ${LGREEN}Clean ALL cache (safe)${RST}"
        box_line "  ${CYAN}[${RED}9${CYAN}]${RST}  ${RED}Aggressive clean (nuclear)${RST}"
        box_empty
        box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back${RST}"
        box_empty; box_bot

        printf "\n  ${CYAN}›${RST} "; local ch; ch=$(read_key)
        [[ -z "$ch" ]] && continue; printf "\n"

        case "$ch" in
            1) clean_dir "$AG_DIR/browser_recordings" "Browser Recordings"; wait_key;;
            2) clean_dir "$AG_DIR/conversations" "Conversations"; wait_key;;
            3) clean_dir "$AG_DIR/brain" "Brain Artifacts"; wait_key;;
            4) clean_dir "$AG_DIR/context_state" "Context State"; wait_key;;
            5) clean_dir "$AG_DIR/code_tracker" "Code Tracker"
               clean_dir "$AG_DIR/annotations" "Annotations"; wait_key;;
            6) clean_dir "$AG_DIR/implicit" "Implicit Memory"
               clean_dir "$AG_DIR/knowledge" "Knowledge Base"; wait_key;;
            7) clean_dir "$AG_DIR/playground" "Playground"
               clean_dir "$AG_DIR/scratch" "Scratch Space"; wait_key;;
            8)
                for d in brain conversations browser_recordings context_state code_tracker implicit annotations knowledge playground scratch; do
                    clean_dir "$AG_DIR/$d" "$d"
                done
                ok_ "All cache cleaned."; wait_key;;
            9)
                printf "  ${RED}${BOLD}NUCLEAR CLEAN${RST}: This removes ALL data including\n"
                printf "  browser profile, config, installation ID — everything.\n"
                printf "  Antigravity will be fully reset.\n\n"
                printf "  Type ${RED}${BOLD}NUKE${RST} to confirm: "
                local confirm; confirm=$(read_key)
                if [[ "$confirm" == "NUKE" ]]; then
                    printf "\n"
                    for d in brain conversations browser_recordings context_state code_tracker implicit annotations knowledge playground scratch; do
                        clean_dir "$AG_DIR/$d" "$d"
                    done
                    clean_dir "$BP_DIR" "Browser Profile"
                    clean_file "$AG_DIR/mcp_config.json" "MCP Config"
                    clean_file "$AG_DIR/user_settings.pb" "User Settings"
                    clean_file "$AG_DIR/browserOnboardingStatus.txt" "Onboarding Status"
                    clean_file "$GEMINI_DIR/GEMINI.md" "GEMINI.md"
                    ok_ "Nuclear clean complete. Restart Antigravity."
                else
                    warn_ "Cancelled."
                fi
                wait_key;;
            b|B) return;; *) continue;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  2. Browser Toolkit  (Antigravity's built-in Chromium browser)
# ═══════════════════════════════════════════════════════════════════════════════
menu_browser() {
    while true; do
        draw_header
        box_top; box_title "Antigravity Browser Toolkit"; box_empty

        # Sizes
        local cache_sz; cache_sz=$(get_size "$BP_DEF/Cache")
        local code_sz;  code_sz=$(get_size "$BP_DEF/Code Cache")
        local gpu_sz;   gpu_sz=$(get_size "$BP_DEF/GPUCache")
        local ls_sz;    ls_sz=$(get_size "$BP_DEF/Local Storage")
        local ss_sz;    ss_sz=$(get_size "$BP_DEF/Session Storage")
        local sw_sz;    sw_sz=$(get_size "$BP_DEF/Service Worker")
        local shader_sz;shader_sz=$(get_size "$BP_DIR/ShaderCache")
        local comp_sz;  comp_sz=$(get_size "$BP_DIR/component_crx_cache")
        local sb_sz;    sb_sz=$(get_size "$BP_DIR/Safe Browsing")
        local prof_total; prof_total=$(get_size "$BP_DIR")

        box_line "  ${DGRAY}Browser profile:${RST} ${WHITE}$prof_total${RST}"
        box_line "  ${DGRAY}  Default/Cache:${RST}         $cache_sz"
        box_line "  ${DGRAY}  Default/Code Cache:${RST}    $code_sz"
        box_line "  ${DGRAY}  Default/GPUCache:${RST}      $gpu_sz"
        box_line "  ${DGRAY}  Default/Local Storage:${RST} $ls_sz"
        box_line "  ${DGRAY}  ShaderCache:${RST}           $shader_sz"
        box_line "  ${DGRAY}  component_crx_cache:${RST}   $comp_sz"
        box_line "  ${DGRAY}  Safe Browsing:${RST}         $sb_sz"

        local has_lock="No"
        [ -f "$BP_DEF/SingletonLock" ] || [ -f "$BP_DEF/LOCK" ] && has_lock="${RED}YES${RST}"
        box_line "  ${DGRAY}  Lock files:${RST}            $has_lock"
        box_empty; box_sep; box_empty

        box_line "  ${CYAN}[${WHITE}1${CYAN}]${RST}  Clean browser cache (Cache/Code/GPU)"
        box_line "  ${CYAN}[${WHITE}2${CYAN}]${RST}  Clean cookies & sessions"
        box_line "  ${CYAN}[${WHITE}3${CYAN}]${RST}  Clean local/session storage"
        box_line "  ${CYAN}[${WHITE}4${CYAN}]${RST}  Clean Service Workers & IndexedDB"
        box_line "  ${CYAN}[${WHITE}5${CYAN}]${RST}  Clean shader/GPU caches"
        box_line "  ${CYAN}[${WHITE}6${CYAN}]${RST}  Clean component cache & Safe Browsing"
        box_line "  ${CYAN}[${WHITE}7${CYAN}]${RST}  Fix lock files (SingletonLock/LOCK)"
        box_line "  ${CYAN}[${WHITE}8${CYAN}]${RST}  Clean browsing history"
        box_empty
        box_line "  ${BG_SEL}${CYAN}[${WHITE}${BOLD}9${CYAN}]${RST}${BG_SEL}  ${LGREEN}Clean ALL browser data${RST}"
        box_line "  ${CYAN}[${RED}0${CYAN}]${RST}  ${RED}Full browser profile reset${RST}"
        box_empty
        box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back${RST}"
        box_empty; box_bot

        printf "\n  ${CYAN}›${RST} "; local ch; ch=$(read_key)
        [[ -z "$ch" ]] && continue; printf "\n"

        case "$ch" in
            1)  clean_dir "$BP_DEF/Cache" "Browser Cache"
                clean_dir "$BP_DEF/Code Cache" "Code Cache"
                clean_dir "$BP_DEF/GPUCache" "GPU Cache"
                clean_dir "$BP_DEF/DawnGraphiteCache" "Dawn Graphite Cache"
                clean_dir "$BP_DEF/DawnWebGPUCache" "Dawn WebGPU Cache"
                wait_key;;
            2)  clean_file "$BP_DEF/Cookies" "Cookies"
                clean_file "$BP_DEF/Cookies-journal" "Cookies journal"
                clean_file "$BP_DEF/Safe Browsing Cookies" "Safe Browsing Cookies"
                clean_file "$BP_DEF/Safe Browsing Cookies-journal" "SB Cookies journal"
                clean_dir "$BP_DEF/Sessions" "Sessions"
                wait_key;;
            3)  clean_dir "$BP_DEF/Local Storage" "Local Storage"
                clean_dir "$BP_DEF/Session Storage" "Session Storage"
                clean_dir "$BP_DEF/WebStorage" "WebStorage"
                clean_dir "$BP_DEF/SharedStorage" "Shared Storage"
                wait_key;;
            4)  clean_dir "$BP_DEF/Service Worker" "Service Workers"
                clean_dir "$BP_DEF/blob_storage" "Blob Storage"
                clean_dir "$BP_DEF/Shared Dictionary" "Shared Dictionary"
                wait_key;;
            5)  clean_dir "$BP_DIR/ShaderCache" "ShaderCache"
                clean_dir "$BP_DIR/GrShaderCache" "GrShaderCache"
                clean_dir "$BP_DIR/GraphiteDawnCache" "GraphiteDawnCache"
                clean_dir "$BP_DEF/GPUCache" "Default GPUCache"
                clean_dir "$BP_DEF/DawnGraphiteCache" "Dawn Graphite"
                clean_dir "$BP_DEF/DawnWebGPUCache" "Dawn WebGPU"
                wait_key;;
            6)  clean_dir "$BP_DIR/component_crx_cache" "Component CRX Cache"
                clean_dir "$BP_DIR/Safe Browsing" "Safe Browsing Data"
                clean_dir "$BP_DIR/extensions_crx_cache" "Extensions Cache"
                clean_dir "$BP_DIR/WidevineCdm" "Widevine DRM"
                clean_dir "$BP_DIR/WasmTtsEngine" "WASM TTS Engine"
                wait_key;;
            7)  info_ "Removing lock files…"
                clean_file "$BP_DEF/SingletonLock" "SingletonLock"
                clean_file "$BP_DEF/LOCK" "LOCK"
                clean_file "$BP_DEF/lockfile" "lockfile"
                ok_ "Lock files cleared. Try restarting Antigravity."
                wait_key;;
            8)  clean_file "$BP_DEF/History" "History"
                clean_file "$BP_DEF/History-journal" "History journal"
                clean_file "$BP_DEF/Favicons" "Favicons"
                clean_file "$BP_DEF/Favicons-journal" "Favicons journal"
                clean_file "$BP_DEF/Top Sites" "Top Sites"
                clean_file "$BP_DEF/Top Sites-journal" "Top Sites journal"
                clean_file "$BP_DEF/Shortcuts" "Shortcuts"
                clean_file "$BP_DEF/Shortcuts-journal" "Shortcuts journal"
                clean_file "$BP_DEF/Network Action Predictor" "Network Predictor"
                wait_key;;
            9)  info_ "Cleaning all browser data…"
                # Caches
                for d in Cache "Code Cache" GPUCache DawnGraphiteCache DawnWebGPUCache \
                         "Local Storage" "Session Storage" WebStorage SharedStorage \
                         "Service Worker" blob_storage Sessions "Shared Dictionary" \
                         "Download Service" "Feature Engagement Tracker"; do
                    clean_dir "$BP_DEF/$d" "$d"
                done
                # GPU caches at top level
                for d in ShaderCache GrShaderCache GraphiteDawnCache; do
                    clean_dir "$BP_DIR/$d" "$d"
                done
                # Files
                for f in Cookies Cookies-journal History History-journal \
                         Favicons Favicons-journal "Top Sites" "Top Sites-journal" \
                         Shortcuts Shortcuts-journal "Safe Browsing Cookies" \
                         "Safe Browsing Cookies-journal" "Network Action Predictor" \
                         "Network Action Predictor-journal" DIPS; do
                    clean_file "$BP_DEF/$f" "$f"
                done
                clean_file "$BP_DEF/SingletonLock" "SingletonLock"
                clean_file "$BP_DEF/LOCK" "LOCK"
                clean_file "$BP_DIR/BrowserMetrics-spare.pma" "BrowserMetrics"
                ok_ "All browser data cleaned."
                wait_key;;
            0)  printf "  ${RED}${BOLD}WARNING${RST}: Full reset deletes the entire browser profile.\n"
                printf "  You will lose all browser cookies, history, extensions.\n"
                printf "  Type ${RED}RESET${RST} to confirm: "
                local c; c=$(read_key)
                if [[ "$c" == "RESET" ]]; then
                    printf "\n"; clean_dir "$BP_DIR" "Entire Browser Profile"
                    ok_ "Browser profile reset. Restart Antigravity."
                else printf "\n"; warn_ "Cancelled."
                fi; wait_key;;
            b|B) return;; *) continue;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  3. Network Fixer
# ═══════════════════════════════════════════════════════════════════════════════
flush_dns() {
    case "$DISTRO" in
        macos)  sudo killall -HUP mDNSResponder 2>/dev/null && sudo dscacheutil -flushcache 2>/dev/null;;
        arch)   resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null;;
        debian) resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || nscd -i hosts 2>/dev/null;;
        fedora) systemd-resolve --flush-caches 2>/dev/null || resolvectl flush-caches 2>/dev/null;;
        *)      resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || nscd -i hosts 2>/dev/null;;
    esac
}

test_url() {
    local url="$1" name="$2"
    printf "  ${DGRAY}${VT}${RST}  ${CYAN}%-5s${RST} %s… " "$name" "$url"
    local code; code=$(curl -sL --max-time 8 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    if [[ "$code" =~ ^(200|301|302|303)$ ]]; then
        printf "${GREEN}OK (${code})${RST}\n"; return 0
    elif [[ "$code" == "403" ]]; then
        printf "${RED}403 Forbidden${RST}\n"; return 1
    elif [[ "$code" == "429" ]]; then
        printf "${ORANGE}429 Rate Limited${RST}\n"; return 1
    else
        printf "${RED}Failed (${code:-timeout})${RST}\n"; return 1
    fi
}

menu_network() {
    draw_header
    box_top; box_title "Network Fixer ($DISTRO)"; box_empty

    printf "  ${DGRAY}${VT}${RST}  ${CYAN}DNS${RST}   Flushing cache… "
    flush_dns && printf "${GREEN}Done${RST}\n" || printf "${YELLOW}Skipped${RST}\n"

    test_url "https://www.google.com" "NET"
    test_url "https://gemini.google.com" "GEM"
    test_url "https://alkalimetal-pa.clients6.google.com" "API"
    test_url "https://generativelanguage.googleapis.com" "GAPI"

    box_empty; box_sep
    box_line "  ${YELLOW}${BOLD}Common Fixes${RST}"
    box_empty
    box_line "  ${DGRAY}1.${RST} Restart Antigravity after DNS flush"
    box_line "  ${DGRAY}2.${RST} Clean browser cache (Browser Toolkit > 1)"
    box_line "  ${DGRAY}3.${RST} Reset browser profile (Browser Toolkit > 0)"
    box_line "  ${DGRAY}4.${RST} Disable VPN / proxy"
    box_line "  ${DGRAY}5.${RST} Switch Google account (Account Switcher)"
    box_line "  ${DGRAY}6.${RST} Check firewall rules for Google domains"
    box_line "  ${DGRAY}7.${RST} Try 'Fix Everything' (main menu > 8)"
    box_empty; box_bot

    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  4. Troubleshooter
# ═══════════════════════════════════════════════════════════════════════════════
menu_troubleshoot() {
    draw_header
    box_top; box_title "Troubleshooter"; box_empty
    box_line "  ${DGRAY}Running diagnostics…${RST}"
    box_empty; box_bot; printf "\n"

    local issues=0
    local fixes=()

    # 1. Antigravity directory
    printf "  ${CYAN}[1/9]${RST} Antigravity directory… "
    if [ -d "$GEMINI_DIR" ] && [ -d "$AG_DIR" ]; then
        printf "${GREEN}OK${RST}\n"
    else
        printf "${RED}Missing${RST}\n"; ((issues++))
    fi

    # 2. Internet
    printf "  ${CYAN}[2/9]${RST} Internet connectivity… "
    if curl -sL --max-time 5 -o /dev/null https://www.google.com 2>/dev/null; then
        printf "${GREEN}OK${RST}\n"
    else
        printf "${RED}No internet${RST}\n"; ((issues++))
        fixes+=("flush_dns")
    fi

    # 3. DNS
    printf "  ${CYAN}[3/9]${RST} DNS resolution… "
    if command -v nslookup &>/dev/null && nslookup gemini.google.com &>/dev/null; then
        printf "${GREEN}OK${RST}\n"
    elif command -v host &>/dev/null && host gemini.google.com &>/dev/null; then
        printf "${GREEN}OK${RST}\n"
    else
        printf "${YELLOW}Uncertain${RST}\n"
    fi

    # 4. Gemini API
    printf "  ${CYAN}[4/9]${RST} Gemini API access… "
    local api_code; api_code=$(curl -sL --max-time 8 -o /dev/null -w '%{http_code}' https://gemini.google.com 2>/dev/null)
    if [[ "$api_code" =~ ^(200|301|302|303)$ ]]; then
        printf "${GREEN}OK (${api_code})${RST}\n"
    elif [[ "$api_code" == "403" ]]; then
        printf "${RED}403 Forbidden${RST}\n"; ((issues++))
        fixes+=("flush_dns" "clean_browser_cache")
    elif [[ "$api_code" == "429" ]]; then
        printf "${ORANGE}429 Rate Limited — wait for reset${RST}\n"; ((issues++))
    else
        printf "${RED}Failed (${api_code:-timeout})${RST}\n"; ((issues++))
        fixes+=("flush_dns")
    fi

    # 5. Alkalimetal API
    printf "  ${CYAN}[5/9]${RST} Alkalimetal endpoint… "
    local alka_code; alka_code=$(curl -sL --max-time 8 -o /dev/null -w '%{http_code}' https://alkalimetal-pa.clients6.google.com 2>/dev/null)
    if [[ "$alka_code" =~ ^[234] ]]; then
        printf "${GREEN}Reachable${RST}\n"
    else
        printf "${RED}Blocked${RST}\n"; ((issues++))
        fixes+=("flush_dns")
    fi

    # 6. Browser profile
    printf "  ${CYAN}[6/9]${RST} Browser profile… "
    if [ -d "$BP_DIR" ]; then
        local lock_issue=false
        [ -f "$BP_DEF/SingletonLock" ] && lock_issue=true
        if $lock_issue; then
            printf "${YELLOW}Lock file present${RST}\n"; ((issues++))
            fixes+=("fix_locks")
        else
            printf "${GREEN}OK${RST}\n"
        fi
    else
        printf "${DGRAY}Not found (will be created)${RST}\n"
    fi

    # 7. Disk space
    printf "  ${CYAN}[7/9]${RST} Disk space… "
    local avail; avail=$(df -BM "$HOME" 2>/dev/null | awk 'NR==2{print $4}' | tr -d 'M')
    if [ -n "$avail" ] && (( avail > 500 )); then
        printf "${GREEN}OK (${avail}MB free)${RST}\n"
    elif [ -n "$avail" ]; then
        printf "${YELLOW}Low (${avail}MB free)${RST}\n"; ((issues++))
        fixes+=("clean_all_cache")
    else
        printf "${DGRAY}Unknown${RST}\n"
    fi

    # 8. Cache size
    printf "  ${CYAN}[8/9]${RST} Cache size… "
    local cache_bytes; cache_bytes=$(get_size_bytes "$AG_DIR")
    if (( cache_bytes > 2147483648 )); then  # > 2GB
        printf "${ORANGE}Large ($(get_size "$AG_DIR")) — consider cleaning${RST}\n"
        fixes+=("clean_all_cache")
    else
        printf "${GREEN}OK ($(get_size "$AG_DIR"))${RST}\n"
    fi

    # 9. Rate limit check
    printf "  ${CYAN}[9/9]${RST} Rate limit status… "
    if [[ "$api_code" == "429" ]]; then
        printf "${RED}Rate limited — check Reset Timer${RST}\n"
    else
        printf "${GREEN}Not rate limited${RST}\n"
    fi

    # Summary
    printf "\n"
    box_top; box_empty
    if (( issues == 0 )); then
        box_line "  ${GREEN}${BOLD}All checks passed!${RST} No issues detected."
    else
        box_line "  ${YELLOW}${BOLD}${issues} issue(s) detected.${RST}"
    fi
    box_empty

    if (( ${#fixes[@]} > 0 )); then
        box_sep; box_empty
        box_line "  ${CYAN}[${WHITE}f${CYAN}]${RST}  Auto-fix all detected issues"
    fi
    box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back${RST}"
    box_empty; box_bot

    printf "\n  ${CYAN}›${RST} "; local ch; ch=$(read_key)
    if [[ "$ch" == "f" || "$ch" == "F" ]] && (( ${#fixes[@]} > 0 )); then
        printf "\n"
        info_ "Applying fixes…"
        # Deduplicate
        local unique_fixes=($(echo "${fixes[@]}" | tr ' ' '\n' | sort -u))
        for fix in "${unique_fixes[@]}"; do
            case "$fix" in
                flush_dns)        printf "  "; flush_dns && ok_ "DNS flushed" || warn_ "DNS flush failed";;
                clean_browser_cache)
                    clean_dir "$BP_DEF/Cache" "Browser Cache"
                    clean_dir "$BP_DEF/Code Cache" "Code Cache";;
                fix_locks)
                    clean_file "$BP_DEF/SingletonLock" "SingletonLock"
                    clean_file "$BP_DEF/LOCK" "LOCK";;
                clean_all_cache)
                    for d in brain conversations browser_recordings context_state code_tracker implicit annotations knowledge playground scratch; do
                        clean_dir "$AG_DIR/$d" "$d"
                    done;;
            esac
        done
        ok_ "Fixes applied. Restart Antigravity."
        wait_key
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  5. Usage & Rate Limits
# ═══════════════════════════════════════════════════════════════════════════════
menu_usage() {
    draw_header

    # Counts
    local conv_n; conv_n=$(count_items "$AG_DIR/conversations" "-mindepth 1 -maxdepth 1 -type d")
    local brain_n; brain_n=$(count_items "$AG_DIR/brain" "-type f")
    local rec_n; rec_n=$(count_items "$AG_DIR/browser_recordings" "-mindepth 1 -maxdepth 1 -type d")
    local ctx_n; ctx_n=$(count_items "$AG_DIR/context_state" "-type f")
    local code_n; code_n=$(count_items "$AG_DIR/code_tracker" "-type f")
    local anno_n; anno_n=$(count_items "$AG_DIR/annotations" "-type f")
    local know_n; know_n=$(count_items "$AG_DIR/knowledge" "-type f")

    # Sizes
    local conv_b; conv_b=$(get_size_bytes "$AG_DIR/conversations")
    local brain_b; brain_b=$(get_size_bytes "$AG_DIR/brain")
    local rec_b; rec_b=$(get_size_bytes "$AG_DIR/browser_recordings")
    local prof_b; prof_b=$(get_size_bytes "$BP_DIR")
    local total_b=$(( conv_b + brain_b + rec_b + prof_b ))

    box_top; box_title "Usage Dashboard"; box_empty
    box_line "  ${WHITE}Conversations${RST}            ${WHITE}${BOLD}${conv_n}${RST} sessions"
    box_line "  ${WHITE}Brain Artifacts${RST}          ${WHITE}${BOLD}${brain_n}${RST} files"
    box_line "  ${WHITE}Browser Recordings${RST}       ${WHITE}${BOLD}${rec_n}${RST} sessions"
    box_line "  ${WHITE}Context Snapshots${RST}        ${WHITE}${BOLD}${ctx_n}${RST} files"
    box_line "  ${WHITE}Code Tracker${RST}             ${WHITE}${BOLD}${code_n}${RST} files"
    box_line "  ${WHITE}Annotations${RST}              ${WHITE}${BOLD}${anno_n}${RST} files"
    box_line "  ${WHITE}Knowledge${RST}                ${WHITE}${BOLD}${know_n}${RST} files"
    box_sep
    local tb; tb=$(fmt_bytes "$total_b")
    box_line "  ${WHITE}${BOLD}Total${RST}                    ${tb}"
    box_bot

    # Activity
    local now; now=$(date +%s)
    local today_n=0 week_n=0 month_n=0
    if [ -d "$AG_DIR/conversations" ]; then
        for d in "$AG_DIR/conversations"/*/; do
            [ -d "$d" ] || continue
            local mt; mt=$(file_mtime "$d"); local age=$(( now - mt ))
            (( age < 86400   )) && (( today_n++ ))
            (( age < 604800  )) && (( week_n++ ))
            (( age < 2592000 )) && (( month_n++ ))
        done
    fi

    printf "\n"
    box_top; box_title "Activity"; box_empty
    box_line "  ${CYAN}Today${RST}          ${WHITE}${BOLD}${today_n}${RST} sessions"
    box_line "  ${CYAN}This week${RST}      ${WHITE}${BOLD}${week_n}${RST} sessions"
    box_line "  ${CYAN}This month${RST}     ${WHITE}${BOLD}${month_n}${RST} sessions"
    box_bot

    # ── Rate Limit / Reset Timer ─────────────────────────────────────────
    local year; year=$(date +%Y)
    local month; month=$(date +%m)
    local day; day=$(date +%d); day=${day#0}
    local month_name; month_name=$(date +%B)
    local dim
    if [[ "$OSTYPE" == darwin* ]]; then
        dim=$(date -v1d -v+1m -v-1d +%d 2>/dev/null || echo 30)
    else
        dim=$(date -d "${year}-${month}-01 +1 month -1 day" +%d 2>/dev/null || echo 30)
    fi
    dim=${dim#0}
    local remaining=$(( dim - day ))
    local next_month
    if [[ "$OSTYPE" == darwin* ]]; then
        next_month=$(date -v+1m "+%B %Y" 2>/dev/null || echo "Next Month")
    else
        next_month=$(date -d "+1 month" "+%B %Y" 2>/dev/null || echo "Next Month")
    fi

    printf "\n"
    box_top; box_title "Rate Limit Reset Timer"; box_empty
    box_line "  ${WHITE}Current Cycle${RST}       ${WHITE}${BOLD}${month_name} ${year}${RST}"
    box_line "  ${WHITE}Resets On${RST}           ${WHITE}${BOLD}${next_month} 1${RST}"
    box_line "  ${WHITE}Days Remaining${RST}      ${WHITE}${BOLD}${remaining}${RST} days"
    box_empty
    local pbar; pbar=$(progress_bar "$day" "$dim" 32)
    box_line "  ${pbar}"
    box_empty

    if (( day > 0 && month_n > 0 )); then
        local rate; rate=$(calc "$month_n / $day")
        local proj; proj=$(calc "$rate * $dim / 1"); proj=${proj%%.*}
        box_sep; box_empty
        box_line "  ${CYAN}Avg sessions/day${RST}    ${WHITE}${BOLD}${rate}${RST}"
        box_line "  ${CYAN}Projected monthly${RST}   ${WHITE}${BOLD}${proj:-0}${RST}"
        box_empty
    fi

    box_line "  ${DGRAY}Free tier resets on the 1st of each month.${RST}"
    box_line "  ${DGRAY}If rate-limited, reduce usage or wait for reset.${RST}"
    box_empty; box_bot

    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  6. Account Switcher
# ═══════════════════════════════════════════════════════════════════════════════
get_active() { [ -f "$ACTIVE_FILE" ] && cat "$ACTIVE_FILE" 2>/dev/null | tr -d '\n' || echo "default"; }

menu_accounts() {
    while true; do
        draw_header
        local active; active=$(get_active)
        mkdir -p "$PROFILES_DIR" 2>/dev/null

        box_top; box_title "Account Switcher"; box_empty
        box_line "  ${GREEN}●${RST}  Active: ${WHITE}${BOLD}${active}${RST}"
        box_empty

        local profiles=() idx=1
        for pdir in "$PROFILES_DIR"/*/; do
            [ -d "$pdir" ] || continue
            local pname; pname=$(basename "$pdir"); profiles+=("$pname")
            local mark=""; [[ "$pname" == "$active" ]] && mark=" ${GREEN}★${RST}"
            local psz; psz=$(get_size "$pdir")
            box_line "  ${CYAN}[${WHITE}${idx}${CYAN}]${RST}  $(printf '%-20s' "$pname") ${DGRAY}${psz}${RST}${mark}"
            (( idx++ ))
        done
        (( ${#profiles[@]} == 0 )) && box_line "  ${DGRAY}No saved profiles yet.${RST}"

        box_empty; box_sep; box_empty
        box_line "  ${CYAN}[${WHITE}s${CYAN}]${RST}  Save current as new profile"
        box_line "  ${CYAN}[${RED}d${CYAN}]${RST}  ${RED}Delete a profile${RST}"
        box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back${RST}"
        box_empty; box_bot

        printf "\n  ${CYAN}›${RST} "; local ch; ch=$(read_key)
        [[ -z "$ch" ]] && continue; printf "\n"

        case "$ch" in
            s|S)
                printf "  Profile name: "; local pn; pn=$(read_key)
                pn=$(echo "$pn" | tr -cd 'a-zA-Z0-9_-')
                [ -z "$pn" ] && { err_ "Invalid name."; wait_key; continue; }
                [ -d "$PROFILES_DIR/$pn" ] && {
                    printf "  Overwrite '$pn'? [y/N] "; local yn; yn=$(read_key)
                    [[ "$yn" =~ ^[Yy]$ ]] || { warn_ "Cancelled."; wait_key; continue; }
                    rm -rf "${PROFILES_DIR:?}/$pn"
                }
                info_ "Saving as '${pn}'…"
                mkdir -p "$PROFILES_DIR/$pn"
                [ -d "$GEMINI_DIR" ] && cp -a "$GEMINI_DIR/." "$PROFILES_DIR/$pn/" 2>/dev/null
                echo "$pn" > "$ACTIVE_FILE"
                ok_ "Saved."; wait_key;;
            d|D)
                (( ${#profiles[@]} == 0 )) && { warn_ "Nothing to delete."; wait_key; continue; }
                printf "  Number to delete: "; local dn; dn=$(read_key)
                if [[ "$dn" =~ ^[0-9]+$ ]] && (( dn>=1 && dn<=${#profiles[@]} )); then
                    local tgt="${profiles[$((dn-1))]}"
                    [[ "$tgt" == "$active" ]] && { err_ "Can't delete active profile."; wait_key; continue; }
                    rm -rf "${PROFILES_DIR:?}/$tgt"; ok_ "Deleted '${tgt}'."
                else err_ "Invalid."; fi; wait_key;;
            b|B) return;;
            [0-9]*)
                (( ch>=1 && ch<=${#profiles[@]} )) || { err_ "Invalid."; wait_key; continue; }
                local tgt="${profiles[$((ch-1))]}"
                [[ "$tgt" == "$active" ]] && { info_ "Already active."; wait_key; continue; }
                warn_ "Close Antigravity before switching."
                printf "  Switch to '${tgt}'? [y/N] "; local yn; yn=$(read_key)
                [[ "$yn" =~ ^[Yy]$ ]] || { warn_ "Cancelled."; wait_key; continue; }
                printf "\n"; info_ "Saving '${active}'…"
                rm -rf "${PROFILES_DIR:?}/$active" 2>/dev/null
                [ -d "$GEMINI_DIR" ] && mv "$GEMINI_DIR" "$PROFILES_DIR/$active"
                info_ "Restoring '${tgt}'…"
                mv "$PROFILES_DIR/$tgt" "$GEMINI_DIR"
                echo "$tgt" > "$ACTIVE_FILE"
                AG_DIR="$GEMINI_DIR/antigravity"; BP_DIR="$GEMINI_DIR/antigravity-browser-profile"
                BP_DEF="$BP_DIR/Default"; BACKUP_DIR="$GEMINI_DIR/backups"
                ok_ "Switched to '${tgt}'."; wait_key;;
            *) continue;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  7. Browser Backup
# ═══════════════════════════════════════════════════════════════════════════════
menu_backup() {
    draw_header
    mkdir -p "$BACKUP_DIR" 2>/dev/null

    declare -A browsers
    if [[ "$OSTYPE" == darwin* ]]; then
        local as="$HOME/Library/Application Support"
        [ -d "$as/Google/Chrome" ]              && browsers[chrome]="$as/Google/Chrome"
        [ -d "$as/Chromium" ]                   && browsers[chromium]="$as/Chromium"
        [ -d "$as/BraveSoftware/Brave-Browser" ] && browsers[brave]="$as/BraveSoftware/Brave-Browser"
        [ -d "$as/Microsoft Edge" ]             && browsers[edge]="$as/Microsoft Edge"
        [ -d "$as/com.operasoftware.Opera" ]    && browsers[opera]="$as/com.operasoftware.Opera"
        [ -d "$as/Firefox/Profiles" ]           && browsers[firefox]="$as/Firefox/Profiles"
        [ -d "$as/Arc" ]                        && browsers[arc]="$as/Arc"
        [ -d "$as/Vivaldi" ]                    && browsers[vivaldi]="$as/Vivaldi"
    else
        [ -d "$HOME/.config/google-chrome" ]               && browsers[chrome]="$HOME/.config/google-chrome"
        [ -d "$HOME/.config/chromium" ]                    && browsers[chromium]="$HOME/.config/chromium"
        [ -d "$HOME/.config/BraveSoftware/Brave-Browser" ] && browsers[brave]="$HOME/.config/BraveSoftware/Brave-Browser"
        [ -d "$HOME/.config/microsoft-edge" ]              && browsers[edge]="$HOME/.config/microsoft-edge"
        [ -d "$HOME/.config/opera" ]                       && browsers[opera]="$HOME/.config/opera"
        [ -d "$HOME/.mozilla/firefox" ]                    && browsers[firefox]="$HOME/.mozilla/firefox"
        [ -d "$HOME/.config/vivaldi" ]                     && browsers[vivaldi]="$HOME/.config/vivaldi"
    fi
    [ -d "$BP_DIR" ] && browsers[antigravity]="$BP_DIR"

    box_top; box_title "Browser Backup"; box_empty
    if (( ${#browsers[@]} == 0 )); then
        box_line "  ${YELLOW}No browsers detected.${RST}"; box_empty; box_bot; wait_key; return
    fi
    local keys=("${!browsers[@]}") idx=1
    for n in "${keys[@]}"; do
        local sz; sz=$(get_size "${browsers[$n]}")
        box_line "  ${CYAN}[${WHITE}${idx}${CYAN}]${RST}  $(printf '%-22s' "$n") ${DGRAY}${sz}${RST}"
        (( idx++ ))
    done
    box_empty; box_line "  ${CYAN}[${WHITE}a${CYAN}]${RST}  Backup ALL"
    box_line "  ${CYAN}[${DGRAY}b${CYAN}]${RST}  ${DGRAY}Back${RST}"; box_empty; box_bot

    printf "\n  ${CYAN}›${RST} "; local ch; ch=$(read_key)
    [[ -z "$ch" ]] && return; printf "\n"

    _bak() {
        local n="$1" p="$2" ts; ts=$(date +%Y%m%d_%H%M%S)
        local out="$BACKUP_DIR/${n}_backup_${ts}.tar.gz"
        printf "  ${DGRAY}…${RST}  Backing up %s" "$n"
        tar -czf "$out" -C "$(dirname "$p")" "$(basename "$p")" \
            --exclude="Cache" --exclude="Code Cache" --exclude="GPUCache" \
            --exclude="Service Worker" 2>/dev/null || true
        printf "\r  ${GREEN}✓${RST}  %s ${DGRAY}→${RST} %s\n" "$n" "$(basename "$out")"
    }

    case "$ch" in
        a|A) for n in "${keys[@]}"; do _bak "$n" "${browsers[$n]}"; done
             ok_ "Saved to $BACKUP_DIR"; wait_key;;
        b|B) return;;
        [0-9]*) (( ch>=1 && ch<=${#keys[@]} )) && _bak "${keys[$((ch-1))]}" "${browsers[${keys[$((ch-1))]}]}" && ok_ "Saved."
                wait_key;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
#  8. Fix Everything (one-click)
# ═══════════════════════════════════════════════════════════════════════════════
menu_fix_all() {
    draw_header
    box_top; box_title "Fix Everything"; box_empty
    box_line "  This will apply ALL fixes in one go:"
    box_line "  ${DGRAY}•${RST} Flush DNS"
    box_line "  ${DGRAY}•${RST} Clean all Antigravity caches"
    box_line "  ${DGRAY}•${RST} Clean browser cache/cookies/storage"
    box_line "  ${DGRAY}•${RST} Fix browser lock files"
    box_line "  ${DGRAY}•${RST} Clean shader caches"
    box_line "  ${DGRAY}•${RST} Test connectivity"
    box_empty; box_bot

    printf "\n  Run? [y/N] "; local yn; yn=$(read_key)
    [[ "$yn" =~ ^[Yy]$ ]] || { warn_ "Cancelled."; wait_key; return; }

    printf "\n"
    info_ "Step 1/6: Flushing DNS…"
    flush_dns && ok_ "DNS flushed" || warn_ "DNS flush skipped"

    info_ "Step 2/6: Cleaning Antigravity caches…"
    for d in brain conversations browser_recordings context_state code_tracker implicit annotations knowledge playground scratch; do
        clean_dir "$AG_DIR/$d" "$d"
    done

    info_ "Step 3/6: Cleaning browser cache…"
    for d in Cache "Code Cache" GPUCache DawnGraphiteCache DawnWebGPUCache "Service Worker" blob_storage Sessions; do
        clean_dir "$BP_DEF/$d" "$d"
    done
    for d in ShaderCache GrShaderCache GraphiteDawnCache; do
        clean_dir "$BP_DIR/$d" "$d"
    done

    info_ "Step 4/6: Cleaning cookies & storage…"
    for f in Cookies Cookies-journal "Safe Browsing Cookies" "Safe Browsing Cookies-journal"; do
        clean_file "$BP_DEF/$f" "$f"
    done
    for d in "Local Storage" "Session Storage" WebStorage; do
        clean_dir "$BP_DEF/$d" "$d"
    done

    info_ "Step 5/6: Fixing lock files…"
    clean_file "$BP_DEF/SingletonLock" "SingletonLock"
    clean_file "$BP_DEF/LOCK" "LOCK"
    clean_file "$BP_DIR/BrowserMetrics-spare.pma" "BrowserMetrics"

    info_ "Step 6/6: Testing connectivity…"
    test_url "https://www.google.com" "NET"
    test_url "https://gemini.google.com" "GEM"

    printf "\n"
    box_top; box_empty
    box_line "  ${GREEN}${BOLD}All fixes applied!${RST}"
    box_line "  ${DGRAY}Restart Antigravity to apply changes.${RST}"
    box_empty; box_bot
    wait_key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Quick mode
# ═══════════════════════════════════════════════════════════════════════════════
run_quick() {
    printf "\n  ${CYAN}${BOLD}Quick Clean${RST}\n\n"
    $FLAG_DRY_RUN && { warn_ "DRY RUN"; printf "\n"; }
    for d in brain conversations browser_recordings context_state code_tracker implicit annotations knowledge playground scratch; do
        clean_dir "$AG_DIR/$d" "$d"
    done
    printf "\n"; $FLAG_DRY_RUN || ok_ "Done."; printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Main Menu
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        draw_header
        box_top; box_title "Main Menu"; box_empty
        box_line "  ${CYAN}[${WHITE}1${CYAN}]${RST}  ${WHITE}Cache Cleaner${RST}          ${DGRAY}Clean Antigravity caches${RST}"
        box_line "  ${CYAN}[${WHITE}2${CYAN}]${RST}  ${WHITE}Browser Toolkit${RST}        ${DGRAY}Fix AG's built-in browser${RST}"
        box_line "  ${CYAN}[${WHITE}3${CYAN}]${RST}  ${WHITE}Network Fixer${RST}          ${DGRAY}DNS, connectivity, 403${RST}"
        box_line "  ${CYAN}[${WHITE}4${CYAN}]${RST}  ${WHITE}Troubleshooter${RST}         ${DGRAY}Diagnose & auto-fix${RST}"
        box_line "  ${CYAN}[${WHITE}5${CYAN}]${RST}  ${WHITE}Usage & Rate Limits${RST}    ${DGRAY}Stats + reset timer${RST}"
        box_line "  ${CYAN}[${WHITE}6${CYAN}]${RST}  ${WHITE}Account Switcher${RST}       ${DGRAY}Manage profiles${RST}"
        box_line "  ${CYAN}[${WHITE}7${CYAN}]${RST}  ${WHITE}Browser Backup${RST}         ${DGRAY}Backup system browsers${RST}"
        box_empty
        box_line "  ${BG_SEL}${CYAN}[${WHITE}${BOLD}8${CYAN}]${RST}${BG_SEL}  ${LGREEN}${BOLD}Fix Everything${RST}${BG_SEL}         ${LGREEN}One-click comprehensive fix${RST}"
        box_empty
        box_line "  ${CYAN}[${DGRAY}0${CYAN}]${RST}  ${DGRAY}Exit${RST}"
        box_empty; box_bot

        printf "\n  ${CYAN}›${RST} "; local choice; choice=$(read_key)
        [[ -z "$choice" ]] && continue

        case "$choice" in
            1) menu_cleaner;; 2) menu_browser;; 3) menu_network;;
            4) menu_troubleshoot;; 5) menu_usage;; 6) menu_accounts;;
            7) menu_backup;; 8) menu_fix_all;;
            0|q|Q) show_cursor; printf "\n  ${CYAN}Goodbye!${RST}\n\n"; exit 0;;
            *) continue;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  CLI args
# ═══════════════════════════════════════════════════════════════════════════════
while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quick)   FLAG_QUICK=true; shift;;
        -d|--dry-run) FLAG_DRY_RUN=true; shift;;
        -h|--help) cat <<'H'
Antigravity Toolkit v3.1

Usage:  antigravity-cleaner.sh [OPTIONS]

  -q, --quick      Clean all cache non-interactively
  -d, --dry-run    Preview deletions (pair with -q)
  -h, --help       Show this help

One-liner:
  curl -sL https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.sh | bash
H
        exit 0;; *) printf "Unknown: %s\n" "$1"; exit 1;; esac
done

# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -d "$GEMINI_DIR" ]; then
    printf "\n  ${RED}Antigravity not found at %s${RST}\n  ${DGRAY}Is it installed?${RST}\n\n" "$GEMINI_DIR"; exit 1
fi
$FLAG_QUICK && { run_quick; exit 0; }
main_menu
