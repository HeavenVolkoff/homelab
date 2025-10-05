#!/usr/bin/env bash

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Limit permissions on files created by the shell to 0750 at most
umask 027

# https://github.com/mrzool/bash-sensible
_sensible="${XDG_DATA_HOME:-$HOME/.local/share}/sensible.bash"
[ -f "$_sensible" ] && . "$_sensible"
unset _sensible

# Set fancy PROMPT with colors in the case we dont have starship
PS1='\[\e]0;\u@\h: \w\a\]' # set window title
PS1+="\[\e[0;32m\]\u@\h "  # green user@host
PS1+="\[\e[0;34m\]\w"      # blue working directory
PS1+="\[\e[0m\]\$ "        # normal color $

# User specific bin path
if ! [[ "$PATH" =~ "${HOME}/.local/bin:" ]]; then
  PATH="${HOME}/.local/bin:$PATH"
fi
export PATH

# Read environment variables from environment.d
_envdir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
if [ -d "$_envdir" ]; then
  for _envfile in "${_envdir}/"*.conf; do
    [ -f "$_envfile" ] || continue
    . "$_envfile"
  done
fi
unset _envdir _envfile

# Set default editor to micro
export EDITOR='micro'
export VISUAL='micro'

# Startship prompt manager
command -v starship 2>/dev/null 1>&2 && eval "$(starship init bash)"

# Some convenient aliases
alias ls='ls --color=auto'
alias ll='ls --color=auto -lahc'
alias grep='grep --color=auto'
alias nano='micro'
alias wget='wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'

# Some convienient functions
man() {
  local width
  width=$(tput cols)
  [ "$width" -le "${MANWIDTH:-0}" ] || width=$MANWIDTH
  env MANWIDTH="$width" man "$@"
}
