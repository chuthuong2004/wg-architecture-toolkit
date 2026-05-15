#!/usr/bin/env bash
# Install skills/subagents from this repo into Claude Code or Cursor.
#
# Items in this repo:
#   skills/<name>/        — workflow recipes with refs/assets
#   agents/<name>.md      — single-file subagent personas
#
# Targets:
#   Claude Code  → <root>/.claude/skills/<name>/   and   <root>/.claude/agents/<name>.md
#   Cursor       → <PWD>/AGENTS.md  (each item appended as a section, idempotent)
#
# Interactive flow (run with no args, e.g. via `curl | bash`):
#   1) Pick target AI: Claude Code or Cursor
#   2) (Claude only) Pick scope: --user or --project
#   3) Pick item(s) to install — multi-select, Space toggles, Enter confirms
#
# Non-interactive flags:
#   --claude | --cursor         Skip the target picker.
#   --user | --project          (Claude only) skip the scope picker.
#   --link                      Symlink instead of copy (Claude only).
#   --uninstall                 Remove named item(s).
#   --cursor-file PATH          Override Cursor AGENTS.md path (default: $PWD/AGENTS.md).
#   CLAUDE_SKILLS_DIR=...       Override Claude skills destination.
#   CLAUDE_AGENTS_DIR=...       Override Claude agents destination.
#   CURSOR_AGENTS_FILE=...      Override Cursor AGENTS.md path.
#
# Bulk keywords (must be explicit — nothing is installed unless you name it):
#   all-skills    install every skill from this repo
#   all-agents    install every agent from this repo
#
# Examples:
#   curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash
#   ./install.sh --claude --user seo-expert
#   ./install.sh --cursor seo-expert architecture-doc-writer
#   ./install.sh --uninstall --claude --user seo-expert

set -euo pipefail

SELF="${BASH_SOURCE[0]:-$0}"
REPO_DIR="$( cd "$( dirname "$SELF" )" 2>/dev/null && pwd || echo "" )"
SKILLS_SRC="$REPO_DIR/skills"
AGENTS_SRC="$REPO_DIR/agents"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { echo "$(color '1;34' '→') $*"; }
ok()    { echo "$(color '1;32' '✓') $*"; }
warn()  { echo "$(color '1;33' '!') $*"; }
err()   { echo "$(color '1;31' '✗') $*" >&2; }

# When piped from curl, $REPO_DIR doesn't have skills/ — clone the repo to a temp dir.
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

# Echoes "skill", "agent", or "" (not found).
item_type() {
  local name="$1"
  local in_skills=0 in_agents=0
  [ -d "$SKILLS_SRC/$name" ] && in_skills=1
  [ -f "$AGENTS_SRC/$name.md" ] && in_agents=1
  if [ "$in_skills" -eq 1 ] && [ "$in_agents" -eq 1 ]; then
    warn "Name collision: '$name' exists as both — installing the skill." >&2
  fi
  if [ "$in_skills" -eq 1 ]; then echo "skill"; return; fi
  if [ "$in_agents" -eq 1 ]; then echo "agent"; return; fi
  echo ""
}

have_tty() { (: > /dev/tty) 2>/dev/null; }

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

# ---- Arrow-key pickers ------------------------------------------------------

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

