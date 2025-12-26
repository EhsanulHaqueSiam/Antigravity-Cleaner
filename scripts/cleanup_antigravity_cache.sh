#!/bin/bash

# =============================================================================
# 🚀 Antigravity Cache Cleanup Script - Beautiful TUI Edition
# =============================================================================

set -e

# Directory paths
GEMINI_DIR="$HOME/.gemini"
ANTIGRAVITY_DIR="$GEMINI_DIR/antigravity"
ANTIGRAVITY_DIR="$GEMINI_DIR/antigravity"
BROWSER_PROFILE_DIR="$GEMINI_DIR/antigravity-browser-profile"
BACKUP_DIR="$GEMINI_DIR/backups"

# ═══════════════════════════════════════════════════════════════════════════
# Color Palette - Cyberpunk Theme 🎨
# ═══════════════════════════════════════════════════════════════════════════

# Reset
RST='\033[0m'

# Regular Colors
BLACK='\033[0;30m'
WHITE='\033[1;37m'

# Gradient Colors (256 color mode)
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;201m'
PINK='\033[38;5;213m'
PURPLE='\033[38;5;141m'
BLUE='\033[38;5;39m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
ORANGE='\033[38;5;208m'
RED='\033[38;5;196m'
GRAY='\033[38;5;244m'
DARK_GRAY='\033[38;5;238m'

# Background Colors
BG_DARK='\033[48;5;234m'
BG_SELECTED='\033[48;5;236m'

# Text Styles
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'

# Box Drawing Characters
BOX_TL="╭"
BOX_TR="╮"
BOX_BL="╰"
BOX_BR="╯"
BOX_H="─"
BOX_V="│"
BOX_LT="├"
BOX_RT="┤"
BOX_TT="┬"
BOX_BT="┴"
BOX_X="┼"

# Icons
ICON_ROCKET="🚀"
ICON_BRAIN="🧠"
ICON_TRASH="🗑️ "
ICON_FOLDER="📁"
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="➜"
ICON_STAR="★"
ICON_SPARKLE="✨"
ICON_WARN="⚠️ "
ICON_INFO="ℹ️ "
ICON_CLEAN="🧹"
ICON_FIRE="🔥"

# Terminal width
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
if [ "$TERM_WIDTH" -gt 80 ]; then
    TERM_WIDTH=80
fi

# ═══════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

# Hide cursor
hide_cursor() { printf '\033[?25l'; }

# Show cursor
show_cursor() { printf '\033[?25h'; }

# Cleanup on exit
cleanup() {
    show_cursor
    printf "${RST}"
}
trap cleanup EXIT

# Center text
center_text() {
    local text="$1"
    local width="$2"
    local text_len=${#text}
    local padding=$(( (width - text_len) / 2 ))
    printf "%*s%s%*s" $padding "" "$text" $((width - text_len - padding)) ""
}

# Draw horizontal line
draw_line() {
    local char="${1:-$BOX_H}"
    local width="${2:-$TERM_WIDTH}"
    local color="${3:-$DARK_GRAY}"
    printf "${color}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${RST}\n"
}

# Draw box top
draw_box_top() {
    local width="${1:-$TERM_WIDTH}"
    local color="${2:-$CYAN}"
    printf "${color}${BOX_TL}"
    printf '%*s' "$((width-2))" '' | tr ' ' "$BOX_H"
    printf "${BOX_TR}${RST}\n"
}

# Draw box bottom
draw_box_bottom() {
    local width="${1:-$TERM_WIDTH}"
    local color="${2:-$CYAN}"
    printf "${color}${BOX_BL}"
    printf '%*s' "$((width-2))" '' | tr ' ' "$BOX_H"
    printf "${BOX_BR}${RST}\n"
}

# Draw box line with text
draw_box_line() {
    local text="$1"
    local width="${2:-$TERM_WIDTH}"
    local color="${3:-$CYAN}"
    local text_color="${4:-$WHITE}"
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    local inner_width=$((width - 4))
    
    printf "${color}${BOX_V} ${text_color}${text}"
    printf '%*s' "$((inner_width - text_len))" ''
    printf " ${color}${BOX_V}${RST}\n"
}

# Draw empty box line
draw_box_empty() {
    local width="${1:-$TERM_WIDTH}"
    local color="${2:-$CYAN}"
    printf "${color}${BOX_V}"
    printf '%*s' "$((width-2))" ''
    printf "${BOX_V}${RST}\n"
}

# Animated spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " ${CYAN}[${MAGENTA}%c${CYAN}]${RST}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "     \b\b\b\b\b"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "${CYAN}["
    printf "${GREEN}"
    printf '%*s' "$filled" '' | tr ' ' '█'
    printf "${DARK_GRAY}"
    printf '%*s' "$empty" '' | tr ' ' '░'
    printf "${CYAN}] ${WHITE}%3d%%${RST}" "$percentage"
}

