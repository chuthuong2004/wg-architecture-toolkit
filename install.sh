#!/usr/bin/env bash
# Install one or more skills from this repo into a Claude Code skills dir.
#
# Scope (where the skill is installed):
#   --user      Install to $HOME/.claude/skills/   (available in every project)
#   --project   Install to $PWD/.claude/skills/    (scoped to the current repo)
#   (no flag)   Ask interactively.
#   CLAUDE_SKILLS_DIR=... overrides both flags and the prompt.
#
# Usage:
#   ./install.sh                              # interactive — pick scope, then skill(s)
#   ./install.sh all                          # install everything (asks scope)
#   ./install.sh architecture-doc-writer ...  # install named skills (asks scope)
#   ./install.sh --user architecture-doc-writer
#   ./install.sh --project architecture-doc-writer
#   ./install.sh --link --project <name>      # symlink instead of copy (good for dev)
#   ./install.sh --uninstall --user <name>    # remove an installed skill
#
# One-liner (no clone):
#   curl -fsSL https://raw.githubusercontent.com/chuthuong2004/wg-architecture-toolkit/main/install.sh \
#     | bash -s -- --user architecture-doc-writer

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd 2>/dev/null || echo "" )"
SKILLS_SRC="$REPO_DIR/skills"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { echo "$(color '1;34' '→') $*"; }
ok()    { echo "$(color '1;32' '✓') $*"; }
warn()  { echo "$(color '1;33' '!') $*"; }
err()   { echo "$(color '1;31' '✗') $*" >&2; }

# When piped from curl, $REPO_DIR points to /dev/fd or doesn't have skills/ — re-fetch the repo.
if [ ! -d "$SKILLS_SRC" ]; then
  TMPDIR_REPO="$(mktemp -d)"
  REPO_URL="${SKILL_REPO_URL:-https://github.com/chuthuong2004/wg-architecture-toolkit.git}"
  info "Cloning $REPO_URL into $TMPDIR_REPO..."
  git clone --depth 1 "$REPO_URL" "$TMPDIR_REPO" >/dev/null
  REPO_DIR="$TMPDIR_REPO"
  SKILLS_SRC="$REPO_DIR/skills"
fi

list_skills() { ls -1 "$SKILLS_SRC" 2>/dev/null | sort; }

# Probe whether /dev/tty is actually usable. `[ -e /dev/tty ]` lies in non-interactive
# environments where the device node exists but the process has no controlling terminal.
have_tty() { (: > /dev/tty) 2>/dev/null; }

# Read from /dev/tty so prompts work even when the script itself is piped from curl.
read_tty() {
  local prompt="$1"
  local __out_var="$2"
  local ans=""
  if have_tty; then
    printf '%s' "$prompt" > /dev/tty
    read -r ans < /dev/tty || ans=""
  else
    printf '%s' "$prompt" >&2
    read -r ans || ans=""
  fi
  printf -v "$__out_var" '%s' "$ans"
}

confirm() {
  local ans
  read_tty "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

ask_scope() {
  # No TTY available and no explicit flag → safest default is --user, with a clear warning.
  if ! have_tty; then
    warn "No TTY detected; defaulting to --user."
    warn "Pass --user or --project explicitly (or set CLAUDE_SKILLS_DIR) to silence this."
    SCOPE="user"
    return
  fi
  {
    echo "Where do you want to install the skill(s)?"
    echo "  1) user    — $HOME/.claude/skills            (available in every project)"
    echo "  2) project — $PWD/.claude/skills   (scoped to this project)"
  } > /dev/tty
  local ans
  read_tty "Pick [1/2] (default 1): " ans
  case "$ans" in
    2|project|p|P) SCOPE="project" ;;
    *)             SCOPE="user" ;;
  esac
}

resolve_dst() {
  # Precedence: $CLAUDE_SKILLS_DIR > explicit flag > interactive prompt.
  if [ -n "${CLAUDE_SKILLS_DIR:-}" ]; then
    SKILLS_DST="$CLAUDE_SKILLS_DIR"
    SCOPE="custom"
    return
  fi
  if [ -z "${SCOPE:-}" ]; then
    ask_scope
  fi
  case "$SCOPE" in
    user)    SKILLS_DST="$HOME/.claude/skills" ;;
    project) SKILLS_DST="$PWD/.claude/skills" ;;
    *)       err "Unknown scope: $SCOPE"; exit 1 ;;
  esac
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
    warn "$name is not installed at $dst."
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
  {
    echo "Available skills:"
    local i=1
    for s in "${skills[@]}"; do
      echo "  $i) $s"
      i=$((i+1))
    done
    echo "  a) all"
  } >&2
  local pick
  read_tty 'Pick (number, comma-separated, or "a"): ' pick
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
  local mode="copy"
  local action="install"
  SCOPE=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --user)       SCOPE="user"; shift ;;
      --project)    SCOPE="project"; shift ;;
      --link)       mode="link"; shift ;;
      --uninstall)  action="uninstall"; shift ;;
      -h|--help)    sed -n '2,22p' "$0" 2>/dev/null || sed -n '2,22p' "${BASH_SOURCE[0]}"; return ;;
      --)           shift; break ;;
      -*)           err "Unknown flag: $1"; return 1 ;;
      *)            break ;;
    esac
  done

  resolve_dst

  if [ "$action" = "uninstall" ]; then
    if [ $# -eq 0 ]; then err "--uninstall requires at least one skill name."; return 1; fi
    for n in "$@"; do uninstall_one "$n"; done
    return
  fi

  if [ $# -eq 0 ]; then
    interactive_pick
    return
  fi

  if [ "${1:-}" = "all" ]; then
    while IFS= read -r s; do install_one "$s" "$mode"; done < <(list_skills)
    return
  fi

  for n in "$@"; do install_one "$n" "$mode"; done
}

main "$@"
echo
info "Done. Restart Claude Code (or open a new session) so the skills are loaded."
