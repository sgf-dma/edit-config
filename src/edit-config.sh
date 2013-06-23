#!/bin/sh

set -euf

newline='
'
OIFS="$IFS"

# Backup filename manipulation functions bkp_file_X().  All have the same
# args:

bkp_file_name()
{
    # Backup file name.
    # Args: 1 - filename (with or without path does not matter).
    # Stdout: backup file name.
    echo "${1}.orig.$$"
}

bkp_file_rx()
{
    # Shell pattern to match backups of this file, created by different
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
    # 1 - file to backup.
    local f="$1"	    # Filename with path!
    local d="$(dirname "$f")"
    local nf="$(basename "$f")"
    local brx="$(bkp_file_rx "$nf")"
    local bfs='' b='' p='' c=''
    bfs="$(find "$d" -maxdepth 1 -type f -name "$brx")"
    if [ -n "$bfs" ]; then
	echo "$0: Warning: Backup file(s) already exists."
	IFS="$newline"
	for b in $bfs; do   # Filenames with path!
	    p="$(bkp_file_pid "$b")"
	    c="$(ps --no-heading -o cmd -p "$p" || true)"
	    diff -s -u "$b" "$f" || true
	    if [ -n "$c" ]; then
		echo "$0: Warning: Process '$c' with PID '$p', which created file '$b', still running."
	    fi
	    echo '##### Ask: Delete/Ignore/Quit'
	done
	# FIXME: If $IFS was changed (against $OIFS) before create_bkp() had
	# called, this restores it to incorrect value. So, probably, run in
	# subshell?
	IFS="$OIFS"
    else
	echo "### Creating backup:"
	cp -avT "$f" "$(bkp_file_name "$f")"
	sleep 60
    fi
}

ask_user()
{
    # 1 -prompt.
    read -p -r reply

}

if [ $# -lt 1 ]; then
    echo "$0: Warning: No files to edit."
    exit 0
fi

f="$1"

# Symlink to file matches with '-f' as well.
if [ ! -f "$f" ]; then
    echo "$0: ERROR: Not a regular file."
    exit 1
fi

create_bkp "$f"

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
