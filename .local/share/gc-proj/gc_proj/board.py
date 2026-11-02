"""The status board: projects by state, with areas in a panel below."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, fields
from typing import Optional

from . import links, plugins, project, services, tmux, ui
from .commands import pick_sandbox, rename
from .project import Project, all_projects, area_dir, current_area, jira_name, set_keys
from .ui import Cancelled, Fail
from .util import self_command, self_env, write_atomic

COLUMNS = ("active", "review", "checkin", "done")
COLOR = {"active": "34", "review": "33", "checkin": "35", "done": "32", "area": "36"}
LABEL = {"active": "ACTIVE", "review": "IN REVIEW", "checkin": "CHECKING IN", "done": "DONE"}
AREA_COL = len(COLUMNS)
HELP = ("hjkl/arrows move  tab areas  enter go  a r c d set state  u auto state  A area  R rename  "
        "o+r/m/j open review/MR/Jira  n new  b break pane  x done  * all  g refresh  q quit")


@dataclass
class Card:
    dir: str
    name: str
    state: str
    color: str
    detail: str = ""
    review: str = ""
    review_url: str = ""
    mr: str = ""
    key: str = ""
    key_url: str = ""
    touched: int = 0
    kids: str = ""


def collect(cfg, show_all: bool) -> list[Card]:
    """One card per project with a tmux session (all projects if show_all), plus one per area."""
    activity = tmux.session_activity()
    projs, areas = [], []
    kids = defaultdict(list)
    for p in all_projects(cfg):
        if p.is_area:
            areas.append(p)
            continue
        if p.get("area"):
            kids[p.get("area")].append(p)
        if show_all or p.session in activity:
            projs.append(p)

    with ThreadPoolExecutor(max_workers=8) as ex:
        f_reviews = ex.submit(services.pending_reviews, cfg) if services.rb_enabled(cfg) else None
        f_mrs = ex.submit(services.pending_mrs, cfg) if services.gitlab_enabled(cfg) else None
        f_plugins = ex.submit(plugins.collect, cfg, projs)
        f_branches = {p.path: ex.submit(links.project_branch, cfg, p) for p in projs}
        reviews = f_reviews.result() if f_reviews else []
        mrs = f_mrs.result() if f_mrs else []
        plugin_ctxs = f_plugins.result()
        branches = {k: f.result() for k, f in f_branches.items()}

    cards = []
    for p in projs:
        state, key = p.get("state"), p.jira_key
        branch = branches[p.path]
        info = plugins.project_info(cfg, p, plugin_ctxs, branch)
        review = links.find_review(p, reviews, info.changes) if services.rb_enabled(cfg) else p.get("review")
        mr = links.find_mr(p, mrs, branch)
        if not state:
            state = "review" if review or mr else "active"
        state = info.state or state
        color = info.color or COLOR.get(state, "37")
        parts = []
        if p.get("area"):
            parts.append("@" + p.get("area"))
        if key:
            parts.append(key)
        if review:
            parts.append(f"r/{review}")
        if mr:
            parts.append(f"!{mr[0]}")
        parts += info.detail
        cards.append(Card(
            dir=str(p.path), name=p.name, state=state, color=color, detail=" · ".join(parts),
            review=review, review_url=services.rb_review_url(cfg, review) if review and services.rb_enabled(cfg) else "",
            mr=mr[1] if mr else "", key=key,
            key_url=services.jira_browse(cfg, key) if key and services.jira_enabled(cfg) else ""))

    # An area was touched when it, one of its projects or one of their tmux
    # sessions last was.
    for a in areas:
        ts = max(a.contents_touched(), activity.get(a.session, 0))
        for kid in kids.get(a.name, []):
            ts = max(ts, kid.last_touched(), activity.get(kid.session, 0))
        cards.append(Card(dir=str(a.path), name=a.name, state="area", color=COLOR["area"], touched=ts,
                          kids=" · ".join(k.name for k in kids.get(a.name, []))))
    return cards


class Board:
    def __init__(self, cards: list[Card]):
        self.cards = cards
        self.layout()

    def layout(self) -> None:
        self.columns = [[i for i, c in enumerate(self.cards) if c.state == s] for s in COLUMNS]
        areas = [i for i, c in enumerate(self.cards) if c.state == "area"]
        areas.sort(key=lambda i: self.cards[i].touched, reverse=True)
        self.columns.append(areas)

    def index(self, d: str) -> int:
        for i, c in enumerate(self.cards):
            if c.dir == d:
                return i
        return -1

    def at(self, ci: int, ri: int) -> int:
        """The card at row ri of column ci, or the column's last; -1 if it's empty."""
        col = self.columns[ci]
        if not col:
            return -1
        return col[min(ri, len(col) - 1)]

    def pos(self, i: int) -> tuple[int, int]:
        for ci, col in enumerate(self.columns):
            if i in col:
                return ci, col.index(i)
        return 0, 0

    def render(self, cfg, selected: int = -1, cols: Optional[int] = None) -> str:
        current = os.environ.get("PROJ", "")
        cols = cols or int(os.environ.get("BOARD_COLS") or 0) or ui.term_cols()
        width = max((cols - 2) // len(COLUMNS) - 2, 12)
        lines = []

        def card_style(i):
            style = f"1;{self.cards[i].color}"
            if i == selected:
                style += ";7"
            return style

        def mark(i):
            return "▸" if self.cards[i].dir == current else " "

        lines.append("".join(f"\x1b[1;{COLOR[s]}m{ui.fit(LABEL[s], width)}\x1b[0m  " for s in COLUMNS))
        lines.append("".join(f"\x1b[2m{'─' * width}\x1b[0m  " for _ in COLUMNS))
        rows = max((len(c) for c in self.columns[:AREA_COL]), default=0)
        for r in range(rows):
            row = [col[r] if r < len(col) else -1 for col in self.columns[:AREA_COL]]
            line = ""
            for i in row:
                if i < 0:
                    line += " " * width + "  "
                else:
                    line += f"\x1b[{card_style(i)}m{ui.fit(mark(i) + self.cards[i].name, width)}\x1b[0m  "
            lines.append(line)
            if any(i >= 0 and self.cards[i].detail for i in row):
                line = ""
                for i in row:
                    if i < 0:
                        line += " " * width + "  "
                    else:
                        line += f"\x1b[2m{ui.fit('  ' + self.cards[i].detail, width)}\x1b[0m  "
                lines.append(line)

        areas = self.columns[AREA_COL]
        if areas:
            total = len(COLUMNS) * (width + 2) - 2
            name_w, touched_w = 18, 16
            kids_w = max(total - name_w - touched_w - 6, 10)
            now = time.time()
            stale = int(cfg["area_stale_days"]) * 86400
            lines.append("")
            lines.append(f"\x1b[1;{COLOR['area']}mAREAS\x1b[0m \x1b[2m{'─' * (total - 6)}\x1b[0m")
            for i in areas:
                c = self.cards[i]
                touched = f"touched {age_label(c.touched)}" if c.touched > 0 else "never touched"
                flag, style = " ", f"1;{c.color}"
                if c.touched == 0 or now - c.touched >= stale:
                    flag, style = "?", "1;33"
                if i == selected:
                    style += ";7"
                lines.append(f"\x1b[{style}m{ui.fit(mark(i) + c.name, name_w)}\x1b[0m  "
                             f"\x1b[2m{ui.fit(touched, touched_w)}\x1b[0m  "
                             f"{ui.fit(c.kids, kids_w)}  \x1b[1;33m{flag}\x1b[0m")
        return "\n".join(lines) + "\n"


def age_label(ts: int) -> str:
    days = int((time.time() - ts) // 86400)
    if days < 1:
        return "today"
    if days < 14:
        return f"{days}d"
    if days < 60:
        return f"{days // 7}w"
    return f"{days // 30}mo"


def cache_file(cfg, show_all: bool):
    return cfg.cache_dir / ("board-all.json" if show_all else "board.json")


def save(cfg, show_all: bool, cards: list[Card]) -> None:
    f = cache_file(cfg, show_all)
    f.parent.mkdir(parents=True, exist_ok=True)
    write_atomic(f, json.dumps([asdict(c) for c in cards]))


def load(cfg, show_all: bool) -> Optional[list[Card]]:
    names = {f.name for f in fields(Card)}
    try:
        data = json.loads(cache_file(cfg, show_all).read_text())
        return [Card(**{k: v for k, v in d.items() if k in names}) for d in data]
    except (OSError, ValueError, TypeError):
        return None


def cmd_status(cfg, a):
    cards = collect(cfg, a.all)
    save(cfg, a.all, cards)
    if not cards:
        print("no projects with tmux sessions")
        return 0
    sys.stdout.write(Board(cards).render(cfg))
    return 0


class Refresh(threading.Thread):
    def __init__(self, cfg, show_all: bool):
        super().__init__(daemon=True)
        self.cfg, self.show_all = cfg, show_all
        self.cards: Optional[list[Card]] = None
        self.start()

    def run(self):
        try:
            self.cards = collect(self.cfg, self.show_all)
            save(self.cfg, self.show_all, self.cards)
        except Exception:
            self.cards = None


def pick_area(cfg, title: str, names: Optional[list[str]] = None) -> Optional[str]:
    """An area name, "" for none, or None if cancelled."""
    if names is None:
        names = [p.name for p in project.areas(cfg)]
    picked = ui.fzf(["(none)", *names], "--prompt", f"{title}> ", "--height", "40%", "--reverse")
    if picked is None:
        return None
    return "" if picked == "(none)" else picked


def board_new(cfg, area: str) -> bool:
    """Prompt for a new project's name, then show its options until enter makes it or q cancels."""
    name = ui.prompt("new project name> ").strip().replace(" ", "-")
    if not name:
        print("cancelled")
        return False
    dir_mode = "tree" if cfg["new_tree"] else ""
    sandbox = jira = jira_mode = summary = msg = ""
    path = tmux.pane_path(tmux.origin_pane()) or os.path.expanduser("~")
    jira_project = cfg.text("jira.project") or "JIRA"
    jira_type = cfg.text("jira.type")
    prefix = cfg.text("branch_prefix")

    while True:
        shown = jira_name(name, f"{jira_project}-#####" if jira_mode == "create" else jira)
        if dir_mode == "tree":
            dir_desc = f"new tree on branch {prefix}{shown}"
        elif dir_mode in ("sandbox", "typed"):
            dir_desc = sandbox
        elif dir_mode == "project":
            dir_desc = str(cfg.root / shown)
        elif area:
            d = area_dir(cfg, area)
            dir_desc = f"{d} \x1b[2m(area dir)\x1b[0m" if d else f"{path} \x1b[2m(current dir)\x1b[0m"
        elif cfg.text("sandboxes"):
            dir_desc = "\x1b[2mpick a sandbox on create\x1b[0m"
        else:
            dir_desc = "\x1b[2mtype a dir on create\x1b[0m"
        if jira_mode == "attach":
            jira_desc = jira
        elif jira_mode == "create":
            jira_desc = f"new {jira_type}: {summary}"
        else:
            jira_desc = "(none)"
        out = ["\x1b[H\x1b[2J\x1b[1mnew project\x1b[0m", "",
               f"  name  {shown:<50} \x1b[2mr rename\x1b[0m",
               f"  area  {area or '(none)':<50} \x1b[2ma change\x1b[0m",
               f"  dir   {dir_desc}",
               "        \x1b[2mt new tree  s pick sandbox  d type a dir  p project dir  (again for default)\x1b[0m"]
        if services.jira_enabled(cfg):
            out.append(f"  jira  {jira_desc:<50} \x1b[2mja attach  jc create  jx none\x1b[0m")
        out += ["", "\x1b[2menter create  q cancel\x1b[0m"]
        if msg:
            out += ["", msg]
            msg = ""
        sys.stdout.write("\n".join(out) + "\n")
        sys.stdout.flush()

        key = ui.getch()
        if key in ("\n", "\r"):
            break
        if key == "q":
            print("cancelled")
            return False
        if key == "\x1b":
            print("cancelled")
            return False
        if key == "r":
            d = ui.prompt("name> ", name).strip().replace(" ", "-")
            if d:
                name = d
        elif key == "a":
            d = pick_area(cfg, f"area for {shown}")
            if d is not None:
                area = d
        elif key in ("t", "p"):
            want = "tree" if key == "t" else "project"
            dir_mode = "" if dir_mode == want else want
        elif key == "s":
            if dir_mode == "sandbox":
                dir_mode = ""
            else:
                try:
                    sandbox = pick_sandbox(cfg)
                    dir_mode = "sandbox"
                except (Cancelled, Fail) as e:
                    msg = str(e)
        elif key == "d":
            if dir_mode == "typed":
                dir_mode = ""
            else:
                d = os.path.expanduser(ui.prompt("dir> ").strip())
                if d and os.path.isdir(d):
                    sandbox = os.path.realpath(d)
                    dir_mode = "typed"
                elif d:
                    msg = f"not a directory: {d}"
        elif key == "j" and services.jira_enabled(cfg):
            sub = ui.getch()
            if sub == "a":
                d = ui.prompt("Jira key> ", jira).strip().upper()
                if re.fullmatch(r"[A-Z]+-[0-9]+", d):
                    jira, jira_mode = d, "attach"
                elif d:
                    msg = f"not a Jira key: {d}"
            elif sub == "c":
                d = ui.prompt(f"{jira_project} {jira_type} summary> ", summary or name.replace("-", " ")).strip()
                if d:
                    summary, jira, jira_mode = d, "", "create"
            elif sub == "x":
                jira = jira_mode = ""

    if (cfg.root / shown).exists():
        print(f"error: {cfg.root / shown} already exists")
        return False
    if jira_mode == "create":
        try:
            jira = services.jira_create(cfg, summary)
        except Fail as e:
            print(f"error: {e}")
            return False
        print(f"created {jira}: {services.jira_browse(cfg, jira)}")
    name = jira_name(name, jira)
    args = ["new", name]
    if dir_mode == "tree":
        args.append("--tree")
    elif dir_mode in ("sandbox", "typed"):
        args.append(sandbox)
    elif dir_mode == "project":
        args.append("--no-sandbox")
    if jira:
        args.append(f"--jira={jira}")
    args.append(f"--area={area}")
    env = self_env(GC_PROJ_NEW_TREE="")
    return subprocess.call(self_command(*args), cwd=path, env=env) == 0


