#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<EOF
Usage: $0 <project_directory> [-v|--volumes] [--no-logs] [--prune]

Options:
  -v, --volumes  Also remove project named and anonymous volumes when stopping it.
  --no-logs      Return after starting the updated containers.
  --prune        Run a global 'docker system prune -af' after the update.
  -h, --help     Show this help.
EOF
}

error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1;36m[%s/%s] %s\033[0m\n' "$1" "$2" "$3"; }
success() { printf '\033[0;32m%s\033[0m\n' "$*"; }

# Use the current user's Docker access when available. If the daemon requires
# elevated privileges, authenticate once and run subsequent Docker commands via sudo.
USE_SUDO=false
docker_cmd() {
  if $USE_SUDO; then sudo docker "$@"; else docker "$@"; fi
}
TARGET_DIR=""
DOWN_ARGS=()
FOLLOW_LOGS=true
PRUNE=false

while (($#)); do
  case "$1" in
    -v|--volumes) DOWN_ARGS+=(--volumes) ;;
    --no-logs) FOLLOW_LOGS=false ;;
    --prune) PRUNE=true ;;
    -h|--help) usage; exit 0 ;;
    --*) error "Unknown option: $1" ;;
    *)
      [[ -z "$TARGET_DIR" ]] || error "Unexpected argument: $1"
      TARGET_DIR="$1"
      ;;
  esac
  shift
done

[[ -n "$TARGET_DIR" ]] || { usage >&2; exit 2; }
[[ -d "$TARGET_DIR" ]] || error "Directory does not exist: $TARGET_DIR"
command -v docker >/dev/null 2>&1 || error "Docker CLI was not found in PATH."
if ! docker info >/dev/null 2>&1; then
  command -v sudo >/dev/null 2>&1 || error "Cannot access the Docker daemon and sudo is unavailable."
  printf 'Docker requires elevated privileges. Authenticate to continue.\n'
  sudo -v || error "Sudo authentication failed."
  USE_SUDO=true
fi
docker_cmd info >/dev/null 2>&1 || error "The Docker daemon is not reachable, even with the current permissions."
cd -- "$TARGET_DIR"

docker_cmd compose version >/dev/null 2>&1 || error "Docker Compose is unavailable."
docker_cmd compose config --quiet || error "Compose configuration is invalid. No containers were changed."

printf '\033[1;35mUpdating Compose project in %s\033[0m\n' "$PWD"

step 1 4 "Pulling images"
docker_cmd compose pull
success "Images pulled."

step 2 4 "Stopping and removing project containers"
docker_cmd compose down "${DOWN_ARGS[@]}"
success "Project stopped."

step 3 4 "Starting updated containers"
docker_cmd compose up -d --remove-orphans
success "Project is running."

if $PRUNE; then
  step 4 4 "Pruning unused Docker resources globally"
  docker_cmd system prune -af
  success "Global prune complete."
else
  step 4 4 "Skipping global Docker prune (use --prune to enable)"
fi

if $FOLLOW_LOGS; then
  printf '\n\033[0;32mFollowing project logs. Press Ctrl+C to stop.\033[0m\n'
  docker_cmd compose logs --follow
fi
