from __future__ import annotations

import os
import select
import shutil
import subprocess
import sys
import termios
import tty
from pathlib import Path
from typing import Iterable, Optional

RESET = "\x1b[0m"
BOLD = "\x1b[1m"
DIM = "\x1b[2m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
CYAN = "\x1b[36m"


class Fail(Exception):
    """Reported as "error: <message>"."""


class Cancelled(Exception):
    def __init__(self, message: str = "cancelled"):
        super().__init__(message)


def err(message: str) -> None:
    print(message, file=sys.stderr)


def prompt(text: str, initial: str = "") -> str:
    """A line read with readline editing, starting from initial."""
    try:
        import readline
    except ImportError:
        readline = None
    sys.stdout.flush()
    if readline is not None and initial:
        readline.set_startup_hook(lambda: readline.insert_text(initial))
    try:
        # Keep prompts off a captured stdout, like bash's read -p.
        if sys.stdout.isatty():
            return input(text)
        sys.stderr.write(text)
        sys.stderr.flush()
        return input()
    except EOFError:
        err("")
        raise Cancelled() from None
    finally:
        if readline is not None:
            readline.set_startup_hook(None)


def confirm(question: str, default: bool) -> bool:
    answer = prompt(f"{question} {'[Y/n]' if default else '[y/N]'} ").strip()
    if not answer:
        return default
    return answer[0] in "yY"


def getch(text: str = "") -> str:
    """One key, without waiting for enter."""
    sys.stdout.flush()
    if text:
        sys.stderr.write(text)
        sys.stderr.flush()
    fd = sys.stdin.fileno()
    if not os.isatty(fd):
        return sys.stdin.read(1)
    saved = termios.tcgetattr(fd)
    try:
        tty.setcbreak(fd)
        return os.read(fd, 1).decode(errors="replace")
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)


def pause() -> None:
    getch(f"{DIM}(press a key){RESET}")


def fzf(lines: Iterable[str], *options: str) -> Optional[str]:
    """The line picked with fzf, or None if cancelled."""
    if not shutil.which("fzf"):
        raise Fail("fzf is needed to pick from a list")
    r = subprocess.run(["fzf", *options], input="\n".join(lines) + "\n", text=True,
                       stdout=subprocess.PIPE)
    if r.returncode not in (0, 1):
        return None
    picked = r.stdout.rstrip("\n")
    return picked or None


def fit(text: str, width: int) -> str:
    """text cut or padded to width columns."""
    if len(text) > width:
        text = text[:max(width - 1, 0)] + "…"
    return text + " " * (width - len(text))


def tilde(path) -> str:
    s = str(path)
    home = str(Path.home())
    if s == home or s.startswith(home + "/"):
        return "~" + s[len(home):]
    return s


def open_url(url: str) -> str:
    """Open url in the browser and return the line to show for it."""
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    try:
        subprocess.Popen([opener, url], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass
    return f"  {url}"


def phase(title: str) -> None:
    print(f"\n{BOLD}== {title}{RESET}")


def term_cols() -> int:
    return shutil.get_terminal_size((120, 40)).columns


class RawTerminal:
    """Keys without echo or line buffering, with the cursor hidden."""

    def __init__(self):
        self.fd = sys.stdin.fileno()
        self.saved = None

    def __enter__(self):
        self.saved = termios.tcgetattr(self.fd)
        self._raw()
        return self

    def __exit__(self, *exc):
        self._cooked()

    def _raw(self):
        tty.setcbreak(self.fd)
        sys.stdout.write("\x1b[?25l")
        sys.stdout.flush()

    def _cooked(self):
        termios.tcsetattr(self.fd, termios.TCSADRAIN, self.saved)
        sys.stdout.write("\x1b[?25h")
        sys.stdout.flush()

    def suspend(self):
        """Context manager that gives the terminal back for prompts and other programs."""
        term = self

        class _Suspended:
            def __enter__(self):
                term._cooked()

            def __exit__(self, *exc):
                term._raw()

        return _Suspended()

    def _read(self, timeout: Optional[float]) -> Optional[str]:
        ready, _, _ = select.select([self.fd], [], [], timeout)
        if not ready:
            return None
        return os.read(self.fd, 1).decode(errors="replace")

    def key(self, timeout: Optional[float] = None) -> Optional[str]:
        """A key, with arrows as h/j/k/l and a lone escape as q; None on timeout, "" at EOF."""
        k = self._read(timeout)
        if k != "\x1b":
            return k
        rest = ""
        while len(rest) < 2:
            c = self._read(0.05)
            if not c:
                break
            rest += c
        if not rest:
            return "q"
        return {"[A": "k", "[B": "j", "[C": "l", "[D": "h",
                "OA": "k", "OB": "j", "OC": "l", "OD": "h"}.get(rest, "\x1b")
