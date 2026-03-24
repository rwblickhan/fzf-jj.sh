# fzf-jj.sh

A faithful reimplementation of junegunn's [fzf-git.sh](https://github.com/junegunn/fzf-git.sh) to operate on [jj](https://github.com/jj-vcs/jj) (jujutsu) objects using [fzf](https://github.com/junegunn/fzf).

> [!WARNING]
> This was largely vibe-coded with Claude Code (though I did look over the code as a spotcheck). It works well in practice for my personal use, but do NOT assume it is production-grade software!

## Installation

- Install the latest version of [fzf](https://github.com/junegunn/fzf)
  - (Optional) Install [bat](https://github.com/sharkdp/bat) for
    syntax-highlighted file previews
- Install the latest version of [jj](https://github.com/jj-vcs/jj)
  - jj v0.21+ is required
- Update your shell configuration file
  - bash or zsh
    - Source [fzf-jj.sh](https://raw.githubusercontent.com/rwblickhan/fzf-jj.sh/refs/heads/main/fzf-jj.sh) from your .bashrc or .zshrc
  - fish
    - Source [fzf-jj.fish](https://raw.githubusercontent.com/rwblickhan/fzf-jj.sh/refs/heads/main/fzf-jj.fish) from your config.fish

## Usage

### List of bindings

- <kbd>CTRL-J</kbd><kbd>CTRL-H</kbd> for **H**elp
- <kbd>CTRL-J</kbd><kbd>CTRL-F</kbd> for **F**iles
- <kbd>CTRL-J</kbd><kbd>CTRL-B</kbd> for **B**ookmarks
- <kbd>CTRL-J</kbd><kbd>CTRL-L</kbd> for **L**og
- <kbd>CTRL-J</kbd><kbd>CTRL-O</kbd> for **O**plog
- <kbd>CTRL-J</kbd><kbd>CTRL-R</kbd> for **R**emotes
- <kbd>CTRL-J</kbd><kbd>CTRL-T</kbd> for **T**ags
- <kbd>CTRL-J</kbd><kbd>CTRL-W</kbd> for **W**orkspaces

> [!WARNING]
> As with the original fzf-git.sh, you may have the following issues:
>
> - If you use tmux, <kbd>CTRL-B</kbd> will conflict with the default tmux prefix.
> - zsh's `KEYTIMEOUT` needs to be high enough for you to hit two keys in a row.

### Inside fzf

- <kbd>TAB</kbd> or <kbd>SHIFT-TAB</kbd> to select multiple objects
- <kbd>CTRL-/</kbd> to change preview window layout
- <kbd>CTRL-O</kbd> to open the object in the web browser (in GitHub URL scheme)

## Customization

As with fzf-git.sh, there's a single function to redefine to change the options:

```sh
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
```

There's also an environment variable you can pass:

| Variable    | Description                                          | Default |
| ----------- | ---------------------------------------------------- | ------- |
| `BAT_STYLE` | Specifies the style for displaying files using `bat` | `full`  |

Also, as with fzf-git.sh, every binding is backed by a `_fzf_jj_*` function that you can use directly in your shell config file.
