#!/usr/bin/env bash

# cSpell:ignore hsts lahc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific bin path
if ! [[ "$PATH" =~ "${HOME}/.local/bin:" ]]; then
  PATH="${HOME}/.local/bin:$PATH"
fi
export PATH

# Read environment variables from environment.d
_generator="/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator"
if command -v "$_generator" >/dev/null; then
  while IFS='=' read -r _key _value; do
    export "$_key"="$_value"
  done < <("$_generator")
fi
unset _generator _key _value

# If not running interactively, don't continue
[[ $- != *i* ]] && return

# Limit permissions on files created by the shell to 0750 at most
umask 027

# https://github.com/mrzool/bash-sensible
_sensible="${XDG_DATA_HOME:-$HOME/.local/share}/sensible.bash"
[ -f "$_sensible" ] && . "$_sensible"
unset _sensible

# Set fancy PROMPT with colors in the case we don't have starship
PS1='\[\e]0;\u@\h: \w\a\]' # set window title
PS1+="\[\e[0;32m\]\u@\h "  # green user@host
PS1+="\[\e[0;34m\]\w"      # blue working directory
PS1+="\[\e[0m\]\$ "        # normal color $

# Set default editor to micro
export EDITOR='micro'
export VISUAL='micro'

# Startship prompt manager (except when running under the linux console)
if [ "$TERM" != "linux" ]; then
  command -v starship &>/dev/null && eval "$(starship init bash)"
fi

# Some convenient aliases
alias ls='ls --color=auto'
alias ll='ls --color=auto -lahc' #
alias grep='grep --color=auto'
alias nano='micro'
alias wget='wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'

# Some convenient functions
man() {
  local width
  width=$(tput cols)
  [ "$width" -le "${MANWIDTH:-0}" ] || width=$MANWIDTH
  env MANWIDTH="$width" man "$@"
}
