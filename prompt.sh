function under_bash () {
	[[ "`ps -p $$ --no-headers -o comm`" == "bash" ]] 2>&1 && return
	return 1
}

function under_zsh () {
	[[ "`ps -p $$ --no-headers -o comm`" == "zsh" ]] 2>&1 && return
	return 1
}

msgp_color_red=$'\e[31m'
msgp_color_yellow=$'\e[33m'
msgp_color_green=$'\e[32m'
msgp_color_cyan=$'\e[36m'
msgp_color_blue=$'\e[34m'
msgp_color_magenta=$'\e[35m'
msgp_color_white=$'\e[37m'
msgp_color_bold_red=$'\e[31;1m'
msgp_color_bold_yellow=$'\e[33;1m'
msgp_color_bold_green=$'\e[36;1m'
msgp_color_bold_cyan=$'\e[32;1m'
msgp_color_bold_blue=$'\e[34;1m'
msgp_color_bold_magenta=$'\e[35;1m'
msgp_color_bold_white=$'\e[37;1m'
msgp_reset_color=$'\e[37m'

# edit colours and characters here
#############################################
if under_bash; then
	# msgp_user_color=$msgp_color_green - change the user to green
	msgp_user_color=$msgp_color_cyan
	msgp_host_color=$msgp_color_yellow
	msgp_root_color=$msgp_color_green
	msgp_repo_color=$msgp_color_red
	msgp_branch_color=$msgp_color_white
	msgp_dirty_color=$msgp_color_red
	msgp_preposition_color=$msgp_color_white
	msgp_promptchar_color=$msgp_color_magenta
elif under_zsh; then
	msgp_user_color=$msgp_color_magenta
	msgp_host_color=$msgp_color_yellow
	msgp_root_color=$msgp_color_green
	msgp_repo_color=$msgp_color_red
	msgp_branch_color=$msgp_color_white
	msgp_dirty_color=$msgp_color_red
	msgp_preposition_color=$msgp_color_white
	msgp_promptchar_color=$msgp_color_cyan
fi
msgp_promptchar_bash='$'
msgp_promptchar_zsh='%%' # the % character is special in zsh - escape with a preceding %
msgp_promptchar_git='±'
#############################################

# obtained from /usr/share/doc/git-1.8.1.2/contrib/completion/git-prompt.sh (as __gitdir)
function get_git_dir ()
{
	if [ -z "${1-}" ]; then
			if [ -n "${__git_dir-}" ]; then
					echo "$__git_dir"
			elif [ -n "${GIT_DIR-}" ]; then
					test -d "${GIT_DIR-}" || return 1
					echo "$GIT_DIR"
			elif [ -d .git ]; then
					echo .git
			else
					git rev-parse --git-dir 2>/dev/null
			fi
	elif [ -d "$1/.git" ]; then
			echo "$1/.git"
	else
			echo "$1"
	fi
}

function in_git_repo {
	get_git_dir 2>&1 1> /dev/null && return
	return 1
}

function in_repo {
	in_git_repo && return
	return 1
}

function prompt_char {
	in_git_repo && echo -ne $msgp_promptchar_git && return
	if under_bash; then
		echo $msgp_promptchar_bash
	elif under_zsh; then
		echo $msgp_promptchar_zsh
	fi
}

function get_repo_type {
	in_git_repo && echo -ne "git" && return
	return 1
}

function get_repo_branch {
	in_git_repo && echo $(git describe --contains --all HEAD 2>/dev/null) && return
	return 1
}

function get_repo_status {
	in_git_repo && git status --porcelain && return
	return 1
}

function get_repo_root {
	in_git_repo && echo $(git rev-parse --show-toplevel) && return
	return 1
}

function get_unversioned_repo_root {
	local lpath="$1"
	local cPWD=`echo $PWD`
	
	# see if $lpath is non-existent or empty, and if so, assign
	if test ! -s "$lpath"; then
		local lpath=`echo $PWD`
	fi
	
	cd "$lpath" &> /dev/null
	local repo_root="$(get_repo_root)"

	# see if $repo_root is non-existent or empty, and if so, assign
	if test ! -s "$repo_root"; then
		echo $lpath
	else
		local parent="${lpath%/*}"
		get_unversioned_repo_root "$parent"
	fi

	cd "$cPWD" &> /dev/null
}

# display current path
function ps_status {
	in_repo && repo_status && return
	echo -e "$msgp_root_color${PWD/#$HOME/~} $msgp_reset_color"
}

