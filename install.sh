#!/usr/bin/env bash
# Install one or more skills or subagents from this repo into a Claude Code config dir.
#
# Items in this repo:
#   skills/<name>/        → installed to <root>/.claude/skills/<name>/
#   agents/<name>.md      → installed to <root>/.claude/agents/<name>.md
#
# Scope (where <root> lives):
#   --user      $HOME           (available in every project)
#   --project   $PWD            (scoped to the current repo)
#   (no flag)   Ask interactively (↑/↓ arrow-key picker, falls back to numbered prompt).
#   CLAUDE_SKILLS_DIR=... overrides the skills destination.
#   CLAUDE_AGENTS_DIR=... overrides the agents destination.
#
# Usage:
#   ./install.sh                              # interactive — pick scope, then one item
#   ./install.sh all-skills                   # install every skill (asks scope)
#   ./install.sh all-agents                   # install every agent (asks scope)
#   ./install.sh seo-expert architecture-doc-writer
#   ./install.sh --user seo-expert
#   ./install.sh --project seo-expert
#   ./install.sh --link --project <name>      # symlink instead of copy (good for dev)
#   ./install.sh --uninstall --user <name>    # remove an installed item
#
# One-liner (no clone):
#   curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh \
#     | bash -s -- --user seo-expert

set -euo pipefail

# When piped from curl, BASH_SOURCE[0] is unset (script came from stdin).
# Fall back to $0 — it'll be "bash", whose dirname is ".", which is harmless
# because the `! -d "$SKILLS_SRC"` check below triggers the clone fallback.
SELF="${BASH_SOURCE[0]:-$0}"
REPO_DIR="$( cd "$( dirname "$SELF" )" 2>/dev/null && pwd || echo "" )"
SKILLS_SRC="$REPO_DIR/skills"
AGENTS_SRC="$REPO_DIR/agents"

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
  AGENTS_SRC="$REPO_DIR/agents"
fi

list_skills() { ls -1 "$SKILLS_SRC" 2>/dev/null | sort; }

