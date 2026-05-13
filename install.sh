#!/usr/bin/env bash
# Install one or more skills from this repo into a Claude Code skills dir.
#
# Scope (where the skill is installed):
#   --user      Install to $HOME/.claude/skills/   (available in every project)
#   --project   Install to $PWD/.claude/skills/    (scoped to the current repo)
#   (no flag)   Ask interactively (↑/↓ arrow-key picker, falls back to numbered prompt).
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
#   curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh \
#     | bash -s -- --user architecture-doc-writer

set -euo pipefail

# When piped from curl, BASH_SOURCE[0] is unset (script came from stdin).
# Fall back to $0 — it'll be "bash", whose dirname is ".", which is harmless
# because the `! -d "$SKILLS_SRC"` check below triggers the clone fallback.
SELF="${BASH_SOURCE[0]:-$0}"
REPO_DIR="$( cd "$( dirname "$SELF" )" 2>/dev/null && pwd || echo "" )"
SKILLS_SRC="$REPO_DIR/skills"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { echo "$(color '1;34' '→') $*"; }
ok()    { echo "$(color '1;32' '✓') $*"; }
warn()  { echo "$(color '1;33' '!') $*"; }
err()   { echo "$(color '1;31' '✗') $*" >&2; }

# When piped from curl, $REPO_DIR points to /dev/fd or doesn't have skills/ — re-fetch the repo.
if [ ! -d "$SKILLS_SRC" ]; then
  TMPDIR_REPO="$(mktemp -d)"
  REPO_URL="${SKILL_REPO_URL:-https://github.com/chuthuong2004/claude-skills.git}"
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

# Arrow-key menu. Args: title, then options. Sets PICK_RESULT to the chosen
# 0-based index. Controls: ↑/↓ or k/j to move, Enter to confirm, Esc/q to cancel.
# Returns:
#   0 — user confirmed a selection (PICK_RESULT is valid)
#   1 — user explicitly cancelled (q, bare Esc) — caller should abort
#   2 — couldn't run (no TTY, stty failed) — caller may fall back to a plain prompt
#
# Each option is truncated to fit the terminal width — a wrapped line would
# desync the cursor-rewind math and produce stacked, garbled output.
_pick_saved_tty=""
_pick_cleanup() {
  [ -n "$_pick_saved_tty" ] && stty "$_pick_saved_tty" < /dev/tty 2>/dev/null
  printf '\e[?25h' > /dev/tty 2>/dev/null || true
  _pick_saved_tty=""
}

term_cols() {
  local c=""
  c=$(tput cols 2>/dev/null) || c=""
  [ -z "$c" ] && c="${COLUMNS:-80}"
  echo "${c:-80}"
}

arrow_pick() {
  local title="$1"; shift
  local options=( "$@" )
  local count=${#options[@]}
  local selected=0

  if ! have_tty || [ "$count" -eq 0 ]; then return 2; fi

  local cols max_label
  cols=$(term_cols)
  max_label=$((cols - 3))     # leave room for "> " prefix and a safety col
  [ "$max_label" -lt 10 ] && max_label=10

  _pick_saved_tty=$(stty -g < /dev/tty 2>/dev/null) || { _pick_saved_tty=""; return 2; }
  trap '_pick_cleanup' EXIT INT TERM
  stty -icanon -echo min 1 time 0 < /dev/tty
  printf '\e[?25l' > /dev/tty

  # Truncate every option once up-front.
  local i
  for ((i=0; i<count; i++)); do
    if [ "${#options[$i]}" -gt "$max_label" ]; then
      options[$i]="${options[$i]:0:$((max_label-1))}…"
    fi
  done

  # Truncate title too so it doesn't wrap.
  if [ "${#title}" -gt "$cols" ]; then
    title="${title:0:$((cols-1))}…"
  fi

  printf '%s\n' "$title" > /dev/tty
  for ((i=0; i<count; i++)); do printf '\n' > /dev/tty; done
  printf '\e[%dA' "$count" > /dev/tty

  local first=1
  while true; do
    if [ "$first" -eq 0 ]; then
      printf '\e[%dA' "$count" > /dev/tty
    fi
    first=0
    for ((i=0; i<count; i++)); do
      printf '\e[2K\r' > /dev/tty
      if [ "$i" -eq "$selected" ]; then
        printf '\e[7m> %s\e[0m\n' "${options[$i]}" > /dev/tty
      else
        printf '  %s\n' "${options[$i]}" > /dev/tty
      fi
    done

    local key=""
    # `read -n1` treats newline as a delimiter (controlled by IFS, default is \n),
    # so when the user hits Enter the call returns success with $key="" — we have
    # to match the empty string here, not just $'\n'/$'\r'.
    IFS= read -rsn1 key < /dev/tty || break
    case "$key" in
      $'\e')
        local rest=""
        IFS= read -rsn2 -t 1 rest < /dev/tty 2>/dev/null || rest=""
        case "$rest" in
          '[A'|'OA') selected=$(( (selected - 1 + count) % count )) ;;
          '[B'|'OB') selected=$(( (selected + 1) % count )) ;;
          '')        _pick_cleanup; trap - EXIT INT TERM; return 1 ;;
        esac
        ;;
      ''|$'\n'|$'\r') break ;;
      k|K)            selected=$(( (selected - 1 + count) % count )) ;;
      j|J)            selected=$(( (selected + 1) % count )) ;;
      q|Q)            _pick_cleanup; trap - EXIT INT TERM; return 1 ;;
    esac
  done

  _pick_cleanup
  trap - EXIT INT TERM
  PICK_RESULT=$selected
  return 0
}

ask_scope() {
  if ! have_tty; then
    warn "No TTY detected; defaulting to --user."
    warn "Pass --user or --project explicitly (or set CLAUDE_SKILLS_DIR) to silence this."
    SCOPE="user"
    return
  fi
  {
    echo
    echo "Install destination:"
    echo "  user    → $HOME/.claude/skills"
    echo "  project → $PWD/.claude/skills"
    echo
  } > /dev/tty
  arrow_pick "Pick scope (↑/↓ + Enter, q to cancel):" \
      "user      (global — available in every project)" \
      "project   (scoped to current directory)"
  case $? in
    0) case "$PICK_RESULT" in
         0) SCOPE="user" ;;
         1) SCOPE="project" ;;
       esac
       return ;;
    1) info "Cancelled."; exit 130 ;;
    2) ;;  # fall through to numbered prompt
  esac
  {
    echo "  1) user"
    echo "  2) project"
  } > /dev/tty
  local ans
  read_tty "Pick [1/2] (default 1, q to cancel): " ans
  case "$ans" in
    q|Q)           info "Cancelled."; exit 130 ;;
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

  if have_tty; then
    local menu=( "${skills[@]}" "all (install every skill)" )
    arrow_pick "Pick a skill to install (↑/↓ + Enter, q to cancel):" "${menu[@]}"
    case $? in
      0) if [ "$PICK_RESULT" -eq "${#skills[@]}" ]; then
           for s in "${skills[@]}"; do install_one "$s"; done
         else
           install_one "${skills[$PICK_RESULT]}"
         fi
         return ;;
      1) info "Cancelled."; exit 130 ;;
      2) ;;  # stty failed — fall through to numbered prompt below
    esac
  fi

  # No TTY: numbered prompt fallback (still supports comma-separated multi-select).
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
      -h|--help)    sed -n '2,22p' "$SELF" 2>/dev/null || echo "See https://github.com/chuthuong2004/claude-skills#install"; return ;;
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
