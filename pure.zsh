# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# git:
# %b => current branch
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# $color_reset => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


local color_reset="%{$reset_color%}"
local color_white="%F{231}"
local color_orange="%F{208}"
local color_green="%F{148}"
local color_green="%F{203}"

local color_pwd="%{%B%F{84}%}"
local color_git="%{%B%F{141}%}"
local color_virtualenv="%{%B%F{228}%}"

local color_prompt_char_1="%F{57}"
local color_prompt_char_2="%F{129}"
local color_prompt_char_3="%F{198}"

local char_prompt=" $color_prompt_char_1❯$color_prompt_char_2❯$color_prompt_char_3❯$color_reset "
local char_shit="💩 "
local char_left_bracket="$color_white〈$color_reset"
local char_right_bracket="$color_white 〉$color_reset"

# local color_git="%F{141}"
# local color_virtualenv="%F{228}"


# turns seconds into human readable time
# 165392 => 1d2156m32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_pure_human_time_to_var() {
	local human=" " total_seconds=$1 var=$2

    local color_short="%{%B%F{green}%}"
    local color_medium="%{%B%F{yellow}%}"
    local color_long="%{%B%F{red}%}"
    if [[ $total_seconds -lt 601 ]]; then
        local color_period="$color_short"
    elif [[ $total_seconds -lt 7201 ]]; then
        local color_period="$color_medium"
    else
        local color_period="$color_long"
    fi

	local days=$(( total_seconds / 60 / 60 / 24 ))
	local hours=$(( total_seconds / 60 / 60 % 24 ))
	local minutes=$(( total_seconds / 60 % 60 ))
	local seconds=$(( total_seconds % 60 ))

    human+="$color_period"
	(( days > 0 )) && human+="${days}d"
	(( hours > 0 )) && human+="${hours}h"
	(( minutes > 0 )) && human+="${minutes}m"
	human+="${seconds}s$color_reset"

	# store human readable time in variable as specified by caller
	typeset -g "${var}"="${human}"
}

# stores (into prompt_pure_cmd_exec_time) the exec time of the last command if set threshold was exceeded
prompt_pure_check_cmd_exec_time() {
	integer elapsed
	(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
	prompt_pure_cmd_exec_time=
	(( elapsed > ${PURE_CMD_MAX_EXEC_TIME:=5} )) && {
		prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
	}
}

prompt_pure_clear_screen() {
	# enable output to terminal
	zle -I
	# clear screen and move cursor to (0, 0)
	print -n '\e[2J\e[0;0H'
	# print preprompt
	prompt_pure_preprompt_render precmd
}

prompt_pure_check_pwd() {
    prompt_pure_pwd=
    if [[ -w $PWD ]]; then
        prompt_pure_pwd="$char_left_bracket $color_pwd%~$color_reset $char_right_bracket"
    else
        prompt_pure_pwd="$char_left_bracket %F{red}%~$color_reset $char_right_bracket"
    fi
}


prompt_pure_check_git_commit_time() {
    prompt_pure_git_commit_time=

    # determine the time since last commit. If branch is clean,
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # only proceed if there is actually a commit.
        if [[ $(git log 2>&1 > /dev/null | grep -c "^fatal: bad default revision") == 0 ]]; then
            # get the last commit.
            last_commit=$(git log --pretty=format:'%at' -1 2> /dev/null)
            now=$(date +%s)
            seconds_since_last_commit=$((now-last_commit))

            prompt_pure_git_commit_time=
            {
                prompt_pure_human_time_to_var $seconds_since_last_commit "prompt_pure_git_commit_time"
            }
        fi
    fi
}

prompt_pure_check_git_arrows() {
	# reset git arrows
	prompt_pure_git_arrows=

	# check if there is an upstream configured for this branch
	command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

	local arrow_status
	# check git left and right arrow_status
	arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
	# exit if the command failed
	(( !$? )) || return

	# left and right are tab-separated, split on tab and store as array
	arrow_status=(${(ps:\t:)arrow_status})
	local arrows left=${arrow_status[1]} right=${arrow_status[2]}

	(( ${right:-0} > 0 )) && arrows+="${PURE_GIT_DOWN_ARROW:-⇣}"
	(( ${left:-0} > 0 )) && arrows+="${PURE_GIT_UP_ARROW:-⇡}"

	[[ -n $arrows ]] && prompt_pure_git_arrows=" ${arrows}"
}

prompt_pure_set_title() {
	# emacs terminal does not support settings the title
	(( ${+EMACS} )) && return

	# tell the terminal we are setting the title
	print -n '\e]0;'
	# show hostname if connected through ssh
	[[ -n $SSH_CONNECTION ]] && print -Pn '(%m) '
	case $1 in
		expand-prompt)
			print -Pn $2;;
		ignore-escape)
			print -rn $2;;
	esac
	# end set title
	print -n '\a'
}

