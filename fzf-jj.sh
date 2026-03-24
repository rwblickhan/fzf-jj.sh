#!/usr/bin/env bash
# fzf-jj.sh - fzf integration for jujutsu (jj)
# Requires jj 0.21+ (for `jj file list` and `jj diff --name-only`)

# shellcheck disable=SC2039
[[ $0 == - ]] && return

__fzf_jj_color() {
  if [[ -n $NO_COLOR ]]; then
    echo never
  else
    echo "${FZF_JJ_COLOR:-always}"
  fi
}

__fzf_jj_cat() {
  if [[ -n $FZF_JJ_CAT ]]; then
    echo "$FZF_JJ_CAT"
    return
  fi

  local bat_opts="--style='${BAT_STYLE:-full}' --color=always --pager=never"
  if command -v batcat > /dev/null; then
    echo "batcat $bat_opts"
  elif command -v bat > /dev/null; then
    echo "bat $bat_opts"
  else
    echo cat
  fi
}

if [[ $1 == --list ]]; then
  shift
  set -e
  type=$1
  value=$2

  if [[ $type == remote ]]; then
    remote_url=$(jj git remote list 2>/dev/null | awk -v r="$value" '$1 == r {print $2}')
  else
    remote_url=$(jj git remote list 2>/dev/null | awk 'NR==1 {print $2}')
  fi

  if [[ $remote_url =~ ^git@ ]]; then
    url=${remote_url%.git}
    url=${url#git@}
    url=https://${url/://}
  elif [[ $remote_url =~ ^http ]]; then
    url=${remote_url%.git}
  fi

  case "$type" in
    commit)
      hash=$(jj log -r "$value" --no-graph -T 'commit_id.short(7) ++ "\n"' 2>/dev/null | head -n 1)
      path=/commit/$hash
      ;;
    branch) path=/tree/$value ;;
    tag)    path=/releases/tag/$value ;;
    remote) path= ;;
    *)      exit 1 ;;
  esac

  case "$OSTYPE" in
    darwin*)  open "$url$path" ;;
    msys)     start "$url$path" ;;
    linux*)
      if uname -a | grep -i -q Microsoft && command -v powershell.exe; then
        powershell.exe -NoProfile start "$url$path"
      else
        xdg-open "$url$path"
      fi
      ;;
    *) xdg-open "$url$path" ;;
  esac
  exit 0
fi

if [[ $- =~ i ]] || [[ $1 = --run ]]; then # ----------------------------------

if [[ $__fzf_jj_fzf ]]; then
  eval "$__fzf_jj_fzf"
else
  # Redefine this function to change the options
  _fzf_jj_fzf() {
    fzf --height 50% --tmux 90%,70% \
      --layout reverse --multi --min-height 20+ --border \
      --no-separator --header-border horizontal \
      --border-label-pos 2 \
      --color 'label:blue' \
      --preview-window 'right,50%' --preview-border line \
      --bind 'ctrl-/:change-preview-window(down,50%|hidden|)' "$@"
  }
fi

_fzf_jj_check() {
  jj root > /dev/null 2>&1 && return

  [[ -n $TMUX ]] && tmux display-message "Not in a jj repository"
  return 1
}

__fzf_jj=${BASH_SOURCE[0]:-${(%):-%x}}
__fzf_jj=$(readlink -f "$__fzf_jj" 2> /dev/null || /usr/bin/ruby --disable-gems -e 'puts File.expand_path(ARGV.first)' "$__fzf_jj" 2> /dev/null)

_fzf_jj_help() {
  local cmd
  cmd=$(printf '%-12s %-16s %s\n' \
    'bookmarks'  'ctrl-j ctrl-b'  'Browse bookmarks' \
    'files'      'ctrl-j ctrl-f'  'Browse files' \
    'log'        'ctrl-j ctrl-l'  'Browse revision log' \
    'ops'        'ctrl-j ctrl-o'  'Browse operation log' \
    'remotes'    'ctrl-j ctrl-r'  'Browse git remotes' \
    'tags'       'ctrl-j ctrl-t'  'Browse tags' \
    'workspaces' 'ctrl-j ctrl-w'  'Browse workspaces' \
  | fzf --height 50% --tmux 90%,70% \
      --layout reverse --no-multi --min-height 20+ --border \
      --no-separator --header-border horizontal \
      --border-label-pos 2 \
      --color 'label:blue' \
      --border-label '⌨ fzf-jj ' \
      --header 'Select a picker' \
      --no-preview \
  | awk '{print $1}')
  case "$cmd" in
    bookmarks)  _fzf_jj_bookmarks ;;
    files)      _fzf_jj_files ;;
    log)        _fzf_jj_log ;;
    ops)        _fzf_jj_ops ;;
    remotes)    _fzf_jj_remotes ;;
    tags)       _fzf_jj_tags ;;
    workspaces) _fzf_jj_workspaces ;;
  esac
}

