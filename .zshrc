# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"

# configuration of python and pip and bigquery of vscode
# NOTE: どちらかを空文字にすると動くのでよしなに
export PIP_CERT='/Library/Application Support/Netskope/STAgent/data/nscacert.pem'
# export PIP_CERT=''
# pip install使う時は必要だが、それ以外ではコメントアウトするように
# export REQUESTS_CA_BUNDLE='/Library/Application Support/Netskope/STAgent/data/nscacert.pem'
export REQUESTS_CA_BUNDLE=''
export NODE_EXTRA_CA_CERTS="$HOME/.config/netskope-root-ca.pem"

# path to pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

autoload -Uz colors; colors

# completion option
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'    # 補完候補で、大文字・小文字を区別しないで補完出来るようにするが、大文字を入力した場合は区別する
zstyle ':completion:*' ignore-parents parent pwd ..    # ../ の後は今いるディレクトリを補間しない
zstyle ':completion:*:default' menu select=1           # 補間候補一覧上で移動できるように
zstyle ':completion:*:cd:*' ignore-parents parent pwd  # 補間候補にカレントディレクトリは含めない
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}  # ファイル補完候補に色をつける

setopt auto_param_slash # ディレクトリ名の補完で末尾の / を自動的にふかし、次の補完に備える
setopt auto_param_keys  # カッコの自動補完
setopt auto_menu        # 補完キー連打で順に補完候補を自動で補完
setopt correct          # スペルミス訂正
setopt complete_in_word # 入力途中でも続きから補完
setopt no_beep          # ビープ音消去

# history
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

setopt share_history           # 履歴を他のシェルとリアルタイム共有する
setopt hist_ignore_all_dups    # 同じコマンドをhistoryに残さない
setopt hist_ignore_space       # historyに保存するときに余分なスペースを削除する
setopt hist_reduce_blanks      # historyに保存するときに余分なスペースを削除する
setopt hist_save_no_dups       # 重複するコマンドが保存されるとき、古い方を削除する
setopt inc_append_history      # 実行時に履歴をファイルに追加していく

# search history ctrl + r
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end

# alias 便利なコマンド群
alias ls='ls -F'
alias la='ls -Fa'
alias ll='ls -Flh'
alias lla='ls -Falh'
alias ..='cd ../'
alias ...='cd ../../'
alias dcom='docker-compose'
alias dk='docker'

# 日本語ファイル名を表示可能にする
setopt print_eight_bit

# 環境変数を補完
setopt AUTO_PARAM_KEYS

# Tabで選択できるように
zstyle ':completion:*:default' menu select=2


if [[ ! -f $HOME/.zi/bin/zi.zsh ]]; then
  print -P "%F{33}▓▒░ %F{160}Installing (%F{33}z-shell/zi%F{160})…%f"
  command mkdir -p "$HOME/.zi" && command chmod go-rwX "$HOME/.zi"
  command git clone -q --depth=1 --branch "main" https://github.com/z-shell/zi "$HOME/.zi/bin" && \
    print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
    print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi
source "$HOME/.zi/bin/zi.zsh"
autoload -Uz _zi
(( ${+_comps} )) && _comps[zi]=_zi
# examples here -> https://wiki.zshell.dev/ecosystem/category/-annexes
zicompinit # <- https://wiki.zshell.dev/docs/guides/commands


zinit light zsh-users/zsh-autosuggestions    # 補完
zinit light zdharma/fast-syntax-highlighting # シンタックスハイライト
zinit ice wait'0'; zinit light zsh-users/zsh-completions # コマンド補完
autoload -Uz compinit && compinit
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/kenta.suzuki/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# google cloud defalut project id
GOOGLE_CLOUD_PROJECT=indigo-medium-816
# bun completions
[ -s "/Users/kenta.suzuki/.bun/_bun" ] && source "/Users/kenta.suzuki/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

. "$HOME/.local/bin/env"
NOTION_API_KEY=your-notion-api-key
NOTION_API_KEY=ntn_l923177488422VnOdsZSE43WGcRApvT8Cc4Y7PYs7ng7O7

# Added by Antigravity
export PATH="/Users/kenta.suzuki/.antigravity/antigravity/bin:$PATH"

# Claude Code tools
export PATH="$HOME/.claude/bin:$PATH"