# Animated progress
animated_progress() {
    local duration=${1:-2}
    local steps=20
    local delay=$(echo "scale=3; $duration / $steps" | bc 2>/dev/null || echo "0.1")
    
    for ((i=1; i<=steps; i++)); do
        printf "\r  "
        progress_bar $i $steps
        sleep "$delay" 2>/dev/null || sleep 0.1
    done
    printf "\n"
}

# Get directory size with color
get_size() {
    if [ -d "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Get size in bytes for comparison
get_size_bytes() {
    if [ -d "$1" ]; then
        du -sb "$1" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Format size with color based on magnitude
format_size() {
    local size="$1"
    local num=$(echo "$size" | tr -d 'A-Za-z')
    local unit=$(echo "$size" | tr -d '0-9.')
    
    case "$unit" in
        G*) printf "${RED}${BOLD}%s${RST}" "$size" ;;
        M*) printf "${ORANGE}%s${RST}" "$size" ;;
        K*) printf "${YELLOW}%s${RST}" "$size" ;;
        *)  printf "${GREEN}%s${RST}" "$size" ;;
    esac
}

# Print status messages
print_info() {
    printf "  ${BLUE}${ICON_INFO}${RST} ${WHITE}%s${RST}\n" "$1"
}

print_success() {
    printf "  ${GREEN}${ICON_CHECK}${RST} ${GREEN}%s${RST}\n" "$1"
}

print_warning() {
    printf "  ${YELLOW}${ICON_WARN}${RST}${YELLOW}%s${RST}\n" "$1"
}

print_error() {
    printf "  ${RED}${ICON_CROSS}${RST} ${RED}%s${RST}\n" "$1"
}

# ═══════════════════════════════════════════════════════════════════════════
# New Features: Network & Backup
# ═══════════════════════════════════════════════════════════════════════════

network_optimizer() {
    print_info "Running Network Diagnostics..."
    
    # 1. DNS Flush
    printf "  ${CYAN}[DNS]${RST} Flushing DNS Cache... "
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo killall -HUP mDNSResponder 2>/dev/null
    else
        resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || nscd -i hosts 2>/dev/null
    fi
    printf "${GREEN}Done${RST}\n"
    
    # 2. Connectivity Check
    printf "  ${CYAN}[NET]${RST} Testing Google Connectivity... "
    if curl -s --head --request GET https://www.google.com | grep "200 OK" > /dev/null; then
        printf "${GREEN}Online${RST}\n"
    else
        printf "${RED}Unreachable${RST}\n"
    fi
    
    printf "  ${CYAN}[NET]${RST} Testing Gemini AI... "
    if curl -s --head --request GET https://gemini.google.com | grep "200 OK" > /dev/null; then
        printf "${GREEN}Online${RST}\n"
    else
        printf "${RED}Unreachable (Check Region/VPN)${RST}\n"
    fi
    
    wait_key
}

session_safeguard() {
    mkdir -p "$BACKUP_DIR"
    print_info "Scanning for browsers to backup..."
    
    local browsers=("google-chrome" "chromium" "brave-browser" "microsoft-edge" "opera")
    local found=0
    
    for browser in "${browsers[@]}"; do
        local config_dir="$HOME/.config/$browser"
        # Mac Paths
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [[ "$browser" == "google-chrome" ]]; then config_dir="$HOME/Library/Application Support/Google/Chrome"; fi
        fi
        
        if [ -d "$config_dir" ]; then
            found=1
            local backup_file="$BACKUP_DIR/${browser}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            printf "  ${CYAN}[BCK]${RST} Backing up ${WHITE}$browser${RST}..."
            
            # Tar exclusion to avoid huge cache files
            tar -czf "$backup_file" -C "$(dirname "$config_dir")" "$(basename "$config_dir")" --exclude="Cache" --exclude="Code Cache" 2>/dev/null
            
            printf "\r  ${GREEN}[BCK]${RST} Saved to ${WHITE}$(basename "$backup_file")${RST}      \n"
        fi
    done
    
    if [ $found -eq 0 ]; then
        print_warning "No standard browsers detected."
    else
        print_success "Backups saved to $BACKUP_DIR"
    fi
    
    wait_key
}