_fzf_jj_log() {
  _fzf_jj_check || return
  local color pager
  color=$(__fzf_jj_color)
  pager="${PAGER:-less -R}"

  jj log --no-graph --color=never \
    -T 'change_id.short(8) ++ " " ++ if(description, description.first_line(), "(no description)") ++ "\n"' \
    2>/dev/null | \
    _fzf_jj_fzf \
      --border-label '📜 Log ' \
      --header 'CTRL-O (open in browser) ╱ CTRL-D (diff) ╱ ALT-E (describe) ╱ ALT-F (files)' \
      --bind "ctrl-o:execute-silent:bash \"$__fzf_jj\" --list commit {1}" \
      --bind "ctrl-d:execute:jj diff --color=$color -r {1} | $pager" \
      --bind "alt-e:execute:jj describe -r {1}" \
      --bind "alt-f:become:bash \"$__fzf_jj\" --run files --revision {1}" \
      --preview "jj show --color=$color {1} 2>/dev/null" \
      "$@" | \
    awk '{print $1}'
}

_fzf_jj_ops() {
  _fzf_jj_check || return
  local op_list
  op_list='jj op restore {1} 2>/dev/null; jj op log --no-graph --color=never -T '"'"'id.short(8) ++ " " ++ description ++ "\n"'"'"' 2>/dev/null'
  local color
  color=$(__fzf_jj_color)

  jj op log --no-graph --color=never \
    -T 'id.short(8) ++ " " ++ description ++ "\n"' \
    2>/dev/null | \
    _fzf_jj_fzf \
      --border-label '⚙ Operations ' \
      --header 'CTRL-X (restore to operation) ╱ ENTER to insert operation ID' \
      --bind "ctrl-x:reload($op_list)" \
      --preview "jj op show --color=$color {1} 2>/dev/null" \
      "$@" | \
    awk '{print $1}'
}

_fzf_jj_remotes() {
  _fzf_jj_check || return

  jj git remote list 2>/dev/null | \
    _fzf_jj_fzf \
      --border-label '🌐 Remotes ' \
      --header 'CTRL-O (open in browser) ╱ ENTER to insert remote name' \
      --bind "ctrl-o:execute-silent:bash \"$__fzf_jj\" --list remote {1}" \
      --preview "
        remote=\"\$(echo {} | awk '{print \$1}')\"
        jj bookmark list --all --color=$(__fzf_jj_color) 2>/dev/null | grep \"@\${remote}\"
      " "$@" | \
    awk '{print $1}'
}

_fzf_jj_bookmarks() {
  _fzf_jj_check || return
  local color
  color=$(__fzf_jj_color)

  jj bookmark list --color=$color 2>/dev/null | \
    grep -v '^\s' | \
    _fzf_jj_fzf \
      --border-label '🔖 Bookmarks ' \
      --header 'CTRL-O (open in browser) ╱ CTRL-X (delete bookmark) ╱ ENTER to insert bookmark name' \
      --ansi \
      --bind "ctrl-o:execute-silent:bash \"$__fzf_jj\" --list branch \$(echo {1} | cut -d: -f1)" \
      --bind "ctrl-x:reload(jj bookmark delete \$(echo {1} | cut -d: -f1) 2>/dev/null; jj bookmark list --color=$color 2>/dev/null | grep -v '^[[:space:]]')" \
      --preview "
        bookmark=\"\$(echo {} | cut -d: -f1)\"
        jj log --color=$color -r \"\$bookmark\" 2>/dev/null
      " "$@" | \
    cut -d: -f1
}

_fzf_jj_tags() {
  _fzf_jj_check || return
  local color
  color=$(__fzf_jj_color)

  jj tag list --color=$color 2>/dev/null | \
    _fzf_jj_fzf \
      --border-label '🏷 Tags ' \
      --header 'CTRL-O (open in browser) ╱ ENTER to insert tag name' \
      --ansi \
      --bind "ctrl-o:execute-silent:bash \"$__fzf_jj\" --list tag \$(echo {} | cut -d: -f1)" \
      --preview "
        tag=\"\$(echo {} | cut -d: -f1)\"
        jj log --color=$color -r \"\$tag\" 2>/dev/null
      " "$@" | \
    cut -d: -f1
}

_fzf_jj_workspaces() {
  _fzf_jj_check || return
  local color
  color=$(__fzf_jj_color)

  jj workspace list --color=$color 2>/dev/null | \
    _fzf_jj_fzf \
      --border-label '🗂 Workspaces ' \
      --header 'CTRL-X (forget workspace) ╱ ENTER to insert workspace name' \
      --ansi \
      --bind "ctrl-x:reload(jj workspace forget \$(echo {} | cut -d: -f1) 2>/dev/null; jj workspace list --color=$color 2>/dev/null)" \
      --preview "
        workspace=\"\$(echo {} | cut -d: -f1)\"
        jj log --color=$color -r \"\${workspace}@\" 2>/dev/null
      " "$@" | \
    cut -d: -f1
}