# Single-select picker. Args: title, options. Sets PICK_RESULT to 0-based index.
# Returns: 0 confirmed, 1 cancelled, 2 no-TTY.
arrow_pick() {
  local title="$1"; shift
  local options=( "$@" )
  local count=${#options[@]}
  local selected=0

  if ! have_tty || [ "$count" -eq 0 ]; then return 2; fi

  local cols max_label
  cols=$(term_cols)
  max_label=$((cols - 3))
  [ "$max_label" -lt 10 ] && max_label=10

  _pick_saved_tty=$(stty -g < /dev/tty 2>/dev/null) || { _pick_saved_tty=""; return 2; }
  trap '_pick_cleanup' EXIT INT TERM
  stty -icanon -echo min 1 time 0 < /dev/tty
  printf '\e[?25l' > /dev/tty

  local i
  for ((i=0; i<count; i++)); do
    if [ "${#options[$i]}" -gt "$max_label" ]; then
      options[$i]="${options[$i]:0:$((max_label-1))}…"
    fi
  done
  if [ "${#title}" -gt "$cols" ]; then
    title="${title:0:$((cols-1))}…"
  fi

  printf '%s\n' "$title" > /dev/tty
  for ((i=0; i<count; i++)); do printf '\n' > /dev/tty; done
  printf '\e[%dA' "$count" > /dev/tty

  local first=1
  while true; do
    if [ "$first" -eq 0 ]; then printf '\e[%dA' "$count" > /dev/tty; fi
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

# Multi-select picker. Args: title, options. Sets PICK_RESULTS to array of indices.
# Controls: ↑/↓ or k/j move, Space toggle, `a` toggle-all, Enter confirm, q cancel.
arrow_pick_multi() {
  local title="$1"; shift
  local options=( "$@" )
  local count=${#options[@]}
  local selected=0
  local -a checked
  local i
  for ((i=0; i<count; i++)); do checked[i]=0; done

  if ! have_tty || [ "$count" -eq 0 ]; then return 2; fi

  local cols max_label
  cols=$(term_cols)
  max_label=$((cols - 7))   # leave room for "> [x] "
  [ "$max_label" -lt 10 ] && max_label=10

  _pick_saved_tty=$(stty -g < /dev/tty 2>/dev/null) || { _pick_saved_tty=""; return 2; }
  trap '_pick_cleanup' EXIT INT TERM
  stty -icanon -echo min 1 time 0 < /dev/tty
  printf '\e[?25l' > /dev/tty

  for ((i=0; i<count; i++)); do
    if [ "${#options[$i]}" -gt "$max_label" ]; then
      options[$i]="${options[$i]:0:$((max_label-1))}…"
    fi
  done
  if [ "${#title}" -gt "$cols" ]; then
    title="${title:0:$((cols-1))}…"
  fi

  printf '%s\n' "$title" > /dev/tty
  for ((i=0; i<count; i++)); do printf '\n' > /dev/tty; done
  printf '\e[%dA' "$count" > /dev/tty

  local first=1
  while true; do
    if [ "$first" -eq 0 ]; then printf '\e[%dA' "$count" > /dev/tty; fi
    first=0
    for ((i=0; i<count; i++)); do
      printf '\e[2K\r' > /dev/tty
      local mark="[ ]"
      [ "${checked[$i]}" -eq 1 ] && mark="[x]"
      if [ "$i" -eq "$selected" ]; then
        printf '\e[7m> %s %s\e[0m\n' "$mark" "${options[$i]}" > /dev/tty
      else
        printf '  %s %s\n' "$mark" "${options[$i]}" > /dev/tty
      fi
    done

    local key=""
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
      ' ') checked[$selected]=$(( 1 - checked[$selected] )) ;;
      ''|$'\n'|$'\r') break ;;
      k|K) selected=$(( (selected - 1 + count) % count )) ;;
      j|J) selected=$(( (selected + 1) % count )) ;;
      a|A)
        local any=0
        for ((i=0; i<count; i++)); do [ "${checked[$i]}" -eq 1 ] && any=1; done
        local new=1; [ "$any" -eq 1 ] && new=0
        for ((i=0; i<count; i++)); do checked[$i]=$new; done
        ;;
      q|Q) _pick_cleanup; trap - EXIT INT TERM; return 1 ;;
    esac
  done

  _pick_cleanup
  trap - EXIT INT TERM
  PICK_RESULTS=()
  for ((i=0; i<count; i++)); do
    [ "${checked[$i]}" -eq 1 ] && PICK_RESULTS+=("$i")
  done
  return 0
}

# ---- Target + scope ---------------------------------------------------------

