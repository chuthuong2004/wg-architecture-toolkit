#!/usr/bin/env bash
# Install one or more skills from this repo into ~/.claude/skills/.
#
# Usage:
#   ./install.sh                              # interactive — pick from menu
#   ./install.sh all                          # install everything
#   ./install.sh architecture-doc-writer ...  # install named skills
#   ./install.sh --link <name>                # symlink instead of copy (good for dev)
#   ./install.sh --uninstall <name>           # remove an installed skill
#
# One-liner (no clone):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh \
#     | bash -s -- architecture-doc-writer

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { echo "$(color '1;34' '→') $*"; }
ok()    { echo "$(color '1;32' '✓') $*"; }
warn()  { echo "$(color '1;33' '!') $*"; }
err()   { echo "$(color '1;31' '✗') $*" >&2; }

# When piped from curl, $REPO_DIR points to /dev/fd or similar — re-fetch the repo.
if [ ! -d "$SKILLS_SRC" ]; then
  TMPDIR_REPO="$(mktemp -d)"
  REPO_URL="${SKILL_REPO_URL:-https://github.com/REPLACE_ME/wg-architecture-toolkit.git}"
  info "Cloning $REPO_URL into $TMPDIR_REPO..."
  git clone --depth 1 "$REPO_URL" "$TMPDIR_REPO"
  REPO_DIR="$TMPDIR_REPO"
  SKILLS_SRC="$REPO_DIR/skills"
fi

list_skills() { ls -1 "$SKILLS_SRC" 2>/dev/null | sort; }

confirm() {
  local prompt="$1"
  local ans
  printf '%s [y/N] ' "$prompt"
  read -r ans || ans=""
  [[ "$ans" =~ ^[Yy]$ ]]
}

install_one() {
  local name="$1"
  local mode="${2:-copy}"  # copy | link
  local src="$SKILLS_SRC/$name"
  local dst="$SKILLS_DST/$name"

  if [ ! -d "$src" ]; then
    err "Skill '$name' not found in repo. Available: $(list_skills | tr '\n' ' ')"
    return 1
  fi

  mkdir -p "$SKILLS_DST"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    warn "$dst already exists."
    confirm "Overwrite?" || { info "Skipped $name."; return 0; }
    rm -rf "$dst"
  fi

  if [ "$mode" = "link" ]; then
    ln -s "$src" "$dst"
    ok "Linked $name → $dst"
  else
    cp -R "$src" "$dst"
    ok "Installed $name → $dst"
  fi
}

uninstall_one() {
  local name="$1"
  local dst="$SKILLS_DST/$name"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    warn "$name is not installed."
    return 0
  fi
  rm -rf "$dst"
  ok "Removed $dst"
}

interactive_pick() {
  local skills=()
  while IFS= read -r line; do skills+=("$line"); done < <(list_skills)
  if [ "${#skills[@]}" -eq 0 ]; then
    err "No skills found in $SKILLS_SRC"
    exit 1
  fi
  echo "Available skills:"
  local i=1
  for s in "${skills[@]}"; do
    echo "  $i) $s"
    i=$((i+1))
  done
  echo "  a) all"
  printf 'Pick (number, comma-separated, or "a"): '
  local pick
  read -r pick || pick=""
  if [ -z "$pick" ]; then info "Nothing selected."; exit 0; fi
  if [ "$pick" = "a" ] || [ "$pick" = "all" ]; then
    for s in "${skills[@]}"; do install_one "$s"; done
    return
  fi
  IFS=',' read -r -a picks <<< "$pick"
  for p in "${picks[@]}"; do
    p="${p// /}"
    install_one "${skills[$((p-1))]}"
  done
}

main() {
  if [ $# -eq 0 ]; then
    interactive_pick
    return
  fi

  local mode="copy"
  case "$1" in
    --link)       mode="link"; shift ;;
    --uninstall)  shift; for n in "$@"; do uninstall_one "$n"; done; return ;;
    -h|--help)    sed -n '2,16p' "$0"; return ;;
  esac

  if [ "${1:-}" = "all" ]; then
    while IFS= read -r s; do install_one "$s" "$mode"; done < <(list_skills)
    return
  fi

  for n in "$@"; do install_one "$n" "$mode"; done
}

main "$@"
echo
info "Done. Restart Claude Code (or open a new session) so the skills are loaded."
