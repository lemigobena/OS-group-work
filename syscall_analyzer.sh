#!/bin/bash

TRACE_FILE="/tmp/strace_out_$$.txt"
# The list of syscalls required by the assignment
SYSCALLS="open,openat,read,write,close,execve,fork,clone,mmap,access,stat,fstat,lseek,exit,exit_group"

# clean up temp file when we are done
trap "rm -f $TRACE_FILE" EXIT

# Function to get the full DESCRIPTION section from the manual
get_short_desc() {
    # We extract everything between DESCRIPTION and the next section header
    man 2 "$1" 2>/dev/null | col -bx | sed -n '/^DESCRIPTION$/,/^[A-Z][A-Z]/p' | sed '1d;$d' | sed 's/^[[:space:]]*/   /'
}

# Function to explain each parameter and show what value was actually passed
show_param_info() {
    local name=$1
    local actual_values=$2
    
    # get the prototype to find parameter names
    local proto=$(man 2 "$name" 2>/dev/null | col -bx | sed -n '/^SYNOPSIS$/,/^[A-Z][A-Z]/p' | grep "${name}(" | head -1)
    
    # regex to find parameter names (skips types like int, char, etc)
    local p_names=$(echo "$proto" | sed 's/.*(//; s/).*//; s/,/ /g' | tr ' ' '\n' | grep -vP '^(int|char|void|const|struct|size_t|off_t|mode_t|unsigned|_Nullable|static|\*)$|^\s*$' | sed 's/.*[*]//; s/\[.*//')
    
    echo "Parameters passed:"
    echo "   Actual Values: ($actual_values)"
    echo "Descriptions:"
    for p in $p_names; do
        if [[ "$p" == "..." ]]; then continue; fi
        # Search the manual for a definition of the parameter
        local def=$(man 2 "$name" 2>/dev/null | col -bx | sed -n '/^DESCRIPTION$/,/^[A-Z][A-Z]/p' | grep -i -m 1 "\b$p\b" | sed 's/^[[:space:]]*//' | cut -d. -f1 | head -c 100)
        [ -z "$def" ] && def="Referenced in the manual."
        echo "   - $p: $def"
    done
}

# Function to get return value interpretation from the manual
get_ret_explanation() {
    man 2 "$1" 2>/dev/null | col -bx | sed -n '/^RETURN VALUE$/,/^[A-Z]/p' | grep -v "^RETURN VALUE$" | grep -v "^[A-Z]" | head -2 | sed 's/^[[:space:]]*//' | tr '\n' ' '
}

# Start of the shell program
echo "======================================================"
echo "    System Call Analyzer Shell - Shell Pro"
echo "    Course Project: OS and System Programming"
echo "======================================================"

while true; do
    echo -n "shellpro> "
    read -r cmd
    [ -z "$cmd" ] && continue
    [ "$cmd" = "exit" ] || [ "$cmd" = "quit" ] && break

    echo -e "\n--- Executing and tracing: $cmd ---\n"
    # Use strace to follow forks (-f) and capture specific syscalls
    strace -f -e trace=$SYSCALLS -o "$TRACE_FILE" -- $cmd 2>/dev/null

    count=0
    while IFS= read -r line; do
        # Ignore signal lines like +++ or ---
        [[ "$line" =~ ^\+\+\+|^--- ]] && continue
        
        # Parse the syscall name
        syscall=$(echo "$line" | grep -oP '\b(open|openat|read|write|close|execve|fork|clone|mmap|access|stat|fstat|lseek|exit|exit_group)\(' | head -1 | tr -d '(')
        [ -z "$syscall" ] && continue
        
        # Parse arguments and return value from the strace line
        params=$(echo "$line" | sed -n "s/.*${syscall}(\(.*\))\s*=.*/\1/p")
        retval=$(echo "$line" | grep -oP '=\s+\K.*$')
        count=$((count + 1))

        echo "------------------------------------------------------"
        echo "SYSTEM CALL #$count: $syscall"
        echo "------------------------------------------------------"
        echo "DESCRIPTION/PURPOSE:"
        echo "   $(get_short_desc "$syscall")"
        echo ""
        show_param_info "$syscall" "$params"
        echo ""
        echo "RETURN VALUE AND INTERPRETATION:"
        echo "   Returned: $retval"
        if echo "$retval" | grep -q "^-1"; then
            echo "   Status: FAILED (See errno in parentheses above)"
        else
            echo "   Status: SUCCESS"
            echo "   Meaning: $(get_ret_explanation "$syscall")"
        fi
        echo -e "------------------------------------------------------\n"
    done < "$TRACE_FILE"
done
