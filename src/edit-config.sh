#!/bin/sh

set -euf

newline='
'
OIFS="$IFS"

create_bkp()
{
    local f="$1"	    # Filename with path!
    local d="$(dirname "$f")"
    # FIXME: $PID reused?
    local bf="$f.orig.$$"   # Marking backup file with PID allows to check
			    # whether its creator still running.
    local nbf="$(basename "$bf")"
    local bfs=''	     # Other backup files.
    local b='' p='' c=''
    bfs="$(find "$d" -maxdepth 1 -type f -name "${nbf%.*}*")"
    if [ -n "$bfs" ]; then
	echo "$0: Warning: Backup file(s) already exists."
	IFS="$newline"
	for b in $bfs; do   # Filename with path!
	    p="${b##*.}"
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
	cp -avT "$d/$f" "$d/$bf"
    fi
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