prompt_pure_check_virtualenv_name() {
    prompt_pure_virtualenv_name=

    virtualenv_name=$(basename "$VIRTUAL_ENV")
    if [[ "$virtualenv_name" != "" ]]; then
        prompt_pure_virtualenv_name="$char_left_bracket 🐍 $color_virtualenv$virtualenv_name$color_reset $char_right_bracket"
    fi
}

prompt_pure_check_battery() {
    battery_status=

    # get the battery status as int
    local battery=`ioreg -n AppleSmartBattery -r | awk '$1~/Capacity/{c[$1]=$3} END{OFMT="%.0f"; max=c["\"MaxCapacity\""]; print (max>0? 100*c["\"CurrentCapacity\""]/max: "?")}'`

    # determine how many full bars to draw
    local bars=0
    if [[ $battery == 100 ]]; then
        local bars=10
    elif [[ $battery -gt 90 ]]; then
        local bars=9
    elif [[ $battery -gt 80 ]]; then
        local bars=8
    elif [[ $battery -gt 70 ]]; then
        local bars=7
    elif [[ $battery -gt 60 ]]; then
        local bars=6
    elif [[ $battery -gt 50 ]]; then
        local bars=5
    elif [[ $battery -gt 40 ]]; then
        local bars=4
    elif [[ $battery -gt 30 ]]; then
        local bars=3
    elif [[ $battery -gt 20 ]]; then
        local bars=2
    elif [[ $battery -gt 10 ]]; then
        local bars=1
    elif [[ $battery -lt 10 ]]; then
        local bars=0
    fi

    # fill
    local full="${(l:$bars::|:)}"
    local empty="${(l:10-$bars::|:)}"

    battery_status="$char_left_bracket 🔋 %F{green}${full}%F{red}${empty}$color_reset $char_right_bracket"
}

prompt_pure_preexec() {
	# attempt to detect and prevent prompt_pure_async_git_fetch from interfering with user initiated git or hub fetch
	[[ $2 =~ (git|hub)\ .*(pull|fetch) ]] && async_flush_jobs 'prompt_pure'

	prompt_pure_cmd_timestamp=$EPOCHSECONDS

	# shows the current dir and executed command in the title while a process is active
	# prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"
}

