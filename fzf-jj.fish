function __fzf_jj_sh
    # Get the absolute path to the directory containing this script so we can
    # call fzf-jj.sh without needing it on $PATH.
    set --function fzf_jj_sh_path (realpath (status dirname))

    commandline --insert (SHELL=bash bash "$fzf_jj_sh_path/fzf-jj.sh" --run $argv | string join ' ')
    commandline -f repaint
end

# Note: Ctrl-j (^J, 0x0A) is also newline/LF. Fish treats chord prefixes with
# a short timeout before falling back to the single-key binding, so regular
# Enter (which sends ^M/CR, not ^J) is unaffected. Rapid ^J presses may have
# a brief delay. If this causes issues, rebind to a different chord prefix.
#
# Each command is bound to both ctrl-j ctrl-{key} and ctrl-j {key} (lowercase).
# Use the lowercase variant as a workaround if ctrl-{key} conflicts with another
# binding (e.g. ctrl-b for the tmux prefix).
set --local commands help bookmarks log ops remotes files tags workspaces

for command in $commands
    set --function key (string sub --length=1 $command)

    eval "bind -M default \cj$key   '__fzf_jj_sh $command'"
    eval "bind -M insert  \cj$key   '__fzf_jj_sh $command'"
    eval "bind -M default \cj\c$key '__fzf_jj_sh $command'"
    eval "bind -M insert  \cj\c$key '__fzf_jj_sh $command'"
end