wait_key() {
    printf "\n  ${GRAY}Press Enter to continue...${RST}"
    read -r
}

# Clean directory with animation
clean_dir() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
        local size=$(get_size "$dir")
        printf "  ${CYAN}${ICON_CLEAN}${RST} ${DIM}Cleaning ${description}...${RST}"
        rm -rf "$dir"/* 2>/dev/null
        sleep 0.3
        printf "\r  ${GREEN}${ICON_CHECK}${RST} ${WHITE}${description}${RST} ${GRAY}─${RST} "
        format_size "$size"
        printf " ${GREEN}freed${RST}\n"
        return 0
    else
        printf "  ${GRAY}${ICON_FOLDER}${RST} ${DIM}${description} is empty${RST}\n"
        return 1
    fi
}


# ═══════════════════════════════════════════════════════════════════════════
# UI Components
# ═══════════════════════════════════════════════════════════════════════════

# Draw the header banner
draw_header() {
    clear
    hide_cursor
    printf "\n"
    
    # Gradient ASCII Art
    printf "${MAGENTA}"
    printf "     █████╗ ███╗   ██╗████████╗██╗ ██████╗ ██████╗  █████╗ ██╗   ██╗██╗████████╗██╗   ██╗\n"
    printf "${PINK}"
    printf "    ██╔══██╗████╗  ██║╚══██╔══╝██║██╔════╝ ██╔══██╗██╔══██╗██║   ██║██║╚══██╔══╝╚██╗ ██╔╝\n"
    printf "${PURPLE}"
    printf "    ███████║██╔██╗ ██║   ██║   ██║██║  ███╗██████╔╝███████║██║   ██║██║   ██║    ╚████╔╝ \n"
    printf "${BLUE}"
    printf "    ██╔══██║██║╚██╗██║   ██║   ██║██║   ██║██╔══██╗██╔══██║╚██╗ ██╔╝██║   ██║     ╚██╔╝  \n"
    printf "${CYAN}"
    printf "    ██║  ██║██║ ╚████║   ██║   ██║╚██████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║   ██║      ██║   \n"
    printf "    ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝   ╚═╝      ╚═╝   \n"
    printf "${RST}\n"
    
    # Subtitle
    printf "${GRAY}                          "
    printf "${ICON_CLEAN} ${WHITE}${BOLD}Cache Cleanup Utility${RST} ${GRAY}v2.0${RST}\n"
    printf "\n"
    draw_line "═" 80 "$DARK_GRAY"
    printf "\n"
}

# Draw cache status table
draw_cache_status() {
    printf "${WHITE}${BOLD}  ${ICON_FOLDER} Cache Status${RST}\n\n"
    
    # Table header
    printf "  ${CYAN}${BOX_TL}"
    printf '%*s' "44" '' | tr ' ' "$BOX_H"
    printf "${BOX_TT}"
    printf '%*s' "12" '' | tr ' ' "$BOX_H"
    printf "${BOX_TR}${RST}\n"
    
    printf "  ${CYAN}${BOX_V}${RST} ${WHITE}${BOLD}%-42s${RST} ${CYAN}${BOX_V}${RST} ${WHITE}${BOLD}%10s${RST} ${CYAN}${BOX_V}${RST}\n" "Directory" "Size"
    
    printf "  ${CYAN}${BOX_LT}"
    printf '%*s' "44" '' | tr ' ' "$BOX_H"
    printf "${BOX_X}"
    printf '%*s' "12" '' | tr ' ' "$BOX_H"
    printf "${BOX_RT}${RST}\n"
    
    # Cache entries
    local total_bytes=0
    local entries=(
        "$ANTIGRAVITY_DIR/brain|🧠 Brain (artifacts/plans)"
        "$ANTIGRAVITY_DIR/browser_recordings|🎬 Browser Recordings"
        "$ANTIGRAVITY_DIR/conversations|💬 Conversations"
        "$ANTIGRAVITY_DIR/context_state|📊 Context State"
        "$ANTIGRAVITY_DIR/code_tracker|🔍 Code Tracker"
        "$ANTIGRAVITY_DIR/implicit|💭 Implicit Memory"
        "$BROWSER_PROFILE_DIR|🌐 Browser Profile"
    )
    
    for entry in "${entries[@]}"; do
        local dir="${entry%%|*}"
        local name="${entry##*|}"
        
        if [ -d "$dir" ]; then
            local size=$(get_size "$dir")
            local size_bytes=$(get_size_bytes "$dir")
            total_bytes=$((total_bytes + size_bytes))
            
            printf "  ${CYAN}${BOX_V}${RST}  %-43s ${CYAN}${BOX_V}${RST} " "$name"
            printf "%10s" ""
            printf "\b\b\b\b\b\b\b\b\b\b"
            format_size "$size"
            local size_clean=$(echo "$size" | wc -c)
            printf '%*s' "$((10 - ${#size}))" ''
            printf " ${CYAN}${BOX_V}${RST}\n"
        fi
    done
    
    # Table footer with total
    printf "  ${CYAN}${BOX_LT}"
    printf '%*s' "44" '' | tr ' ' "$BOX_H"
    printf "${BOX_X}"
    printf '%*s' "12" '' | tr ' ' "$BOX_H"
    printf "${BOX_RT}${RST}\n"
    
    local total_size=$(get_size "$GEMINI_DIR")
    printf "  ${CYAN}${BOX_V}${RST} ${WHITE}${BOLD}%-42s${RST} ${CYAN}${BOX_V}${RST} ${WHITE}${BOLD}%10s${RST} ${CYAN}${BOX_V}${RST}\n" "TOTAL" "$total_size"
    
    printf "  ${CYAN}${BOX_BL}"
    printf '%*s' "44" '' | tr ' ' "$BOX_H"
    printf "${BOX_BT}"
    printf '%*s' "12" '' | tr ' ' "$BOX_H"
    printf "${BOX_BR}${RST}\n"
    
    printf "\n"
}

# Draw menu
draw_menu() {
    printf "${WHITE}${BOLD}  ${ICON_ARROW} Select Cleanup Option${RST}\n\n"
    
    local options=(
        "1│🎬│Clean browser recordings only"
        "2│💬│Clean conversations history"
        "3│🧠│Clean brain (artifacts/plans)"
        "4│📊│Clean context state"
        "5│🌐│Clean browser profile"
        "6│📦│Clean ALL cache ${GREEN}(recommended)${RST}"
        "7│🔥│Deep clean (removes everything)"
        "8│🔧│Network Optimizer (Fix 403/Connect)"
        "9│💾│Session Safeguard (Backup Browsers)"
        "0│🚪│Exit"
    )
    
    for opt in "${options[@]}"; do
        local num="${opt%%│*}"
        local rest="${opt#*│}"
        local icon="${rest%%│*}"
        local text="${rest#*│}"
        
        if [ "$num" == "6" ]; then
            printf "  ${BG_SELECTED} ${CYAN}[${WHITE}${BOLD}%s${CYAN}]${RST}${BG_SELECTED} %s  %b ${RST}\n" "$num" "$icon" "$text"
        elif [ "$num" == "7" ]; then
            printf "   ${CYAN}[${RED}%s${CYAN}]${RST} %s  ${RED}%s${RST}\n" "$num" "$icon" "$text"
        elif [ "$num" == "0" ]; then
            printf "   ${CYAN}[${GRAY}%s${CYAN}]${RST} %s  ${GRAY}%s${RST}\n" "$num" "$icon" "$text"
        else
            printf "   ${CYAN}[${WHITE}%s${CYAN}]${RST} %s  ${WHITE}%s${RST}\n" "$num" "$icon" "$text"
        fi
    done
    
    printf "\n"
    draw_line "─" 60 "$DARK_GRAY"
    printf "\n"
}

# Draw footer
draw_footer() {
    printf "\n"
    printf "  ${GRAY}Press ${WHITE}[0-7]${GRAY} to select an option${RST}\n"
    printf "\n"
}

# Confirmation dialog
confirm_dialog() {
    local message="$1"
    printf "\n"
    printf "  ${YELLOW}${BOX_TL}"
    printf '%*s' "56" '' | tr ' ' "$BOX_H"
    printf "${BOX_TR}${RST}\n"
    printf "  ${YELLOW}${BOX_V}${RST}  ${ICON_WARN}${YELLOW}${BOLD} WARNING${RST}%46s${YELLOW}${BOX_V}${RST}\n" ""
    printf "  ${YELLOW}${BOX_V}${RST}  %-54s${YELLOW}${BOX_V}${RST}\n" "$message"
    printf "  ${YELLOW}${BOX_V}${RST}  %-54s${YELLOW}${BOX_V}${RST}\n" "This action cannot be undone!"
    printf "  ${YELLOW}${BOX_BL}"
    printf '%*s' "56" '' | tr ' ' "$BOX_H"
    printf "${BOX_BR}${RST}\n"
    printf "\n"
    printf "  ${WHITE}Continue? ${GRAY}[${GREEN}y${GRAY}/${RED}N${GRAY}]${RST} "
    read -r confirm
    [[ $confirm =~ ^[Yy]$ ]]
}

# Success animation
success_animation() {
    printf "\n"
    printf "  ${GREEN}${BOX_TL}"
    printf '%*s' "56" '' | tr ' ' "$BOX_H"
    printf "${BOX_TR}${RST}\n"
    printf "  ${GREEN}${BOX_V}${RST}  ${ICON_SPARKLE} ${GREEN}${BOLD}Cleanup Complete!${RST}%34s${GREEN}${BOX_V}${RST}\n" ""
    printf "  ${GREEN}${BOX_V}${RST}  %-54s${GREEN}${BOX_V}${RST}\n" "Your Antigravity cache has been cleaned."
    printf "  ${GREEN}${BOX_V}${RST}  %-54s${GREEN}${BOX_V}${RST}\n" ""
    printf "  ${GREEN}${BOX_V}${RST}  Remaining cache size: ${WHITE}${BOLD}%-30s${RST}${GREEN}${BOX_V}${RST}\n" "$(get_size "$GEMINI_DIR")"
    printf "  ${GREEN}${BOX_BL}"
    printf '%*s' "56" '' | tr ' ' "$BOX_H"
    printf "${BOX_BR}${RST}\n"
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════
# Main Program
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Check if directory exists
    if [ ! -d "$GEMINI_DIR" ]; then
        draw_header
        print_error "Antigravity cache directory not found at $GEMINI_DIR"
        exit 1
    fi
    
    # Draw UI
    draw_header
    draw_cache_status
    draw_menu
    draw_footer
    
    show_cursor
    printf "  ${CYAN}${ICON_ARROW}${RST} ${WHITE}Enter choice:${RST} "
    read -r choice
    hide_cursor
    
    printf "\n"
    
    case $choice in
        1)
            print_info "Cleaning browser recordings..."
            clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser recordings"
            success_animation
            ;;
        2)
            print_info "Cleaning conversations..."
            clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
            success_animation
            ;;
        3)
            print_info "Cleaning brain artifacts..."
            clean_dir "$ANTIGRAVITY_DIR/brain" "Brain (artifacts/plans)"
            success_animation
            ;;
        4)
            print_info "Cleaning context state..."
            clean_dir "$ANTIGRAVITY_DIR/context_state" "Context state"
            success_animation
            ;;
        5)
            print_info "Cleaning browser profile..."
            clean_dir "$BROWSER_PROFILE_DIR" "Browser profile"
            success_animation
            ;;
        6)
            print_info "Cleaning all cache directories..."
            printf "\n"
            clean_dir "$ANTIGRAVITY_DIR/brain" "Brain (artifacts/plans)"
            clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser recordings"
            clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
            clean_dir "$ANTIGRAVITY_DIR/context_state" "Context state"
            clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code tracker"
            clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit memory"
            success_animation
            ;;
        7)
            if confirm_dialog "Deep clean will remove ALL cached data."; then
                printf "\n"
                print_info "Performing deep clean..."
                printf "\n"
                clean_dir "$ANTIGRAVITY_DIR/brain" "Brain (artifacts/plans)"
                clean_dir "$ANTIGRAVITY_DIR/browser_recordings" "Browser recordings"
                clean_dir "$ANTIGRAVITY_DIR/conversations" "Conversations"
                clean_dir "$ANTIGRAVITY_DIR/context_state" "Context state"
                clean_dir "$ANTIGRAVITY_DIR/code_tracker" "Code tracker"
                clean_dir "$ANTIGRAVITY_DIR/implicit" "Implicit memory"
                clean_dir "$BROWSER_PROFILE_DIR" "Browser profile"
                success_animation
            else
                printf "\n"
                print_warning "Deep clean cancelled."
                printf "\n"
            fi
            ;;
        8)
            network_optimizer
            ;;
        9)
            session_safeguard
            ;;
        0)
            printf "\n"
            printf "  ${CYAN}${ICON_ROCKET}${RST} ${WHITE}Goodbye! Have a great day!${RST} ${ICON_SPARKLE}\n"
            printf "\n"
            exit 0
            ;;
        *)
            print_error "Invalid option. Please select 0-9."
            printf "\n"
            exit 1
            ;;
    esac
    
    show_cursor
}

# Run main
main "$@"