ask_target() {
  if ! have_tty; then
    warn "No TTY; defaulting target to claude."
    TARGET="claude"
    return
  fi
  echo > /dev/tty
  arrow_pick "Pick AI tool (↑/↓ + Enter, q to cancel):" \
      "Claude Code   →  .claude/skills + .claude/agents" \
      "Cursor        →  AGENTS.md at project root"
  case $? in
    0) case "$PICK_RESULT" in 0) TARGET="claude" ;; 1) TARGET="cursor" ;; esac; return ;;
    1) info "Cancelled."; exit 130 ;;
    2) ;;
  esac
  local ans
  read_tty "Target [1=claude, 2=cursor] (default 1, q to cancel): " ans
  case "$ans" in
    q|Q)        info "Cancelled."; exit 130 ;;
    2|c|cursor) TARGET="cursor" ;;
    *)          TARGET="claude" ;;
  esac
}

ask_scope() {
  if ! have_tty; then
    warn "No TTY; defaulting Claude scope to --user."
    warn "Pass --user or --project explicitly to silence this."
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
    0) case "$PICK_RESULT" in 0) SCOPE="user" ;; 1) SCOPE="project" ;; esac; return ;;
    1) info "Cancelled."; exit 130 ;;
    2) ;;
  esac
  local ans
  read_tty "Pick [1=user, 2=project] (default 1, q to cancel): " ans
  case "$ans" in
    q|Q)           info "Cancelled."; exit 130 ;;
    2|project|p|P) SCOPE="project" ;;
    *)             SCOPE="user" ;;
  esac
}

resolve_target_dst() {
  case "$TARGET" in
    claude)
      [ -z "${SCOPE:-}" ] && [ -z "${CLAUDE_SKILLS_DIR:-}" ] && [ -z "${CLAUDE_AGENTS_DIR:-}" ] && ask_scope
      case "${SCOPE:-}" in
        user)    SKILLS_DST="$HOME/.claude/skills"; AGENTS_DST="$HOME/.claude/agents" ;;
        project) SKILLS_DST="$PWD/.claude/skills";  AGENTS_DST="$PWD/.claude/agents"  ;;
        "")      ;;
        *)       err "Unknown scope: $SCOPE"; exit 1 ;;
      esac
      [ -n "${CLAUDE_SKILLS_DIR:-}" ] && SKILLS_DST="$CLAUDE_SKILLS_DIR"
      [ -n "${CLAUDE_AGENTS_DIR:-}" ] && AGENTS_DST="$CLAUDE_AGENTS_DIR"
      : "${SKILLS_DST:=$HOME/.claude/skills}"
      : "${AGENTS_DST:=$HOME/.claude/agents}"
      ;;
    cursor)
      CURSOR_AGENTS_FILE="${CURSOR_AGENTS_FILE:-$PWD/AGENTS.md}"
      info "Cursor target: $CURSOR_AGENTS_FILE"
      ;;
  esac
}

# ---- Claude install/uninstall ----------------------------------------------

install_one_claude() {
  local name="$1"
  local mode="${2:-copy}"
  local type
  type=$(item_type "$name")
  local src dst dst_root
  case "$type" in
    skill) src="$SKILLS_SRC/$name";    dst_root="$SKILLS_DST"; dst="$dst_root/$name" ;;
    agent) src="$AGENTS_SRC/$name.md"; dst_root="$AGENTS_DST"; dst="$dst_root/$name.md" ;;
    *)     err "Item '$name' not found. Skills: $(list_skills | tr '\n' ' '); agents: $(list_agents | tr '\n' ' ')."; return 1 ;;
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

