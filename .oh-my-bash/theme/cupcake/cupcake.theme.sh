#! bash oh-my-bash.module

# Emoji-based theme to display source control management and
# virtual environment info beside the ordinary bash prompt.

# Theme inspired by:
#  - Naming your Terminal tabs in OSX Lion - http://thelucid.com/2012/01/04/naming-your-terminal-tabs-in-osx-lion/
#  - Bash_it sexy theme

# Demo:
# ┌ⓔ virtualenv 🧑user @ 🌐host in 📂directory on 🌿branch {1} ↑1 ↓1 +1 •1 ⌀1 ✗
# └❯ cd .bash-it/themes/cupcake

# virtualenv prompts
VIRTUALENV_CHAR="ⓔ "
OMB_PROMPT_VIRTUALENV_FORMAT='%s'
OMB_PROMPT_SHOW_PYTHON_VENV=${OMB_PROMPT_SHOW_PYTHON_VENV:=true}

# SCM prompts
SCM_NONE_CHAR=""
SCM_GIT_CHAR="[±] "
SCM_GIT_BEHIND_CHAR="${_omb_prompt_brown}↓${_omb_prompt_brown}"
SCM_GIT_AHEAD_CHAR="${_omb_prompt_bold_green}↑${_omb_prompt_bold_green}"
SCM_GIT_UNTRACKED_CHAR="⌀"
SCM_GIT_UNSTAGED_CHAR="${_omb_prompt_bold_olive}•${_omb_prompt_bold_olive}"
SCM_GIT_STAGED_CHAR="${_omb_prompt_bold_green}+${_omb_prompt_bold_green}"

SCM_THEME_PROMPT_DIRTY=""
SCM_THEME_PROMPT_CLEAN=""
SCM_THEME_PROMPT_PREFIX=""
SCM_THEME_PROMPT_SUFFIX=""

# Git status prompts
GIT_THEME_PROMPT_DIRTY=" ${_omb_prompt_brown}✗${_omb_prompt_normal}"
GIT_THEME_PROMPT_CLEAN=" ${_omb_prompt_bold_green}✓${_omb_prompt_normal}"
GIT_THEME_PROMPT_PREFIX=""
GIT_THEME_PROMPT_SUFFIX=""

# ICONS =======================================================================

icon_start="┌"
icon_user=""
icon_host=""
icon_directory="  "
icon_branch="" 
icon_end="└())==D "

# extra spaces ensure legibility in prompt

# FUNCTIONS ===================================================================

# Rename tab
function tabname {
  printf '\e]1;%s\a' "$1"
}

# Rename window
function winname {
  printf '\e]2;%s\a' "$1"
}

# PROMPT OUTPUT ===============================================================
function __cupcake_format_duration {
  local duration=$1
  local seconds=$((duration / 1000))
  local milliseconds=$((duration % 1000))
  local minutes=$((seconds / 60 % 60))
  local hours=$((seconds / 3600))

  if ((hours > 0)); then
    echo "${hours}h ${minutes}m ${seconds}s ${milliseconds}ms"
  elif ((minutes > 0)); then
    echo "${minutes}m ${seconds}s ${milliseconds}ms"
  elif ((seconds > 0)); then
    echo "${seconds}s ${milliseconds}ms"
  else
    echo "${milliseconds}ms"
  fi
}

export LAST_COMMAND_TIME=0
export LAST_COMMAND_START_TIME_MS=$(date +%s%3N)
trap 'LAST_COMMAND_START_TIME_MS=$(date +%s%3N)' DEBUG

function __cupcake_prompt_cmd_duration {
  local duration_ms=$(( $(date +%s%3N) - $LAST_COMMAND_START_TIME_MS ))
  local runtime=$(__cupcake_format_duration $duration_ms)
  echo " took ${_omb_prompt_bold_red}$runtime${_omb_prompt_normal} "
}

# Displays the current prompt
function _omb_theme_PROMPT_COMMAND() {
  local duration_info=$(__cupcake_prompt_cmd_duration)

  PS1='\n'$icon_start$(_omb_prompt_print_python_venv)
  PS1+=$icon_user$_omb_prompt_bold_brown'\u'
  PS1+=$_omb_prompt_normal$icon_host$_omb_prompt_bold_teal'\h'
  PS1+=$_omb_prompt_bold_yellow$icon_directory$_omb_prompt_bold_yellow'\W '
  PS1+=$_omb_prompt_normal$([[ -n $(_omb_prompt_git branch 2> /dev/null) ]] && _omb_util_print " on ${_omb_prompt_bold_green}$icon_branch ")
  PS1+=$_omb_prompt_bold_green$(scm_prompt_info)$_omb_prompt_normal$duration_info'\n'$icon_end
  PS2=$icon_end
}

# Runs prompt (this bypasses oh-my-bash $PROMPT setting)
_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND
