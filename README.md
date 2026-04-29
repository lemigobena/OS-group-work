# System Call Analyzer — Shell Pro

## Project Description

This is a shell program developed for the Operating Systems course at Addis Ababa University. It captures and analyzes the system calls generated when a user executes a command.

The program uses `strace` to monitor the execution and provides a detailed report for each system call, including:

- The name and full description of the system call.
- The parameters passed and their meanings.

* The returned values and whether the call was successful.

All descriptions are pulled directly from the Linux system manual pages.

## Supported System Calls

It traces major system calls including: `open`, `openat`, `read`, `write`, `close`, `execve`, `fork`, `clone`, `mmap`, `access`, `stat`, `fstat`, `lseek`, and `exit`.

## How to Run

1. Make the script executable:
   ```bash
   chmod +x syscall_analyzer.sh
   ```
2. Run the shell program:
   ```bash
   ./syscall_analyzer.sh
   ```
3. Type any command (e.g., `ls` or `pwd`) to see the analysis.

## Group Members

1. Bekalu Addisu
2. Fita Alemayehu
3. Lemi Gobena
4. Misganaw Habtamu
5. Olit Oljira
