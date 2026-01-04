source /opt/venv/bin/activate

export PS1="(venv) \u@\h:\w$ "
export TERM=xterm-256color
export COLUMNS=200

alias l='ls -CF'
alias ll='ls -alF --group-directories-first'
alias lh='ls -lh --group-directories-first'
alias du1='du -h --max-depth=1'
alias duh='du -sh * 2>/dev/null'
alias dfh='df -h'
alias k='kubectl'

source /etc/bash_completion
source <(kubectl completion bash)

if [ -z "$_ENV_INFO_SHOWN" ]; then
  export _ENV_INFO_SHOWN=1
  [ -f "$HOME/.env_info.sh" ] && bash "$HOME/.env_info.sh"
fi

