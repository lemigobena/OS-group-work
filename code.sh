#!/bin/bash

# Configuration: Trace output file and list of system calls to analyze
TRACE_FILE="/tmp/strace_out_$$.txt"
SYSCALLS="open,openat,read,write,close,execve,fork,clone,mmap,access,stat,fstat,lseek,exit,exit_group"

# ANSI Color Tokens for a rich UI
BOLD=$'\e[1m'; RESET=$'\e[0m'; BLUE=$'\e[34m'; CYAN=$'\e[36m'; GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; MAGENTA=$'\e[35m'

# Ensure temporary files are removed on exit
trap "rm -f $TRACE_FILE" EXIT

# Utility: Clean man page output (strips non-ASCII and formatting artifacts)
clean_man() { 
    col -bx | iconv -f UTF-8 -t ASCII//TRANSLIT | sed 's/- [[:space:]]*//g'
}

# Function: Extract the first paragraph of the DESCRIPTION section for a syscall
get_short_desc() {
    man 2 "$1" 2>/dev/null | clean_man | sed -n '/^DESCRIPTION$/,/^[A-Z]/p' | sed '1d;$d' | awk 'NF {p=1} p && !NF {exit} p' | xargs
}

# Function: Analyze and explain each parameter passed to a syscall
show_param_info() {
    local name=$1 actual_values=$2
    
    # Extract the C prototype from the SYNOPSIS section
    local proto=$(man 2 "$name" 2>/dev/null | clean_man | tr '\n' ' ' | sed 's/  */ /g' | grep -oP "\b${name}\([^;]*;" | head -n 1)
    
    # Filter parameter names by stripping types (int, char*, etc.) and keywords (const, restrict)
    local p_names=($(echo "$proto" | sed 's/.*(//; s/).*//; s/,/ /g' | tr ' ' '\n' | grep -vP '^([*]?(int|char|void|const|struct|size_t|off_t|mode_t|unsigned|_Nullable|static|restrict|long|short)|\*)$|^\s*$' | sed 's/.*[*]//; s/\[.*//'))
    
    # Split the actual values captured by strace
    IFS=',' read -ra p_vals <<< "$actual_values"
    
    echo -e "${YELLOW}${BOLD}PARAMETERS:${RESET}"
    for i in "${!p_names[@]}"; do
        [[ "${p_names[$i]}" == "..." || -z "${p_names[$i]}" ]] && continue
        local val=$(echo "${p_vals[$i]}" | xargs)
        
        # Search for the general definition of this parameter in the man page
        local p_def=$(man 2 "$name" 2>/dev/null | clean_man | sed -n '/^DESCRIPTION$/,/^[A-Z]/p' | tr '\n' ' ' | sed 's/  */ /g' | grep -oP "[^.]*\b${p_names[$i]}\b[^.]*\." | grep -vi "${name}(" | head -n 1 | xargs)
        [[ -z "$p_def" ]] && p_def=$(man 2 "$name" 2>/dev/null | clean_man | grep -i "\b${p_names[$i]}\b" | head -n 1 | xargs | cut -d. -f1)
        
        # Smart Explanation: If the value is a symbolic constant (e.g. O_RDONLY), find its specific meaning
        local val_meaning="" val_clean=$(echo "$val" | tr '|' ' ' | sed 's/[()",]//g')
        for v in $val_clean; do
            if [[ "$v" =~ ^[A-Z_][A-Z0-9_]+$ ]]; then
                 local m=$(man 2 "$name" 2>/dev/null | clean_man | grep -i "\b$v\b" | head -n 1 | xargs | cut -d. -f1)
                 [[ -n "$m" ]] && val_meaning+="$m. "
            fi
        done
        
        # Display the parameter name, the value passed, and its explanation
        echo -e "   ${CYAN}• ${p_names[$i]}${RESET}: ${MAGENTA}${val:-N/A}${RESET}\n           ${val_meaning:-${p_def:-See man 2 $name for detailed description.}}"
    done
}

# Function: Extract the return value interpretation from the RETURN VALUE section
get_ret_explanation() {
    man 2 "$1" 2>/dev/null | clean_man | sed -n '/^RETURN VALUE$/,/^[A-Z]/p' | grep -vE "^(RETURN VALUE|[A-Z])" | head -2 | xargs
}

# --- Main Program Entry Point ---
echo -e "${BLUE}${BOLD}========================================\n      System Call Analyzer Shell      \n========================================${RESET}"

while true; do
    echo -ne "${GREEN}${BOLD}myshell> ${RESET}"; read -r cmd
    [[ -z "$cmd" ]] && continue
    [[ "$cmd" =~ ^(exit|quit)$ ]] && break
    
    echo -e "\n${BLUE}--- Executing and tracing: ${BOLD}$cmd${RESET}${BLUE} ---${RESET}\n"
    
    # Execute the command under strace, following forks (-f) and filtering for target syscalls
    # Both stdout and stderr of the traced command are silenced to keep the UI clean
    strace -f -e trace=$SYSCALLS -o "$TRACE_FILE" -- $cmd >/dev/null 2>&1
    
    count=0
    while IFS= read -r line; do
        # Filter out strace signals/meta-info
        [[ "$line" =~ ^\+\+\+|^--- ]] && continue
        
        # Parse the syscall name from the trace line
        syscall=$(echo "$line" | grep -oP '\b(open|openat|read|write|close|execve|fork|clone|mmap|access|stat|fstat|lseek|exit|exit_group)\(' | head -1 | tr -d '(')
        [[ -z "$syscall" ]] && continue
        
        # Extract arguments and return value
        params=$(echo "$line" | sed -n "s/.*${syscall}(\(.*\))\s*=.*/\1/p")
        retval=$(echo "$line" | grep -oP '=\s+\K.*$')
        ((count++))
        
        # Header for the specific syscall instance
        echo -e "${BLUE}${BOLD}➤ SYSTEM CALL #$count: ${MAGENTA}$syscall${RESET}"
        
        # Show the raw trace (PID stripped) for verification
        echo -e "${YELLOW}${BOLD}RAW TRACE:${RESET}  ${CYAN}$(echo "$line" | sed 's/^[0-9 ]*//')${RESET}"
        
        # Display the high-level purpose of this call
        echo -e "${YELLOW}${BOLD}PURPOSE:${RESET} $(get_short_desc "$syscall")"
        
        # Detail the parameters and their meanings
        show_param_info "$syscall" "$params"
        
        # Interpret the return value (Success vs. Failure)
        echo -e "${YELLOW}${BOLD}RETURN:${RESET}\n   ${CYAN}Value:    ${RESET}${BOLD}$retval${RESET}"
        if echo "$retval" | grep -q "^-1"; then 
            echo -e "   ${CYAN}Status:   ${RESET}${RED}${BOLD}FAILED${RESET}"
        else 
            echo -e "   ${CYAN}Status:   ${RESET}${GREEN}${BOLD}SUCCESS${RESET}\n   ${CYAN}Meaning:  ${RESET}${YELLOW}$(get_ret_explanation "$syscall")${RESET}"
        fi
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    done < "$TRACE_FILE"
done
