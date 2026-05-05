#!/bin/bash

TRACE_FILE="/tmp/syscall_trace_$$.txt"
SYSCALLS="open,openat,read,write,close,execve,fork,clone,mmap,access,stat,fstat,lseek,exit,exit_group"

# Function to get system call descriptions from manual pages
desc() {
    local summary
    summary=$(man 2 "$1" 2>/dev/null | col -b | awk '/NAME/{getline; print}' | sed 's/^[ \t]*//')
    
    if [ -n "$summary" ]; then
        echo "$summary"
    else
        case "$1" in
            exit_group) echo "exit_group - exit all threads in a process" ;;
            *)          echo "System call: $1" ;;
        esac
    fi
}

# Function to analyze and display system call parameters
params() {
    local name="$1" args="$2"
    local f1 f2 f3 f4
    f1=$(echo "$args" | cut -d',' -f1 | xargs)
    f2=$(echo "$args" | cut -d',' -f2 | xargs)
    f3=$(echo "$args" | cut -d',' -f3 | xargs)
    f4=$(echo "$args" | cut -d',' -f4 | xargs)

    case "$name" in
        openat)
            echo "  dirfd: $f1"
            echo "  path:  $(echo "$f2" | tr -d '\"')"
            echo "  flags: $f3"
            [ -n "$f4" ] && echo "  mode:  $f4"
            ;;
        open)
            echo "  path:  $(echo "$f1" | tr -d '\"')"
            echo "  flags: $f2"
            [ -n "$f3" ] && echo "  mode:  $f3"
            ;;
        read|write)
            echo "  fd:    $f1"
            echo "  buf:   $f2"
            echo "  count: $f3 bytes"
            ;;
        close)
            echo "  fd:    $f1" ;;
        execve)
            echo "  path:  $(echo "$f1" | tr -d '\"')"
            echo "  argv:  $f2"
            ;;
        clone)
            echo "  flags: $f1"
            echo "  stack: $f2"
            ;;
        mmap)
            echo "  addr:  $f1"
            echo "  len:   $f2 bytes"
            echo "  prot:  $f3"
            echo "  flags: $f4"
            ;;
        access)
            echo "  path:  $(echo "$f1" | tr -d '\"')"
            echo "  mode:  $f2"
            ;;
        stat)
            echo "  path:  $(echo "$f1" | tr -d '\"')"
            echo "  buf:   $f2"
            ;;
        fstat)
            echo "  fd:    $f1"
            echo "  buf:   $f2"
            ;;
        lseek)
            echo "  fd:     $f1"
            echo "  offset: $f2"
            echo "  whence: $f3"
            ;;
        exit|exit_group)
            echo "  status: $f1" ;;
        *)
            echo "  args:   $args" ;;
    esac
}

# Function to interpret system call return values
retval() {
    local name="$1" raw="$2"
    local val errno errmsg
    val=$(echo "$raw" | sed 's/^= *//' | awk '{print $1}')
    errno=$(echo "$raw" | grep -oE 'E[A-Z]+' | head -1)
    errmsg=$(echo "$raw" | grep -oP '\(.*?\)' | head -1 | tr -d '()')

    case "$name" in
        open|openat)
            [[ "$val" =~ ^[0-9]+$ ]] && echo "  RESULT: Success (fd $val)" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        read|write)
            [[ "$val" =~ ^[0-9]+$ ]] && echo "  RESULT: Success ($val bytes)" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        close|execve|access|stat|fstat)
            [ "$val" = "0" ] && echo "  RESULT: Success" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        fork|clone)
            [[ "$val" =~ ^[0-9]+$ ]] && echo "  RESULT: Success (PID $val)" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        mmap)
            echo "$val" | grep -qE '^0x' && echo "  RESULT: Success (mapped at $val)" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        lseek)
            [[ "$val" =~ ^[0-9]+$ ]] && echo "  RESULT: Success (new offset $val)" || echo "  RESULT: Error ($errno: $errmsg)" ;;
        exit|exit_group)
            echo "  RESULT: Process terminated" ;;
        *)
            echo "  RESULT: $val" ;;
    esac
}

# Function to parse strace output and trigger analysis
analyze() {
    echo "--- ANALYSIS START ---"
    while IFS= read -r line; do
        [[ "$line" =~ ^\+\+\+|^---|^strace ]] && continue
        [ -z "$line" ] && continue

        local sc raw_args rv
        sc=$(echo "$line" | grep -oP '^[a-z_0-9]+(?=\()')
        [ -z "$sc" ] && continue
        
        if echo "$SYSCALLS" | grep -qw "$sc"; then
            raw_args=$(echo "$line" | grep -oP '(?<=\().*(?=\))' | head -1)
            rv=$(echo "$line" | grep -oP '=\s*[-0-9a-zA-Z_\(\) ]+$')

            echo "SYSCALL:     $sc"
            echo "PURPOSE:     $(desc "$sc")"
            echo "PARAMETERS:"
            params "$sc" "$raw_args"
            retval "$sc" "$rv"
            echo ""
        fi
    done < "$TRACE_FILE"
    echo "--- ANALYSIS END ---"
}

command -v strace &>/dev/null || { echo "Error: strace not found."; exit 1; }
command -v man &>/dev/null    || { echo "Warning: man not found. Descriptions will be generic."; }
command -v col &>/dev/null    || { echo "Warning: col not found. Descriptions may have formatting issues."; }

trap 'rm -f "$TRACE_FILE"' EXIT

while true; do
    printf "Enter command (or 'exit'): "
    read -r cmd
    [ -z "$cmd" ] && continue
    [[ "${cmd,,}" == "exit" ]] && break

    echo "Tracing command: $cmd"
    strace -e trace=$SYSCALLS -o "$TRACE_FILE" -- bash -c "$cmd" >/dev/null 2>&1

    if [ -s "$TRACE_FILE" ]; then
        analyze
    else
        echo "No system calls captured."
    fi
    rm -f "$TRACE_FILE"
done