# System Call Analyzer Shell

A professional, terminal-based utility designed to demystify the interaction between user commands and the Linux kernel. This tool captures, analyzes, and explains system calls in real-time using `strace` and system manual pages.

Developed for the **Operating Systems** course at **Addis Ababa University**.

---

## Key Features

- **Real-time Tracing**: Monitor system calls as they happen during command execution.
- **Smart Parameter Interpretation**: Automatically resolves symbolic constants (like `O_RDONLY` or `PROT_READ`) and explains their specific meaning.
- **Integrated Documentation**: Pulls concise descriptions and return value interpretations directly from `man` pages.
- **Premium Terminal UI**: Uses ANSI color tokens for a high-contrast, readable analysis report.
- **Automatic Cleanup**: Self-cleaning architecture ensures no temporary trace files are left behind.

## Supported System Calls

The analyzer is optimized for core filesystem, process, and memory management calls:
`open`, `openat`, `read`, `write`, `close`, `execve`, `fork`, `clone`, `mmap`, `access`, `stat`, `fstat`, `lseek`, `exit`, and `exit_group`.

---

## Getting Started

1. **Clone the repository** (if applicable) and navigate to the project directory.
2. **Make the script executable**:
   ```bash
   chmod +x code.sh
   ```
3. **Launch the shell**:
   ```bash
   ./code.sh
   ```
4. **Analyze a command**:
   Simply type any command (e.g., `ls` or `cat test.txt`) inside the `myshell>` prompt to see the step-by-step system call breakdown.

---

## Group Members

1. Bekalu Addisu
2. Fita Alemayehu
3. Lemi Gobena
4. Misganaw Habtamu
5. Olit Oljira

---

© 2026 Addis Ababa University - Operating Systems Course