_fzf_jj_files() {
  _fzf_jj_check || return
  local root revision
  root=$(jj root 2>/dev/null)

  # Parse optional --revision flag
  if [[ ${1:-} == --revision ]] || [[ ${1:-} == -r ]]; then
    revision=$2
    shift 2
  fi

  local rev_flag=""
  [[ -n $revision ]] && rev_flag="-r $revision"

  # All lines use a consistent 3-char prefix so `cut -c4-` extracts the path:
  #   Changed files:   "{status}  path"  e.g. "M  src/foo.rs"
  #   Unchanged files: "   path"         e.g. "   src/bar.rs"
  #
  # `jj diff --summary` format: "{M|A|D} path"
  # Changed files are ordered: modified (M) first, then added (A), then deleted (D).
  local diff_summary
  # shellcheck disable=SC2086
  diff_summary=$(jj diff --summary --color=never $rev_flag 2>/dev/null)
  (
    printf '%s\n' "$diff_summary" | awk '
      { status=substr($0,1,1); path=substr($0,3) }
      status=="M" { m[++mc]=path }
      status=="A" { a[++ac]=path }
      status=="D" { d[++dc]=path }
      END {
        for (i=1; i<=mc; i++) printf "M  %s\n", m[i]
        for (i=1; i<=ac; i++) printf "A  %s\n", a[i]
        for (i=1; i<=dc; i++) printf "D  %s\n", d[i]
      }
    '
    # shellcheck disable=SC2086
    jj file list $rev_flag 2>/dev/null | \
      grep -vxFf <(
        printf '%s\n' "$diff_summary" | awk '{print substr($0,3)}'
        echo :
      ) | sed 's/^/   /'
  ) | \
    _fzf_jj_fzf -m \
      --border-label '📁 Files ' \
      --header 'ALT-E (open in editor)' \
      --bind "alt-e:execute:${EDITOR:-vim} \"\$(echo {} | cut -c4-)\"" \
      --preview "
        filepath=\"\$(echo {} | cut -c4-)\"
        diff_out=\"\$(cd \"$root\" && jj diff --color=$(__fzf_jj_color) $rev_flag -- \"\$filepath\" 2>/dev/null)\"
        if [ -n \"\$diff_out\" ]; then
          echo \"\$diff_out\"
          echo '────'
        fi
        $(__fzf_jj_cat) \"$root/\$filepath\" 2>/dev/null
      " "$@" | \
    cut -c4-
}

[[ $1 == --run ]] && shift
case "$1" in
  bookmarks)  _fzf_jj_bookmarks ;;
  files)      _fzf_jj_files "${@:2}" ;;
  help)       _fzf_jj_help ;;
  log)        _fzf_jj_log ;;
  ops)        _fzf_jj_ops ;;
  remotes)    _fzf_jj_remotes ;;
  tags)       _fzf_jj_tags ;;
  workspaces) _fzf_jj_workspaces ;;
esac

fi # -------------------------------------------------------------------------

if [[ $- =~ i ]]; then # ------------------------------------------------------
if [[ -n "${BASH_VERSION:-}" ]]; then
  __fzf_jj_init() {
    bind -m emacs-standard '"\er":  redraw-current-line'
    bind -m emacs-standard '"\C-z": vi-editing-mode'
    bind -m vi-command     '"\C-z": emacs-editing-mode'
    bind -m vi-insert      '"\C-z": emacs-editing-mode'

    local o c
    for o in "$@"; do
      c=${o:0:1}
      bind -m emacs-standard '"\C-j\C-'$c'": " \C-u \C-a\C-k`_fzf_jj_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-j\C-'$c'": "\C-z\C-j\C-'$c'\C-z"'
      bind -m vi-insert      '"\C-j\C-'$c'": "\C-z\C-j\C-'$c'\C-z"'
      bind -m emacs-standard '"\C-j'$c'":    " \C-u \C-a\C-k`_fzf_jj_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-j'$c'":    "\C-z\C-j'$c'\C-z"'
      bind -m vi-insert      '"\C-j'$c'":    "\C-z\C-j'$c'\C-z"'
    done
  }
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  __fzf_jj_join() {
    local item
    while read -r item; do
      echo -n -E "${(q)${(Q)item}} "
    done
  }

  __fzf_jj_init() {
    setopt localoptions no_glob
    local m o
    for o in "$@"; do
      eval "fzf-jj-$o-widget() { local result=\$(_fzf_jj_$o | __fzf_jj_join); zle reset-prompt; LBUFFER+=\$result }"
      eval "zle -N fzf-jj-$o-widget"
      for m in emacs vicmd viins; do
        eval "bindkey -M $m '^j^${o[1]}' fzf-jj-$o-widget"
        eval "bindkey -M $m '^j${o[1]}' fzf-jj-$o-widget"
      done
    done
  }
fi
__fzf_jj_init bookmarks files help log ops remotes tags workspaces

fi # --------------------------------------------------------------------------