def cmd_board(cfg, a):
    if not sys.stdin.isatty():
        raise Fail("the board needs a terminal")
    show_all = False
    cards = load(cfg, show_all)
    refresh: Optional[Refresh] = None
    if cards is not None:
        refresh = Refresh(cfg, show_all)
    else:
        sys.stdout.write("\x1b[2mloading...\x1b[0m")
        sys.stdout.flush()
        cards = collect(cfg, show_all)
        save(cfg, show_all, cards)
    board = Board(cards)
    sel = board.index(os.environ.get("PROJ", ""))
    board_sel = -1
    msg = ""
    dirty = False
    redraw = True

    def on_resize(*_):
        nonlocal redraw
        redraw = True

    signal.signal(signal.SIGWINCH, on_resize)

    def refreshed():
        nonlocal refresh, dirty
        if refresh is not None:
            dirty = True
        else:
            refresh = Refresh(cfg, show_all)

    with ui.RawTerminal() as term:
        while True:
            if refresh is not None and not refresh.is_alive():
                done, refresh = refresh, None
                if dirty:
                    dirty = False
                    refresh = Refresh(cfg, show_all)
                elif done.cards is not None:
                    keep = board.cards[sel].dir if 0 <= sel < len(board.cards) else ""
                    board = Board(done.cards)
                    sel = board.index(keep)
                    redraw = True

            if redraw:
                redraw = False
                if not 0 <= sel < len(board.cards):
                    sel = next((board.at(ci, 0) for ci in range(AREA_COL + 1) if board.at(ci, 0) >= 0), -1)
                frame = board.render(cfg, sel)
                frame += f"\n\x1b[2m{'updating…  ' if refresh else ''}{HELP}\x1b[0m\n{msg}"
                msg = ""
                sys.stdout.write("\x1b[H" + frame.replace("\n", "\x1b[K\n") + "\x1b[K\x1b[J")
                sys.stdout.flush()

            key = term.key(0.2)
            if key is None:
                continue
            if key == "":
                break
            redraw = True
            if sel < 0 and key not in "*qgnb":
                continue
            ci, ri = board.pos(sel)
            card = board.cards[sel] if sel >= 0 else None

            if key in ("h", "l"):
                if ci == AREA_COL:
                    continue
                step = -1 if key == "h" else 1
                t = ci + step
                while 0 <= t < AREA_COL:
                    new = board.at(t, ri)
                    if new >= 0:
                        sel = new
                        break
                    t += step
            elif key == "j":
                new = board.at(ci, ri + 1)
                if new == sel and ci < AREA_COL and board.at(AREA_COL, 0) >= 0:
                    board_sel = sel
                    new = board.at(AREA_COL, 0)
                sel = new
            elif key == "k":
                if ri > 0:
                    sel = board.at(ci, ri - 1)
                elif ci == AREA_COL and 0 <= board_sel < len(board.cards) and board.cards[board_sel].state != "area":
                    sel = board_sel
            elif key == "\t":
                if ci == AREA_COL:
                    if 0 <= board_sel < len(board.cards) and board.cards[board_sel].state != "area":
                        sel = board_sel
                    else:
                        sel = next((board.at(c, 0) for c in range(AREA_COL) if board.at(c, 0) >= 0), sel)
                elif board.at(AREA_COL, 0) >= 0:
                    board_sel = sel
                    sel = board.at(AREA_COL, 0)
            elif key in ("\n", "\r"):
                with term.suspend():
                    project.open_project(Project(card.dir, cfg))
                return 0
            elif key in "arcd":
                new_state = {"a": "active", "r": "review", "c": "checkin", "d": "done"}[key]
                if card.state == "area":
                    msg = f"{card.name} is an area; gc-proj set kind= first"
                    continue
                try:
                    set_keys(cfg, Project(card.dir, cfg), [f"state={new_state}"])
                except Fail as e:
                    msg = f"error: {e}"
                    continue
                card.state, card.color = new_state, COLOR[new_state]
                board.layout()
                save(cfg, show_all, board.cards)
                if refresh is not None:
                    dirty = True
            elif key == "u":
                if card.state != "area":
                    Project(card.dir, cfg).update({"state": ""})
                    refreshed()
            elif key == "o":
                sys.stdout.write("\r\x1b[Kopen: r review  m merge request  j Jira")
                sys.stdout.flush()
                sub = term.key()
                if sub == "r":
                    msg = ui.open_url(card.review_url) if card.review_url else \
                        f"no review found for {card.name}; gc-proj set review=N"
                elif sub == "m":
                    msg = ui.open_url(card.mr) if card.mr else \
                        f"no merge request found for {card.name}; gc-proj set mr=URL"
                elif sub == "j":
                    msg = ui.open_url(card.key_url) if card.key_url else \
                        f"no Jira key for {card.name}; gc-proj set jira=KEY"
            elif key == "A":
                if card.state == "area":
                    msg = f"{card.name} is an area itself"
                    continue
                with term.suspend():
                    new = pick_area(cfg, f"area for {card.name}",
                                    [board.cards[i].name for i in board.columns[AREA_COL]])
                sys.stdout.write("\x1b[2J")
                if new is None:
                    continue
                try:
                    set_keys(cfg, Project(card.dir, cfg), [f"area={new}"])
                    msg = f"{card.name}: {new or 'no area'}"
                    refreshed()
                except Fail as e:
                    msg = f"error: {e}"
            elif key == "R":
                sys.stdout.write("\x1b[H\x1b[2J")
                with term.suspend():
                    try:
                        new = ui.prompt(f"rename {card.name} to> ", card.name).strip().replace(" ", "-")
                        if new and new != card.name:
                            rename(cfg, card.dir, new)
                            msg = f"renamed {card.name} to {new}"
                            card.dir, card.name = str(cfg.root / new), new
                            refreshed()
                    except Cancelled:
                        pass
                    except (Fail, OSError) as e:
                        print(f"error: {e}")
                        ui.pause()
                sys.stdout.write("\x1b[2J")
            elif key == "n":
                sys.stdout.write("\x1b[H\x1b[2J")
                with term.suspend():
                    area = card.name if card and card.state == "area" else current_area(cfg)
                    try:
                        if board_new(cfg, area):
                            return 0
                    except Cancelled:
                        pass
                    ui.pause()
                sys.stdout.write("\x1b[2J")
            elif key == "b":
                sys.stdout.write("\x1b[H\x1b[2J")
                with term.suspend():
                    if subprocess.call(self_command("break"), env=self_env()) == 0:
                        return 0
                    ui.pause()
                sys.stdout.write("\x1b[2J")
            elif key == "x":
                if card.state == "area":
                    msg = f"{card.name} is an area; gc-proj set kind= first if it really is finished"
                    continue
                sys.stdout.write("\x1b[H\x1b[2J")
                with term.suspend():
                    subprocess.call(self_command("done"), cwd=os.path.expanduser("~"),
                                    env=self_env(PROJ=card.dir, GC_PROJ_FIXED="1"))
                    ui.pause()
                sys.stdout.write("\x1b[2J")
                refreshed()
            elif key == "*":
                refresh, dirty = None, False
                show_all = not show_all
                keep = card.dir if card else ""
                cards = load(cfg, show_all)
                if cards is not None:
                    refresh = Refresh(cfg, show_all)
                else:
                    sys.stdout.write("\x1b[2J\x1b[H\x1b[2mloading...\x1b[0m")
                    sys.stdout.flush()
                    cards = collect(cfg, show_all)
                    save(cfg, show_all, cards)
                board = Board(cards)
                sel = board.index(keep)
            elif key == "g":
                if refresh is None:
                    refresh = Refresh(cfg, show_all)
            elif key == "q":
                break
    return 0
