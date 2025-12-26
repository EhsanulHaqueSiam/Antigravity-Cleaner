#!/bin/bash

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Repo Info (Placeholder)
REPO="EhsanulHaqueSiam/Antigravity-Cleaner"
VERSION="latest"

echo -e "\n${CYAN}🚀 Antigravity Cleaner Installer${NC}"
echo -e "${CYAN}==============================${NC}\n"

# Detect OS
OS="$(uname)"
if [ "$OS" == "Darwin" ]; then
    FILE_EXT="dmg"
    PLATFORM="mac"
    echo -e "  Detected OS: ${GREEN}macOS${NC}"
elif [ "$OS" == "Linux" ]; then
    FILE_EXT="AppImage"
    PLATFORM="linux"
    echo -e "  Detected OS: ${GREEN}Linux${NC}"
else
    echo -e "  ${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

echo -e "  Fetch version: ${GREEN}${VERSION}${NC}"

# Determine filename
FILENAME="cleanup_antigravity_cache.sh"
# Pointing to the RAW file in the repo (assuming main branch)
DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/main/scripts/${FILENAME}"

echo -e "  Downloading script from: ${CYAN}${DOWNLOAD_URL}${NC}"

# Download
if command -v curl >/dev/null 2>&1; then
    curl -sL -o "$FILENAME" "$DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$FILENAME" "$DOWNLOAD_URL"
else
    echo -e "  ${RED}Error: Neither curl nor wget found.${NC}"
    exit 1
fi

chmod +x "$FILENAME"

echo -e "\n${GREEN}✔ Download successful! Launching...${NC}\n"
# Run immediately
./"$FILENAME" < /dev/tty

# Cleanup (Optional: remove script after run? User typically wants to keep it or run via one-liner)
# rm "$FILENAME"

