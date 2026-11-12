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
from dataclasses import asdict, dataclass, field, fields
from typing import Optional

from . import links, plugins, project, services, tmux, ui
from .commands import pick_sandbox, rename
from .project import Project, all_projects, area_dir, current_area, jira_name, set_keys
from .ui import Cancelled, Fail
from .util import self_command, self_env, write_atomic

COLOR = {"active": "34", "review": "33", "checkin": "35", "done": "32", "waiting": "33", "area": "36"}
LABEL = {"review": "IN REVIEW", "checkin": "CHECKING IN"}
SEARCH_NEXT = (ui.TAB, ui.CTRL_N, *ui.DOWN)
SEARCH_PREV = (ui.SHIFT_TAB, ui.CTRL_P, *ui.UP)
PALETTE = ("34", "33", "35", "32", "31")


def state_color(state: str) -> str:
    return COLOR.get(state) or PALETTE[sum(map(ord, state)) % len(PALETTE)]


def state_label(state: str) -> str:
    return LABEL.get(state) or state.upper()


def help_line(cfg) -> str:
    keys = " ".join(k for _, k in project.states(cfg))
    return (f"hjkl/arrows move  tab areas  / search  enter go  {keys} set state  u auto state  A area  R rename  "
            "o+r/m/j… open review/MR/Jira/…  n new  b break pane  x done  * all  g refresh  q quit")


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
    links: dict = field(default_factory=dict)


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
    names = project.state_names(cfg)
    for p in projs:
        state, key = p.get("state"), p.jira_key
        branch = branches[p.path]
        info = plugins.project_info(cfg, p, plugin_ctxs, branch)
        review = links.find_review(p, reviews, info.changes) if services.rb_enabled(cfg) else p.get("review")
        mr = links.find_mr(p, mrs, branch)
        if not state or state not in names:
            state = "review" if (review or mr) and "review" in names else names[0]
        state = info.state if info.state in names else state
        color = info.color or state_color(state)
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
            key_url=services.jira_browse(cfg, key) if key and services.jira_enabled(cfg) else "",
            links=info.links))

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
    def __init__(self, cards: list[Card], cfg):
        self.cards = cards
        self.states = project.state_names(cfg)
        self.area_col = len(self.states)
        self.layout()

    def layout(self) -> None:
        # A card cached under a state that's no longer configured goes in the first column.
        first = self.states[0]
        self.columns = [[i for i, c in enumerate(self.cards)
                         if c.state == s or (s == first and c.state not in self.states and c.state != "area")]
                        for s in self.states]
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

    def matches(self, query: str) -> list[int]:
        """Cards whose name or detail holds query, ignoring case, in board order."""
        q = query.lower()
        return [i for col in self.columns for i in col
                if q in self.cards[i].name.lower() or q in self.cards[i].detail.lower()]

    def render(self, cfg, selected: int = -1, cols: Optional[int] = None, query: Optional[str] = None) -> str:
        current = os.environ.get("PROJ", "")
        cols = cols or int(os.environ.get("BOARD_COLS") or 0) or ui.term_cols()
        width = max((cols - 2) // len(self.states) - 2, 12)
        lines = []
        hits = set(self.matches(query)) if query else None

        def card_style(i):
            style = f"1;{self.cards[i].color}"
            if hits is not None and i not in hits:
                style = "2"
            if i == selected:
                style += ";7"
            return style

        def mark(i):
            return "▸" if self.cards[i].dir == current else " "

        lines.append("".join(ui.styled(ui.fit(state_label(s), width), f"1;{state_color(s)}") + "  " for s in self.states))
        lines.append("".join(ui.dim("─" * width) + "  " for _ in self.states))
        rows = max((len(c) for c in self.columns[:self.area_col]), default=0)
        for r in range(rows):
            row = [col[r] if r < len(col) else -1 for col in self.columns[:self.area_col]]
            line = ""
            for i in row:
                if i < 0:
                    line += " " * width + "  "
                else:
                    line += ui.styled(ui.fit(mark(i) + self.cards[i].name, width), card_style(i)) + "  "
            lines.append(line)
            if any(i >= 0 and self.cards[i].detail for i in row):
                line = ""
                for i in row:
                    if i < 0:
                        line += " " * width + "  "
                    else:
                        line += ui.dim(ui.fit("  " + self.cards[i].detail, width)) + "  "
                lines.append(line)

        areas = self.columns[self.area_col]
        if areas:
            total = len(self.states) * (width + 2) - 2
            name_w, touched_w = 18, 16
            kids_w = max(total - name_w - touched_w - 6, 10)
            now = time.time()
            stale = int(cfg["area_stale_days"]) * 86400
            lines.append("")
            lines.append(ui.styled("AREAS", f"1;{COLOR['area']}") + " " + ui.dim("─" * (total - 6)))
            for i in areas:
                c = self.cards[i]
                touched = f"touched {age_label(c.touched)}" if c.touched > 0 else "never touched"
                flag, style = " ", f"1;{c.color}"
                if stale and (c.touched == 0 or now - c.touched >= stale):
                    flag, style = "?", "1;33"
                if hits is not None and i not in hits:
                    style = "2"
                if i == selected:
                    style += ";7"
                lines.append(f"{ui.styled(ui.fit(mark(i) + c.name, name_w), style)}  "
                             f"{ui.dim(ui.fit(touched, touched_w))}  "
                             f"{ui.fit(c.kids, kids_w)}  {ui.styled(flag, '1;33')}")
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
    sys.stdout.write(Board(cards, cfg).render(cfg))
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
            dir_desc = f"{d} {ui.dim('(area dir)')}" if d else f"{path} {ui.dim('(current dir)')}"
        elif cfg.text("sandboxes"):
            dir_desc = ui.dim("pick a sandbox on create")
        else:
            dir_desc = ui.dim("type a dir on create")
        if jira_mode == "attach":
            jira_desc = jira
        elif jira_mode == "create":
            jira_desc = f"new {jira_type}: {summary}"
        else:
            jira_desc = "(none)"
        out = [ui.HOME + ui.CLEAR_SCREEN + ui.bold("new project"), "",
               f"  name  {shown:<50} {ui.dim('r rename')}",
               f"  area  {area or '(none)':<50} {ui.dim('a change')}",
               f"  dir   {dir_desc}",
               "        " + ui.dim("t new tree  s pick sandbox  d type a dir  p project dir  (again for default)")]
        if services.jira_enabled(cfg):
            out.append(f"  jira  {jira_desc:<50} {ui.dim('ja attach  jc create  jx none')}")
        out += ["", ui.dim("enter create  q cancel")]
        if msg:
            out += ["", msg]
            msg = ""
        sys.stdout.write("\n".join(out) + "\n")
        sys.stdout.flush()

        key = ui.getch()
        if key in ui.ENTER:
            break
        if key == "q":
            print("cancelled")
            return False
        if key == ui.ESC:
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
        sys.stdout.write(ui.dim("loading..."))
        sys.stdout.flush()
        cards = collect(cfg, show_all)
        save(cfg, show_all, cards)
    state_keys = {k: n for n, k in project.states(cfg)}
    help_text = help_line(cfg)
    board = Board(cards, cfg)
    sel = board.index(os.environ.get("PROJ", ""))
    board_sel = -1
    query: Optional[str] = None
    search_from = ""
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
                    board = Board(done.cards, cfg)
                    sel = board.index(keep)
                    redraw = True

            if redraw:
                redraw = False
                if not 0 <= sel < len(board.cards):
                    sel = next((board.at(ci, 0) for ci in range(board.area_col + 1) if board.at(ci, 0) >= 0), -1)
                frame = board.render(cfg, sel, query=query)
                if query is None:
                    frame += "\n" + ui.dim(f"{'updating…  ' if refresh else ''}{help_text}") + f"\n{msg}"
                else:
                    hits = board.matches(query) if query else []
                    count = f"{hits.index(sel) + 1}/{len(hits)}" if sel in hits else f"0/{len(hits)}"
                    cursor = ui.styled(" ", "7")
                    hint = f"{count if query else ''}  tab/↓ next  shift-tab/↑ prev  enter select  esc cancel"
                    frame += f"\n/{query}{cursor}  {ui.dim(hint)}\n"
                msg = ""
                sys.stdout.write(ui.HOME + frame.replace("\n", ui.CLEAR_EOL + "\n") + ui.CLEAR_EOL + ui.CLEAR_BELOW)
                sys.stdout.flush()

            key = term.key(0.2, text=query is not None)
            if key is None:
                continue
            if key == "":
                break
            redraw = True

            if query is not None:
                start = board.index(search_from)
                if key in ui.ENTER:
                    if not query or not board.matches(query):
                        sel = start
                    elif 0 <= sel and board.cards[sel].state == "area" and 0 <= start < len(board.cards) \
                            and board.cards[start].state != "area":
                        board_sel = start
                    query = None
                    continue
                if key == ui.ESC:
                    query, sel = None, start
                    continue
                if key in SEARCH_NEXT or key in SEARCH_PREV:
                    hits = board.matches(query) if query else []
                    if hits:
                        step = 1 if key in SEARCH_NEXT else -1
                        if sel in hits:
                            sel = hits[(hits.index(sel) + step) % len(hits)]
                        else:
                            sel = hits[0 if step > 0 else -1]
                    continue
                if key in ui.BACKSPACE:
                    if not query:
                        query, sel = None, start
                        continue
                    query = query[:-1]
                elif key == ui.CTRL_U:
                    query = ""
                elif key.isprintable():
                    query += key
                else:
                    continue
                hits = board.matches(query) if query else []
                sel = hits[0] if hits else start
                continue

            if sel < 0 and key not in "*qgnb":
                continue
            ci, ri = board.pos(sel)
            card = board.cards[sel] if sel >= 0 else None

            if key in ("h", "l"):
                if ci == board.area_col:
                    continue
                step = -1 if key == "h" else 1
                t = ci + step
                while 0 <= t < board.area_col:
                    new = board.at(t, ri)
                    if new >= 0:
                        sel = new
                        break
                    t += step
            elif key == "j":
                new = board.at(ci, ri + 1)
                if new == sel and ci < board.area_col and board.at(board.area_col, 0) >= 0:
                    board_sel = sel
                    new = board.at(board.area_col, 0)
                sel = new
            elif key == "k":
                if ri > 0:
                    sel = board.at(ci, ri - 1)
                elif ci == board.area_col and 0 <= board_sel < len(board.cards) and board.cards[board_sel].state != "area":
                    sel = board_sel
            elif key == ui.TAB:
                if ci == board.area_col:
                    if 0 <= board_sel < len(board.cards) and board.cards[board_sel].state != "area":
                        sel = board_sel
                    else:
                        sel = next((board.at(c, 0) for c in range(board.area_col) if board.at(c, 0) >= 0), sel)
                elif board.at(board.area_col, 0) >= 0:
                    board_sel = sel
                    sel = board.at(board.area_col, 0)
            elif key == "/":
                query, search_from = "", card.dir
            elif key in ("\n", "\r"):
                with term.suspend():
                    project.open_project(Project(card.dir, cfg))
                return 0
            elif key in state_keys:
                new_state = state_keys[key]
                if card.state == "area":
                    msg = f"{card.name} is an area; gc-proj set kind= first"
                    continue
                try:
                    set_keys(cfg, Project(card.dir, cfg), [f"state={new_state}"])
                except Fail as e:
                    msg = f"error: {e}"
                    continue
                card.state, card.color = new_state, state_color(new_state)
                board.layout()
                save(cfg, show_all, board.cards)
                if refresh is not None:
                    dirty = True
            elif key == "u":
                if card.state != "area":
                    Project(card.dir, cfg).update({"state": ""})
                    refreshed()
            elif key == "o":
                extra = "".join(f"  {k} {label}" for k, (label, _) in card.links.items())
                sys.stdout.write(f"\r{ui.CLEAR_EOL}open: r review  m merge request  j Jira{extra}")
                sys.stdout.flush()
                sub = term.key()
                if sub in card.links:
                    msg = ui.open_url(card.links[sub][1])
                elif sub == "r":
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
                                    [board.cards[i].name for i in board.columns[board.area_col]])
                sys.stdout.write(ui.CLEAR_SCREEN)
                if new is None:
                    continue
                try:
                    set_keys(cfg, Project(card.dir, cfg), [f"area={new}"])
                    msg = f"{card.name}: {new or 'no area'}"
                    refreshed()
                except Fail as e:
                    msg = f"error: {e}"
            elif key == "R":
                sys.stdout.write(ui.HOME + ui.CLEAR_SCREEN)
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
                sys.stdout.write(ui.CLEAR_SCREEN)
            elif key == "n":
                sys.stdout.write(ui.HOME + ui.CLEAR_SCREEN)
                with term.suspend():
                    area = card.name if card and card.state == "area" else current_area(cfg)
                    try:
                        if board_new(cfg, area):
                            return 0
                    except Cancelled:
                        pass
                    ui.pause()
                sys.stdout.write(ui.CLEAR_SCREEN)
            elif key == "b":
                sys.stdout.write(ui.HOME + ui.CLEAR_SCREEN)
                with term.suspend():
                    if subprocess.call(self_command("break"), env=self_env()) == 0:
                        return 0
                    ui.pause()
                sys.stdout.write(ui.CLEAR_SCREEN)
            elif key == "x":
                if card.state == "area":
                    msg = f"{card.name} is an area; gc-proj set kind= first if it really is finished"
                    continue
                sys.stdout.write(ui.HOME + ui.CLEAR_SCREEN)
                with term.suspend():
                    subprocess.call(self_command("done"), cwd=os.path.expanduser("~"),
                                    env=self_env(PROJ=card.dir, GC_PROJ_FIXED="1"))
                    ui.pause()
                sys.stdout.write(ui.CLEAR_SCREEN)
                refreshed()
            elif key == "*":
                refresh, dirty = None, False
                show_all = not show_all
                keep = card.dir if card else ""
                cards = load(cfg, show_all)
                if cards is not None:
                    refresh = Refresh(cfg, show_all)
                else:
                    sys.stdout.write(ui.CLEAR_SCREEN + ui.HOME + ui.dim("loading..."))
                    sys.stdout.flush()
                    cards = collect(cfg, show_all)
                    save(cfg, show_all, cards)
                board = Board(cards, cfg)
                sel = board.index(keep)
            elif key == "g":
                if refresh is None:
                    refresh = Refresh(cfg, show_all)
            elif key == "q":
                break
    return 0
