#!/bin/sh

# 'errexit', 'nounset', 'noglob'.
set -euf

readonly newline='
'
#readonly save_pipe=8
#readonly save_stdout=9
readonly ps_e0="ERROR: $0"
readonly ps_w0="Warning: $0"

# Functions bkp_file_X() are basic operations on backup filename. When you
# change format of backup file name, you must change _all_ these functons
# accordingly.

bkp_file_name()
{
    # Backup file name.
    # Args: 1 - filename (with or without path does not matter).
    # Stdout: backup file name.
    echo "${1}.orig.$$"
}

bkp_file_rx()
{
    # Shell pattern to match all backups of this file, created by different
    # processes.
    # Args: 1 - filename (with or without path does not matter).
    # Stdout: shell pattern.
    echo "${1}.orig.*"
}

bkp_file_pid()
{
    # PID of backup file creator's process.
    # Args: 1 - backup filename (with or without path does not matter).
    # Stdout: creator's PID.
    echo "${1##*.}"
}


# FIXME: $PID reused?
create_bkp()
{
    # Create backup file (also check whether it is already exist).
    # 1 - file to backup.
    local OIFS="$IFS"
    local func='create_bkp()'
    local ps_e="$ps_e0: $func"
    local ps_w="$ps_w0: $func"

    local f="$1"	    # Filename with path!
    local d="$(dirname "$f")"
    local nf="$(basename "$f")"
    local brx="$(bkp_file_rx "$nf")"
    local bfs='' b='' p='' c=''
    local reply=''
    # If you add more possible answers, add corresponding branch in `case`
    # below.
    local user_answers='yes
no'

    bfs="$(find "$d" -maxdepth 1 -type f -name "$brx")"
    if [ -n "$bfs" ]; then
	echo "$ps_w: Backup file(s) already exists." 1>&2
	IFS="$newline"
	for b in $bfs; do   # Filenames with path!
	    p="$(bkp_file_pid "$b")"
	    c="$(ps --no-heading -o cmd -p "$p" || true)"
	    diff -s -u "$b" "$f" || true
	    if [ -n "$c" ]; then
		echo "$ps_e: Process '$c' with PID '$p', which created file '$b', still running." 1>&2
		return 1
	    fi
	    IFS="$OIFS"	    # $bfs already expanded.
	    reply="$(ask_user "## What should i do with backup file '$b'?" \
			      "$user_answers")" \
		    || return 1
	    case "$reply" in
	      'delete' ) rm -v "$b" ;;
	      'ignore' ) continue ;;
	      * ) echo "$ps_e: No such answer: '$reply'. Probably, this is missed 'case' branch." 1>&2
		  return 1
		  ;;
	    esac
	done
	IFS="$OIFS"
    fi
    b="$(bkp_file_name "$f")"
    cp -avT "$f" "$b"
    echo "$b"
}

rm_bkp()
{
    # 1 - file, which backup to remove.
    local OIFS="$IFS"
    local func='create_bkp()'
    local ps_e="$ps_e0: $func"
    local ps_w="$ps_w0: $func"

    local f="$1"
    local bf="$(bkp_file_name "$f")"
    if [ ! -f "$bf" ]; then
	echo "$ps_e: Backup file '$bf' does not exist."
	return 1
    fi
    echo "Removing backup files."
    rm -vi "$bf"
}

ask_user()
{
    # Ask user and match reply as prefix against list of correct answers. Quit
    # answer added to all prompts and processed here.
    # 1 - prompt.
    # 2 - all possible answers.
    # Stdout: matched answer (line) from possible answers list.
    local OIFS="$IFS"
    local func='ask_user()'
    local ps_e="$ps_e0: $func"
    local ps_w="$ps_w0: $func"

    local p="$1"
    # Add 'quit' and ensure, that there is no duplicates, because replies
    # matching more, than one answer, are not accepted.
    local xs="$(echo "$2${newline}quit" | sort -u)"
    local reply=''

    # Join answers into one line and add to the prompt.
    p="$p ($(echo "$xs" | sed -ne 'H; ${ x; s/\n//; s/\n/, /gp; };')): "
    while [ 0 ]; do
	read -r -p "$p" reply
	# If reply contains grep's special character result will be
	# unpredictable, so i use `grep -F`: for prefix match i need to first
	# truncate all answers to reply length and then match whole line.
	# Because `cut -c` works on bytes (not characters), i use `sed`.
	if [ -z "$reply" ]; then
	    continue
	fi
	l="$(echo "$reply" | wc -m)"	# length + 1 (due to newline)
	# Below i replace (length + 1) character with newline and print only
	# first line.
	res="$(echo "$xs"			    \
			| sed -e "s/./\n/$l; P; d;" \
			| grep -nFx -e "$reply"     \
		    || true
		)"

	if [ -z "$res" ]; then
	    echo "No one matches." 1>&2
	elif [ "$(echo -n "$res" | wc -l)" != 0 ]; then
	    echo "More, than one matches." 1>&2
	    continue
	else
	    res="$(echo "$xs" | sed -ne "${res%%:*}p;")"
	    if [ "$res" = 'quit' ]; then
		echo "Quit.." 1>&2
		return 1
	    else
		echo "$res"
		break
	    fi
	fi
    done
}

OIFS="$IFS"
func='main()'
ps_e="$ps_e0: $func"
ps_w="$ps_w0: $func"

if [ $# -lt 1 ]; then
    echo "$ps_w: No files to edit."
    exit 0
fi

f="$1"

# Symlink to file matches with '-f' as well.
if [ ! -f "$f" ]; then
    echo "$ps_e: Not a regular file."
    exit 1
fi

create_bkp "$f"
cmd="$(command -v "${EDITOR:-}" || true)"
if [ -z "$cmd" ]; then
    cmd="$(command -v vim)"
    if [ -z "$cmd" ]; then
	cmd="$(command -v vi)"
    fi
fi
#cmd="$(command -v ls)"
cmd="ls -l"
if [ -x "$cmd" ]; then
    "$cmd" "$f"
else
    echo "$ps_e: Can't execute editor."
    rm_bkp "$f"
    exit 1
fi
    
exit 0

if create_bkp "$f"; then
    # Is this process still running.
    # If yesShow diff.
    # Ask what to do: delete 
else
    # Call editor.
    # Generate diff (and save).
    # Show diff to user and ask what to do: save, retry, discard.
fi
