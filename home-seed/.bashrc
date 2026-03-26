# ~/.bashrc for claudevm VM

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Prompt: show user@host:dir with git branch if in a repo
git_branch() {
    git branch 2>/dev/null | sed -n 's/^\* //p'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(b=$(git_branch); [ -n "$b" ] && echo " \[\033[01;33m\]($b)\[\033[00m\]")\$ '

# Color ls
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Convenience
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'

# NVM (Node Version Manager) - installed per-user so claude can self-update
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# PATH: include ~/bin and common tool locations
export PATH="$HOME/bin:/usr/local/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

# Go
export GOPATH="$HOME/go"

# Editor
export EDITOR=emacs
export VISUAL=emacs

# Pager
export PAGER=less
export LESS='-R'

# Load local overrides if present
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