# string length ignoring ansi escapes
prompt_pure_string_length_to_var() {
	local str=$1 var=$2 length
	# perform expansion on str and check length
	length=$(( ${#${(S%%)str//(\%([KF1]|)\{*\}|\%[Bbkf])}} ))

	# store string length in variable as specified by caller
	typeset -g "${var}"="${length}"
}

prompt_pure_preprompt_render() {
	# check that no command is currently running, the preprompt will otherwise be rendered in the wrong place
	[[ -n ${prompt_pure_cmd_timestamp+x} && "$1" != "precmd" ]] && return

	# set color for git branch/dirty status, change color if dirty checking has been delayed
	local git_color=$color_git
	[[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && git_color=red

	# construct preprompt, beginning with path
	# local preprompt="[%F{blue} %~$color_reset ]"
    local preprompt="$prompt_pure_pwd"

	# git info
    git_part="${vcs_info_msg_0_}${prompt_pure_git_dirty}"
	# git pull/push arrows
	git_part+="${prompt_pure_git_arrows}"

	git_part+="${prompt_pure_git_commit_time}"


    if [[ $git_part != '' ]]; then
        preprompt+=" $char_left_bracket$color_git$git_part$color_reset $char_right_bracket "
    fi

    preprompt+=""

	# username and machine if applicable
	preprompt+=$prompt_pure_username
	# execution time
	preprompt+="%F{yellow}${prompt_pure_cmd_exec_time}$color_reset"

	# if executing through precmd, do not perform fancy terminal editing
	if [[ "$1" == "precmd" ]]; then
		print -P "\n${preprompt}"
	else
		# only redraw if preprompt has changed
		[[ "${prompt_pure_last_preprompt}" != "${preprompt}" ]] || return

		# calculate length of preprompt and store it locally in preprompt_length
		integer preprompt_length lines
		prompt_pure_string_length_to_var "${preprompt}" "preprompt_length"

		# calculate number of preprompt lines for redraw purposes
		(( lines = ( preprompt_length - 1 ) / COLUMNS + 1 ))

		# calculate previous preprompt lines to figure out how the new preprompt should behave
		integer last_preprompt_length last_lines
		prompt_pure_string_length_to_var "${prompt_pure_last_preprompt}" "last_preprompt_length"
		(( last_lines = ( last_preprompt_length - 1 ) / COLUMNS + 1 ))

		# clr_prev_preprompt erases visual artifacts from previous preprompt
		local clr_prev_preprompt
		if (( last_lines > lines )); then
			# move cursor up by last_lines, clear the line and move it down by one line
			clr_prev_preprompt="\e[${last_lines}A\e[2K\e[1B"
			while (( last_lines - lines > 1 )); do
				# clear the line and move cursor down by one
				clr_prev_preprompt+='\e[2K\e[1B'
				(( last_lines-- ))
			done

			# move cursor into correct position for preprompt update
			clr_prev_preprompt+="\e[${lines}B"
		# create more space for preprompt if new preprompt has more lines than last
		elif (( last_lines < lines )); then
			# move cursor using newlines because ansi cursor movement can't push the cursor beyond the last line
			printf $'\n'%.0s {1..$(( lines - last_lines ))}
		fi

		# disable clearing of line if last char of preprompt is last column of terminal
		local clr='\e[K'
		(( COLUMNS * lines == preprompt_length )) && clr=

		# modify previous preprompt
		print -Pn "${clr_prev_preprompt}\e[${lines}A\e[${COLUMNS}D${preprompt}${clr}\n"

		# redraw prompt (also resets cursor position)
		zle && zle .reset-prompt
	fi

    RPROMPT="${prompt_pure_virtualenv_name} ${battery_status}"

	# store previous preprompt for comparison
	prompt_pure_last_preprompt=$preprompt
}

prompt_pure_precmd() {
	# check exec time and store it in a variable
	prompt_pure_check_cmd_exec_time

	# by making sure that prompt_pure_cmd_timestamp is defined here the async functions are prevented from interfering
	# with the initial preprompt rendering
	prompt_pure_cmd_timestamp=

    prompt_pure_check_pwd

	# check for git arrows
	prompt_pure_check_git_arrows

	prompt_pure_check_git_commit_time

    prompt_pure_check_virtualenv_name

    prompt_pure_check_battery

	# shows the full path in the title
	# prompt_pure_set_title 'expand-prompt' '%~'

	# get vcs info
	vcs_info

	# preform async git dirty check and fetch
	prompt_pure_async_tasks

	# print the preprompt
	prompt_pure_preprompt_render "precmd"

	# remove the prompt_pure_cmd_timestamp, indicating that precmd has completed
	unset prompt_pure_cmd_timestamp
}

# fastest possible way to check if repo is dirty
prompt_pure_async_git_dirty() {
	local untracked_dirty=$1; shift

	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q "$*"

	if [[ "$untracked_dirty" == "0" ]]; then
		command git diff --no-ext-diff --quiet --exit-code
	else
		test -z "$(command git status --porcelain --ignore-submodules -unormal)"
	fi

	(( $? )) && echo "○%F{white}●$color_reset"
}

prompt_pure_async_git_fetch() {
	# use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	builtin cd -q "$*"

	# set GIT_TERMINAL_PROMPT=0 to disable auth prompting for git fetch (git 2.3+)
	GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch
}

prompt_pure_async_tasks() {
	# initialize async worker
	((!${prompt_pure_async_init:-0})) && {
		async_start_worker "prompt_pure" -u -n
		async_register_callback "prompt_pure" prompt_pure_async_callback
		prompt_pure_async_init=1
	}

	# store working_tree without the "x" prefix
	local working_tree="${vcs_info_msg_1_#x}"

	# check if the working tree changed (prompt_pure_current_working_tree is prefixed by "x")
	if [[ ${prompt_pure_current_working_tree#x} != $working_tree ]]; then
		# stop any running async jobs
		async_flush_jobs "prompt_pure"

		# reset git preprompt variables, switching working tree
		unset prompt_pure_git_dirty
		unset prompt_pure_git_last_dirty_check_timestamp

		# set the new working tree and prefix with "x" to prevent the creation of a named path by AUTO_NAME_DIRS
		prompt_pure_current_working_tree="x${working_tree}"
	fi

	# only perform tasks inside git working tree
	[[ -n $working_tree ]] || return

	# do not preform git fetch if it is disabled or working_tree == HOME
	if (( ${PURE_GIT_PULL:-1} )) && [[ $working_tree != $HOME ]]; then
		# tell worker to do a git fetch
		async_job "prompt_pure" prompt_pure_async_git_fetch "${working_tree}"
	fi

	# if dirty checking is sufficiently fast, tell worker to check it again, or wait for timeout
	integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_pure_git_last_dirty_check_timestamp:-0} ))
	if (( time_since_last_dirty_check > ${PURE_GIT_DELAY_DIRTY_CHECK:-1800} )); then
		unset prompt_pure_git_last_dirty_check_timestamp
		# check check if there is anything to pull
		async_job "prompt_pure" prompt_pure_async_git_dirty "${PURE_GIT_UNTRACKED_DIRTY:-1}" "${working_tree}"
	fi
}

prompt_pure_async_callback() {
	local job=$1
	local output=$3
	local exec_time=$4

	case "${job}" in
		prompt_pure_async_git_dirty)
			prompt_pure_git_dirty=$output
			prompt_pure_preprompt_render

			# When prompt_pure_git_last_dirty_check_timestamp is set, the git info is displayed in a different color.
			# To distinguish between a "fresh" and a "cached" result, the preprompt is rendered before setting this
			# variable. Thus, only upon next rendering of the preprompt will the result appear in a different color.
			(( $exec_time > 2 )) && prompt_pure_git_last_dirty_check_timestamp=$EPOCHSECONDS
			;;
		prompt_pure_async_git_fetch)
            prompt_pure_check_pwd
			prompt_pure_check_git_arrows
            prompt_pure_check_git_commit_time
            prompt_pure_check_virtualenv_name
            prompt_pure_check_battery
			prompt_pure_preprompt_render
			;;
	esac
}

prompt_pure_setup() {
	# prevent percentage showing up
	# if output doesn't end with a newline
	export PROMPT_EOL_MARK=''

	prompt_opts=(subst percent)

	zmodload zsh/datetime
	zmodload zsh/zle
	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	autoload -Uz async && async

	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec

	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' use-simple true
	# only export two msg variables from vcs_info
	zstyle ':vcs_info:*' max-exports 2
	# vcs_info_msg_0_ = ' %b' (for branch)
	# vcs_info_msg_1_ = 'x%R' git top level (%R), x-prefix prevents creation of a named path (AUTO_NAME_DIRS)
	zstyle ':vcs_info:git*' formats ' %b' 'x%R'
	zstyle ':vcs_info:git*' actionformats ' %b|%a' 'x%R'

	# if the user has not registered a custom zle widget for clear-screen,
	# override the builtin one so that the preprompt is displayed correctly when
	# ^L is issued.
	if [[ $widgets[clear-screen] == 'builtin' ]]; then
		zle -N clear-screen prompt_pure_clear_screen
	fi

	# show username@host if logged in through SSH
	[[ "$SSH_CONNECTION" != '' ]] && prompt_pure_username=' %F{242}%n@%m$color_reset'

	# show username@host if root, with username in white
	[[ $UID -eq 0 ]] && prompt_pure_username=' %F{white}%n$color_reset%F{242}@%m$color_reset'

	# prompt turns red if the previous command didn't exit with 0
	PROMPT="%(?.$char_prompt.$char_shit) "
    # PS2='[ %{%B%F{yellow}%}%_$color_reset ] '
}

# disable the default virtualenv info
export VIRTUAL_ENV_DISABLE_PROMPT=yes
prompt_pure_setup "$@"