function repo_status {
	# set locations
	local here="$PWD"
	local user_root="$HOME"
	local repo_root="$(get_repo_root)"
	local root="`get_unversioned_repo_root`/"
	local lpath="${here/$root/}"
	if [[ "`echo $root`" =~ ^$user_root ]]; then
		root=`echo "$root" | sed "s:^$user_root:~:g"`
	fi

	# get branch information - empty if no (or default) branch
	local branch=$(get_repo_branch)

	# underline branch name
	if [[ $branch != '' ]]; then
		if under_zsh; then
			local branch=" on %{\033[4m%}${branch}%{\033[0m%}"
		elif under_bash; then
			local branch=" on \033[4m${branch}\033[0m"
		fi
	fi

	# status of current repo
	if in_git_repo; then
		local lstatus="`get_repo_status | sed 's/^/g/'`"
		local ahead="`git status | grep 'Your branch is ahead' | sed -Ee 's/^.* ([0-9]+) commit.*$/\1/'`"
		if [[ "$ahead" != '' ]]; then
			local branch="${branch}${msrp_preposition_color} + $ahead"
		fi
	else
		local lstatus=''
	fi

	local status_count=`echo "$lstatus" | wc -l | awk '{print $1}'`
	
	# if there's anything to report on...
	if [[ "$status_count" -gt 0 ]]; then

		local changes=""

		# modified file count
		local modified="$(echo "$lstatus" | grep -c '^g *M')"
		if [[ "$modified" -gt 0 ]]; then
			changes="$modified changed"
		fi
		
		# added file count
		local added="$(echo "$lstatus" | grep -c '^g *A')"
		if [[ "$added" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${added} added"
		fi
		
		# removed file count
		local removed="$(echo "$lstatus" | grep -c '^g *D')"
		if [[ "$removed" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${removed} removed"
		fi
		
		# renamed file count
		local renamed="$(echo "$lstatus" | grep -c '^g *R')"
		if [[ "$renamed" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${removed} renamed"
		fi
				
		# untracked file count
		local untracked="$(echo "$lstatus" | grep -c '^g *?')"
		if [[ "$untracked" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${untracked} untracked"
		fi
		
		# staged file count
		local staged="$(echo "$lstatus" | grep -c '^g[A-Z]')"
		if [[ "$staged" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${staged} staged"
		fi

		if [[ "$changes" != "" ]]; then
			changes=" (${changes})"
		fi
	fi

	echo -e "$msgp_root_color$root$msgp_repo_color$lpath$msgp_branch_color$branch$msgp_dirty_color$update$changes"
}

# obtained from /usr/share/doc/git-1.8.1.2/contrib/completion/git-prompt.sh (as __git_ps1)
function get_current_repo_action () {
	if in_git_repo; then
		local g="$(get_git_dir)"
		local action
		local branch
		if [ -f "$g/rebase-merge/interactive" ]; then
			branch=$(cat "$g/rebase-merge/head-name")
			if under_zsh; then
				branch="%{\033[4m%}${branch}%{\033[0m%}"
			elif under_bash; then
				branch="\033[4m${branch}\033[0m"
			fi
			action="interactive rebasing on ${branch}"
		elif [ -d "$g/rebase-merge" ]; then
			branch=$(cat "$g/rebase-merge/head-name")
			if under_zsh; then
				branch="%{\033[4m%}${branch}%{\033[0m%}"
			elif under_bash; then
				branch="\033[4m${branch}\033[0m"
			fi
			action="merge rebasing on ${branch}"
		else
			if [ -d "$g/rebase-apply" ]; then
				if [ -f "$g/rebase-apply/rebasing" ]; then
					action="rebasing"
				elif [ -f "$g/rebase-apply/applying" ]; then
					action="applying patch"
				else
					action="applying patch or rebasing"
				fi
			elif [ -f "$g/MERGE_HEAD" ]; then
					action="merging"
			elif [ -f "$g/CHERRY_PICK_HEAD" ]; then
					action="cherry-picking"
			elif [ -f "$g/BISECT_LOG" ]; then
					action="bisecting"
			fi
		fi
		if [ -n "$action" ]; then
			if under_zsh; then
				echo -e "$msgp_dirty_color$action$msgp_dirty_color%{$msgp_reset_color%}"
			elif under_bash; then
				echo -e "$msgp_dirty_color[$action$msgp_dirty_color]$msgp_reset_color"
			fi
		else
			echo -e "($(git rev-parse --short HEAD 2>/dev/null)) "
		fi
	else
		return 1
	fi
}

function construct_prompt () {
	echo -e "$msgp_user_color$USER ${msgp_preposition_color}at $msgp_host_color`hostname -s` ${msgp_preposition_color}in $(ps_status)$msgp_reset_color\n$(get_current_repo_action)$msgp_promptchar_color$(prompt_char)"
}

function get_last_status {
	local st="$?"
	if under_bash; then
		if [[ "$st" == "0" ]]; then
			echo -e "$msgp_color_green✔$reset_color "
		else
			echo -e "$msgp_color_red✖$reset_color "
		fi
	elif under_zsh; then
		echo -e "%(?.$msgp_color_green✔.$msgp_color_red✖)$reset_color "
	fi
}

if under_bash; then
	export PS1='$(get_last_status)$(construct_prompt)\[$msgp_reset_color\] '
elif under_zsh; then
	export PROMPT='$(get_last_status)$(construct_prompt)%{$msgp_reset_color%} '
fi
