#!/usr/bin/env bash
# Install Claude Code skills into the current project.
#
# Usage:
#   install.sh <stack>...              Install all skills declared in stacks/<stack>.txt
#   install.sh --skill <name>...       Install specific skills by folder name
#   install.sh --list                  Show available stacks and skills
#   install.sh --copy <args>           Copy instead of symlink (default: symlink)
#   install.sh --target <dir> <args>   Use <dir> instead of ./.claude/skills
#   install.sh --remove <name>...      Remove a skill from this project
#   install.sh -h | --help             Show this message
#
# Examples:
#   ~/Documents/IA/skills/install.sh ios
#   ~/Documents/IA/skills/install.sh ios wordpress
#   ~/Documents/IA/skills/install.sh --skill apple-intelligence-app-intents
#   ~/Documents/IA/skills/install.sh --copy ios     # for portable repos

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
STACKS_DIR="$REPO_DIR/stacks"
TARGET="$(pwd)/.claude/skills"
MODE="symlink"
ACTION="install"

show_help() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

list_available() {
  echo "Repo: $REPO_DIR"
  echo
  echo "Available stacks:"
  if [ -d "$STACKS_DIR" ] && compgen -G "$STACKS_DIR/*.txt" > /dev/null; then
    for f in "$STACKS_DIR"/*.txt; do
      name="$(basename "$f" .txt)"
      count="$(grep -cvE '^\s*(#|$)' "$f" || true)"
      echo "  • $name ($count skills)"
    done
  else
    echo "  (none)"
  fi
  echo
  echo "Available skills:"
  if [ -d "$SKILLS_DIR" ]; then
    for d in "$SKILLS_DIR"/*/; do
      [ -d "$d" ] || continue
      echo "  • $(basename "$d")"
    done
  fi
  echo
  echo "Currently linked in $TARGET:"
  if [ -d "$TARGET" ] && [ "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    for d in "$TARGET"/*; do
      [ -e "$d" ] || continue
      if [ -L "$d" ]; then
        echo "  → $(basename "$d")  (symlink → $(readlink "$d"))"
      else
        echo "  → $(basename "$d")  (copy)"
      fi
    done
  else
    echo "  (none)"
  fi
}

install_one() {
  local name="$1"
  local src="$SKILLS_DIR/$name"
  if [ ! -d "$src" ]; then
    echo "✗ skill '$name' not found in $SKILLS_DIR" >&2
    return 1
  fi
  mkdir -p "$TARGET"
  local dest="$TARGET/$name"
  if [ "$MODE" = "copy" ]; then
    rm -rf "$dest"
    cp -R "$src" "$dest"
    echo "✓ $name (copied)"
  else
    ln -sfn "$src" "$dest"
    echo "✓ $name (symlinked)"
  fi
}

remove_one() {
  local name="$1"
  local dest="$TARGET/$name"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "· $name not installed"
    return 0
  fi
  rm -rf "$dest"
  echo "✓ removed $name"
}

install_stack() {
  local stack="$1"
  local file="$STACKS_DIR/$stack.txt"
  if [ ! -f "$file" ]; then
    echo "✗ stack '$stack' not found ($file)" >&2
    return 1
  fi
  echo "→ Installing stack: $stack"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    install_one "$(echo "$line" | xargs)"
  done < "$file"
}

# Parse args
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)   show_help; exit 0 ;;
    --list)      list_available; exit 0 ;;
    --copy)      MODE="copy"; shift ;;
    --target)    TARGET="$2"; shift 2 ;;
    --skill)     ACTION="install-skill"; shift; ARGS=("$@"); break ;;
    --remove)    ACTION="remove"; shift; ARGS=("$@"); break ;;
    *)           ARGS+=("$1"); shift ;;
  esac
done

if [ "${#ARGS[@]}" -eq 0 ]; then
  show_help
  exit 1
fi

case "$ACTION" in
  install)         for s in "${ARGS[@]}"; do install_stack "$s"; done ;;
  install-skill)   for s in "${ARGS[@]}"; do install_one "$s"; done ;;
  remove)          for s in "${ARGS[@]}"; do remove_one "$s"; done ;;
esac

echo
echo "Done. Target: $TARGET"
