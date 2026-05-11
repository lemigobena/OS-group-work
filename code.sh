#!/bin/bash

TRACE_FILE="/tmp/strace_out_$$.txt"
# The list of syscalls required by the assignment
SYSCALLS="open,openat,read,write,close,execve,fork,clone,mmap,access,stat,fstat,lseek,exit,exit_group"

# Colors
BOLD=$'\e[1m'
RESET=$'\e[0m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
GREEN=$'\e[32m'
RED=$'\e[31m'
YELLOW=$'\e[33m'
MAGENTA=$'\e[35m'

# clean up temp file when we are done
trap "rm -f $TRACE_FILE" EXIT

# Function to get the full DESCRIPTION section from the manual
get_short_desc() {
    # Extract DESCRIPTION and print only the first paragraph (until the first empty line)
    man 2 "$1" 2>/dev/null | col -bx | sed -n '/^DESCRIPTION$/,/^[A-Z]/p' | sed '1d;$d' | awk 'NF {p=1} p && !NF {exit} p' | sed 's/^[[:space:]]*//'
}

# Function to explain each parameter and show what value was actually passed
show_param_info() {
    local name=$1
    local actual_values=$2
    
    # Capture the prototype from SYNOPSIS (robust regex for multi-line C prototypes)
    local proto=$(man 2 "$name" 2>/dev/null | col -bx | sed -n "/^SYNOPSIS$/,/^[A-Z]/p" | tr '\n' ' ' | sed 's/  */ /g' | grep -oP "\b${name}\([^;]*;" | head -n 1)

    # Extract parameter names (filters types and keywords)
    local p_names=($(echo "$proto" | sed 's/.*(//; s/).*//; s/,/ /g' | tr ' ' '\n' | grep -vP '^([*]?(int|char|void|const|struct|size_t|off_t|mode_t|unsigned|_Nullable|static|restrict|long|short)|\*)$|^\s*$' | sed 's/.*[*]//; s/\[.*//'))
    
    # Split strace values
    IFS=',' read -ra p_vals <<< "$actual_values"

    echo -e "${YELLOW}${BOLD}PARAMETERS:${RESET}"
    for i in "${!p_names[@]}"; do
        [[ "${p_names[$i]}" == "..." || -z "${p_names[$i]}" ]] && continue
        
        local val=$(echo "${p_vals[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        # 1. Get the general definition of the parameter name
        local p_def=$(man 2 "$name" 2>/dev/null | col -bx | sed -n '/^DESCRIPTION$/,/^[A-Z]/p' | tr '\n' ' ' | sed 's/  */ /g' | grep -oP "[^.]*\b${p_names[$i]}\b[^.]*\." | grep -vi "${name}(" | head -n 1 | sed 's/^[[:space:]]*//')
        # Broad fallback if sentence search fails
        [ -z "$p_def" ] && p_def=$(man 2 "$name" 2>/dev/null | col -bx | grep -i "\b${p_names[$i]}\b" | head -n 1 | sed 's/^[[:space:]]*//' | cut -d. -f1)
        
        # 2. Try to find specific meanings for the actual values (e.g., flags like O_RDONLY)
        local val_meaning=""
        local val_clean=$(echo "$val" | tr '|' ' ' | sed 's/[()",]//g')
        for v in $val_clean; do
            if [[ "$v" =~ ^[A-Z_][A-Z0-9_]+$ ]]; then
                 # Use a simpler line-based search for symbolic constants
                 local m=$(man 2 "$name" 2>/dev/null | col -bx | grep -i "\b$v\b" | head -n 1 | sed 's/^[[:space:]]*//' | cut -d. -f1)
                 [ -n "$m" ] && val_meaning+="$m. "
            fi
        done

        echo -e "   ${CYAN}• ${p_names[$i]}${RESET}: ${MAGENTA}${val:-N/A}${RESET}"
        echo -e "           ${val_meaning:-${p_def:-See man 2 $name for detailed description.}}"
    done
}

# Function to get return value interpretation from the manual
get_ret_explanation() {
    man 2 "$1" 2>/dev/null | col -bx | sed -n '/^RETURN VALUE$/,/^[A-Z]/p' | grep -v "^RETURN VALUE$" | grep -v "^[A-Z]" | head -2 | sed 's/^[[:space:]]*//' | tr '\n' ' '
}

# Start of the shell program
echo -e "${BLUE}${BOLD}========================================${RESET}"
echo -e "${BLUE}${BOLD}      System Call Analyzer Shell      ${RESET}"
echo -e "${BLUE}${BOLD}========================================${RESET}"

while true; do
    echo -ne "${GREEN}${BOLD}myshell> ${RESET}"
    read -r cmd
    [ -z "$cmd" ] && continue
    [ "$cmd" = "exit" ] || [ "$cmd" = "quit" ] && break

    echo -e "\n${BLUE}--- Executing and tracing: ${BOLD}$cmd${RESET}${BLUE} ---${RESET}\n"
    # Use strace and silence the target command's output
    strace -f -e trace=$SYSCALLS -o "$TRACE_FILE" -- $cmd >/dev/null 2>&1

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

        echo -e "${BLUE}${BOLD}➤ SYSTEM CALL #$count: ${MAGENTA}$syscall${RESET}"
        # Remove the leading PID from the raw trace for a cleaner look
        clean_line=$(echo "$line" | sed 's/^[0-9 ]*//')
        echo -e "${YELLOW}${BOLD}RAW TRACE:${RESET}  ${CYAN}$clean_line${RESET}"
        echo -e "${YELLOW}${BOLD}PURPOSE:${RESET} $(get_short_desc "$syscall")"
        show_param_info "$syscall" "$params"
        
        echo -e "${YELLOW}${BOLD}RETURN:${RESET}"
        printf "   ${CYAN}%-10s${RESET} %s\n" "Value:" "${BOLD}$retval${RESET}"
        if echo "$retval" | grep -q "^-1"; then
            printf "   ${CYAN}%-10s${RESET} ${RED}${BOLD}FAILED${RESET}\n" "Status:"
        else
            printf "   ${CYAN}%-10s${RESET} ${GREEN}${BOLD}SUCCESS${RESET}\n" "Status:"
            printf "   ${CYAN}%-10s${RESET} ${YELLOW}%s${RESET}\n" "Meaning:" "$(get_ret_explanation "$syscall")"
        fi
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    done < "$TRACE_FILE"
done
