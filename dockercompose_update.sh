#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Colors & Formatting ---
ESC=$(printf '\033')
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
CYAN="${ESC}[36m"
MAGENTA="${ESC}[35m"
# ---------------------------

# Check for the first argument (target directory)
if [ -z "$1" ]; then
  echo -e "${RED}❌ Error: Please specify the directory containing docker-compose.yml.${RESET}"
  echo -e "${YELLOW}💡 Usage: sudo $0 <target_directory> [-v]${RESET}"
  exit 1
fi

TARGET_DIR="$1"
DOWN_OPT="$2" # Second argument (expected to be an option like "-v")

# Check if the directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo -e "${RED}❌ Error: The specified directory does not exist: $TARGET_DIR${RESET}"
  exit 1
fi

# Navigate to the target directory
cd "$TARGET_DIR"

echo -e "${CYAN}${BOLD}✨🌟 Starting Docker Compose Update Process 🌟✨${RESET}"
echo -e "${MAGENTA}📁 Target Directory: $(pwd)${RESET}\n"

# 1. Stop and remove containers
echo -e "${YELLOW}✨ [1/4] 🛑 Stopping and removing containers (down ${DOWN_OPT})...${RESET}"
docker compose down ${DOWN_OPT}
echo -e "${GREEN}✔️ Step 1 Complete!${RESET}\n"

# 2. Pull the latest images
echo -e "${CYAN}✨ [2/4] 🐳 Downloading the latest images (pull)...${RESET}"
docker compose pull
echo -e "${GREEN}✔️ Step 2 Complete!${RESET}\n"

# 3. Rebuild and start containers
echo -e "${GREEN}✨ [3/4] 🚀 Building and starting containers (up -d)...${RESET}"
docker compose up -d
echo -e "${GREEN}✔️ Step 3 Complete!${RESET}\n"

# 4. Clean up unused resources
echo -e "${MAGENTA}✨ [4/4] 🧹 Cleaning up unused system resources (system prune -f)...${RESET}"
docker system prune -f
echo -e "${GREEN}✔️ Step 4 Complete!${RESET}\n"

echo -e "${CYAN}${BOLD}🎉✨ All update processes are complete! Everything is sparkling clean! ✨🎉${RESET}"