uninstall_one_claude() {
  local name="$1"
  local type
  type=$(item_type "$name")
  local dst
  case "$type" in
    skill) dst="$SKILLS_DST/$name" ;;
    agent) dst="$AGENTS_DST/$name.md" ;;
    *)
      if   [ -e "$SKILLS_DST/$name"   ] || [ -L "$SKILLS_DST/$name"   ]; then dst="$SKILLS_DST/$name"
      elif [ -e "$AGENTS_DST/$name.md" ] || [ -L "$AGENTS_DST/$name.md" ]; then dst="$AGENTS_DST/$name.md"
      else warn "$name is not installed."; return 0
      fi ;;
  esac
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then warn "$name is not installed at $dst."; return 0; fi
  rm -rf "$dst"
  ok "Removed $dst"
}

# ---- Cursor install/uninstall (AGENTS.md) ----------------------------------

cursor_start_marker() { echo "<!-- claude-skills:start $1 -->"; }
cursor_end_marker()   { echo "<!-- claude-skills:end $1 -->"; }

# Strip YAML frontmatter from stdin (only if the very first line is `---`).
strip_frontmatter() {
  awk '
    BEGIN { state = "maybe" }   # maybe → inside → done
    state == "maybe" {
      if (NR == 1 && $0 == "---") { state = "inside"; next }
      else { state = "done"; print; next }
    }
    state == "inside" {
      if ($0 == "---") { state = "done"; next }
      next
    }
    { print }
  '
}

cursor_remove_section() {
  local name="$1"
  local file="$CURSOR_AGENTS_FILE"
  [ -f "$file" ] || return 0
  local s e tmp
  s=$(cursor_start_marker "$name")
  e=$(cursor_end_marker "$name")
  tmp=$(mktemp)
  awk -v s="$s" -v e="$e" '
    BEGIN { skip = 0 }
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$file" > "$tmp"
  # Collapse trailing blank lines so re-installs don't accumulate whitespace.
  awk 'NF { blank=0 } !NF { blank++ } { lines[NR]=$0 } END { for (i=1; i<=NR-blank+1; i++) print lines[i] }' "$tmp" > "$tmp.2" 2>/dev/null || cp "$tmp" "$tmp.2"
  mv "$tmp.2" "$file"
  rm -f "$tmp"
}

