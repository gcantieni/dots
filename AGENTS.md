# Agent instructions

Personal defaults for every project. A repo's own `AGENTS.md` takes precedence.

@~/AGENTS.local.md

- Be terse. Match the surrounding code's style; don't add explanatory comments
  unless asked.
- Run the project's check or test command before calling work done, and report
  failures as they are.
- Write any non-trivial script in Python. Prefer plain python3. If dependencies
  are required, run with uv (`#!/usr/bin/env -S uv run --script` plus PEP 723
  inline metadata).
  - Exception: scripts on a hot path (status lines, prompts, frequent hooks) use
    POSIX `sh` if small, or Go if they need real logic.