list_agents() {
  [ -d "$AGENTS_SRC" ] || return 0
  local f
  for f in "$AGENTS_SRC"/*.md; do
    [ -e "$f" ] || continue
    basename "$f" .md
  done | sort
}

# Echoes "skill", "agent", or "" (not found). Skill names take precedence on
# unlikely collisions, but we warn if both exist for the same name.
item_type() {
  local name="$1"
  local in_skills=0 in_agents=0
  [ -d "$SKILLS_SRC/$name" ] && in_skills=1
  [ -f "$AGENTS_SRC/$name.md" ] && in_agents=1
  if [ "$in_skills" -eq 1 ] && [ "$in_agents" -eq 1 ]; then
    warn "Name collision: '$name' exists as both a skill and an agent — installing the skill." >&2
  fi
  if [ "$in_skills" -eq 1 ]; then echo "skill"; return; fi
  if [ "$in_agents" -eq 1 ]; then echo "agent"; return; fi
  echo ""
}

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
    warn "Pass --user or --project explicitly (or set CLAUDE_SKILLS_DIR / CLAUDE_AGENTS_DIR) to silence this."
    SCOPE="user"
    return
  fi
  {
    echo
    echo "Install destination:"
    echo "  user    → $HOME/.claude/{skills,agents}"
    echo "  project → $PWD/.claude/{skills,agents}"
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
  # CLAUDE_SKILLS_DIR / CLAUDE_AGENTS_DIR override per-type; otherwise scope decides.
  if [ -z "${SCOPE:-}" ] && [ -z "${CLAUDE_SKILLS_DIR:-}" ] && [ -z "${CLAUDE_AGENTS_DIR:-}" ]; then
    ask_scope
  fi
  case "${SCOPE:-}" in
    user)    SKILLS_DST="$HOME/.claude/skills"; AGENTS_DST="$HOME/.claude/agents" ;;
    project) SKILLS_DST="$PWD/.claude/skills";  AGENTS_DST="$PWD/.claude/agents"  ;;
    "")      ;;  # scope wasn't asked because env overrides cover both — handled below
    *)       err "Unknown scope: $SCOPE"; exit 1 ;;
  esac
  [ -n "${CLAUDE_SKILLS_DIR:-}" ] && SKILLS_DST="$CLAUDE_SKILLS_DIR"
  [ -n "${CLAUDE_AGENTS_DIR:-}" ] && AGENTS_DST="$CLAUDE_AGENTS_DIR"
  # If only one of the env vars was set, fill the other from $HOME as a safe default.
  : "${SKILLS_DST:=$HOME/.claude/skills}"
  : "${AGENTS_DST:=$HOME/.claude/agents}"
}

install_one() {
  local name="$1"
  local mode="${2:-copy}"  # copy | link
  local type
  type=$(item_type "$name")
  local src dst dst_root
  case "$type" in
    skill)
      src="$SKILLS_SRC/$name"
      dst_root="$SKILLS_DST"
      dst="$dst_root/$name"
      ;;
    agent)
      src="$AGENTS_SRC/$name.md"
      dst_root="$AGENTS_DST"
      dst="$dst_root/$name.md"
      ;;
    *)
      err "Item '$name' not found. Available skills: $(list_skills | tr '\n' ' '). Available agents: $(list_agents | tr '\n' ' ')."
      return 1
      ;;
  esac

  mkdir -p "$dst_root"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    warn "$dst already exists."
    confirm "Overwrite?" || { info "Skipped $name."; return 0; }
    rm -rf "$dst"
  fi

  if [ "$mode" = "link" ]; then
    ln -s "$src" "$dst"
    ok "Linked $type $name → $dst"
  else
    cp -R "$src" "$dst"
    ok "Installed $type $name → $dst"
  fi
}

uninstall_one() {
  local name="$1"
  local type
  type=$(item_type "$name")
  local dst
  case "$type" in
    skill) dst="$SKILLS_DST/$name" ;;
    agent) dst="$AGENTS_DST/$name.md" ;;
    *)
      # Item is no longer in the repo (rare) — try both destinations.
      if [ -e "$SKILLS_DST/$name" ] || [ -L "$SKILLS_DST/$name" ]; then
        dst="$SKILLS_DST/$name"
      elif [ -e "$AGENTS_DST/$name.md" ] || [ -L "$AGENTS_DST/$name.md" ]; then
        dst="$AGENTS_DST/$name.md"
      else
        warn "$name is not installed (checked skills and agents)."
        return 0
      fi
      ;;
  esac
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    warn "$name is not installed at $dst."
    return 0
  fi
  rm -rf "$dst"
  ok "Removed $dst"
}

interactive_pick() {
  local items=() labels=()
  local s a
  while IFS= read -r s; do
    [ -n "$s" ] && items+=("$s") && labels+=("$s  (skill)")
  done < <(list_skills)
  while IFS= read -r a; do
    [ -n "$a" ] && items+=("$a") && labels+=("$a  (agent)")
  done < <(list_agents)

  if [ "${#items[@]}" -eq 0 ]; then
    err "No skills or agents found in $REPO_DIR"
    exit 1
  fi

  if have_tty; then
    arrow_pick "Pick a skill or agent to install (↑/↓ + Enter, q to cancel):" "${labels[@]}"
    case $? in
      0) install_one "${items[$PICK_RESULT]}"; return ;;
      1) info "Cancelled."; exit 130 ;;
      2) ;;  # stty failed — fall through to numbered prompt below
    esac
  fi

  # No TTY: numbered prompt fallback (still supports comma-separated multi-select).
  {
    echo "Available:"
    local i=1
    for l in "${labels[@]}"; do
      echo "  $i) $l"
      i=$((i+1))
    done
  } >&2
  local pick
  read_tty 'Pick (number or comma-separated): ' pick
  if [ -z "$pick" ]; then info "Nothing selected."; exit 0; fi
  IFS=',' read -r -a picks <<< "$pick"
  for p in "${picks[@]}"; do
    p="${p// /}"
    install_one "${items[$((p-1))]}"
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
      -h|--help)    sed -n '2,30p' "$SELF" 2>/dev/null || echo "See https://github.com/chuthuong2004/claude-skills#install"; return ;;
      --)           shift; break ;;
      -*)           err "Unknown flag: $1"; return 1 ;;
      *)            break ;;
    esac
  done

  resolve_dst

  if [ "$action" = "uninstall" ]; then
    if [ $# -eq 0 ]; then err "--uninstall requires at least one skill/agent name."; return 1; fi
    for n in "$@"; do uninstall_one "$n"; done
    return
  fi

  if [ $# -eq 0 ]; then
    interactive_pick
    return
  fi

  for arg in "$@"; do
    case "$arg" in
      all-skills)
        while IFS= read -r s; do install_one "$s" "$mode"; done < <(list_skills)
        ;;
      all-agents)
        while IFS= read -r a; do install_one "$a" "$mode"; done < <(list_agents)
        ;;
      all)
        err "'all' is no longer supported — use 'all-skills' or 'all-agents' (or list items explicitly)."
        return 1
        ;;
      *)
        install_one "$arg" "$mode"
        ;;
    esac
  done
}

main "$@"
echo
info "Done. Restart Claude Code (or open a new session) so the items are loaded."