build_skill_block() {
  local name="$1"
  local dir="$SKILLS_SRC/$name"
  echo "## Skill: $name"
  echo
  if [ -f "$dir/SKILL.md" ]; then
    strip_frontmatter < "$dir/SKILL.md"
    echo
  fi
  if [ -d "$dir/references" ]; then
    echo "### References"
    echo
    local f
    for f in "$dir/references"/*; do
      [ -f "$f" ] || continue
      echo "#### $(basename "$f")"
      echo
      cat "$f"
      echo
    done
  fi
  if [ -d "$dir/assets" ]; then
    echo "### Assets"
    echo
    local f
    for f in "$dir/assets"/*; do
      [ -f "$f" ] || continue
      echo "#### $(basename "$f")"
      echo
      cat "$f"
      echo
    done
  fi
}

build_agent_block() {
  local name="$1"
  echo "## Agent: $name"
  echo
  strip_frontmatter < "$AGENTS_SRC/$name.md"
}

install_one_cursor() {
  local name="$1"
  local type
  type=$(item_type "$name")
  if [ -z "$type" ]; then
    err "Item '$name' not found. Skills: $(list_skills | tr '\n' ' '); agents: $(list_agents | tr '\n' ' ')."
    return 1
  fi

  local file="$CURSOR_AGENTS_FILE"
  mkdir -p "$(dirname "$file")"

  if [ ! -f "$file" ]; then
    cat > "$file" <<'HEADER'
# AGENTS

Skills and subagents installed via [claude-skills](https://github.com/chuthuong2004/claude-skills).
Each section below is delimited by `<!-- claude-skills:start NAME -->` / `<!-- claude-skills:end NAME -->`
markers — feel free to edit, but keep the markers so re-installs stay idempotent.
HEADER
  fi

  cursor_remove_section "$name"

  {
    echo
    cursor_start_marker "$name"
    case "$type" in
      skill) build_skill_block "$name" ;;
      agent) build_agent_block "$name" ;;
    esac
    cursor_end_marker "$name"
  } >> "$file"

  ok "Wrote $type $name → $file"
}

uninstall_one_cursor() {
  local name="$1"
  if [ ! -f "$CURSOR_AGENTS_FILE" ]; then
    warn "No AGENTS.md at $CURSOR_AGENTS_FILE."
    return 0
  fi
  cursor_remove_section "$name"
  ok "Removed section '$name' from $CURSOR_AGENTS_FILE"
}

# ---- Dispatch --------------------------------------------------------------

install_dispatch() {
  case "$TARGET" in
    claude) install_one_claude "$1" "${MODE:-copy}" ;;
    cursor) install_one_cursor "$1" ;;
    *)      err "Unknown target: $TARGET"; return 1 ;;
  esac
}

uninstall_dispatch() {
  case "$TARGET" in
    claude) uninstall_one_claude "$1" ;;
    cursor) uninstall_one_cursor "$1" ;;
    *)      err "Unknown target: $TARGET"; return 1 ;;
  esac
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
    arrow_pick_multi "Pick item(s) (↑/↓ move, Space toggle, a all, Enter confirm, q cancel):" "${labels[@]}"
    case $? in
      0)
        if [ "${#PICK_RESULTS[@]}" -eq 0 ]; then info "Nothing selected."; exit 0; fi
        local idx
        for idx in "${PICK_RESULTS[@]}"; do install_dispatch "${items[$idx]}"; done
        return ;;
      1) info "Cancelled."; exit 130 ;;
      2) ;;
    esac
  fi

  {
    echo "Available:"
    local i=1
    for l in "${labels[@]}"; do echo "  $i) $l"; i=$((i+1)); done
  } >&2
  local pick
  read_tty 'Pick (numbers, comma-separated): ' pick
  if [ -z "$pick" ]; then info "Nothing selected."; exit 0; fi
  IFS=',' read -r -a picks <<< "$pick"
  for p in "${picks[@]}"; do
    p="${p// /}"
    install_dispatch "${items[$((p-1))]}"
  done
}

main() {
  MODE="copy"
  local action="install"
  TARGET=""
  SCOPE=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --claude)        TARGET="claude"; shift ;;
      --cursor)        TARGET="cursor"; shift ;;
      --target)        TARGET="$2"; shift 2 ;;
      --user)          SCOPE="user"; shift ;;
      --project)       SCOPE="project"; shift ;;
      --link)          MODE="link"; shift ;;
      --uninstall)     action="uninstall"; shift ;;
      --cursor-file)   CURSOR_AGENTS_FILE="$2"; shift 2 ;;
      -h|--help)       sed -n '2,40p' "$SELF" 2>/dev/null || echo "See https://github.com/chuthuong2004/claude-skills#install"; return ;;
      --)              shift; break ;;
      -*)              err "Unknown flag: $1"; return 1 ;;
      *)               break ;;
    esac
  done

  if [ -z "$TARGET" ]; then ask_target; fi
  resolve_target_dst

  if [ "$action" = "uninstall" ]; then
    if [ $# -eq 0 ]; then err "--uninstall requires at least one item name."; return 1; fi
    for n in "$@"; do uninstall_dispatch "$n"; done
    return
  fi

  if [ $# -eq 0 ]; then
    interactive_pick
    return
  fi

  for arg in "$@"; do
    case "$arg" in
      all-skills)  while IFS= read -r s; do install_dispatch "$s"; done < <(list_skills) ;;
      all-agents)  while IFS= read -r a; do install_dispatch "$a"; done < <(list_agents) ;;
      all)         err "'all' is not supported — use 'all-skills' or 'all-agents' (or list items)."; return 1 ;;
      *)           install_dispatch "$arg" ;;
    esac
  done
}

main "$@"
echo
case "${TARGET:-}" in
  claude) info "Done. Restart Claude Code (or open a new session) so the items load." ;;
  cursor) info "Done. Cursor picks up AGENTS.md automatically — reopen the project if needed." ;;
  *)      info "Done." ;;
esac
