from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Iterator, Optional

from . import projfile, tmux, worktrees
from .config import Config
from .ui import Fail

# Board keys that a state can't take.
RESERVED_KEYS = set("hjkluoARnbx*gq/")
KEYS = {
    "dir": "the source tree to work in",
    "branch": "worktree branch; overrides dir with the worktree holding it",
    "subdir": "dir within the branch's worktree, if not worktrees.subdir",
    "tree": "tree made by new --tree; done offers to drop it",
    "tree_repo": "the area's repo the tree was made in, when the trees commands use {repo}",
    "state": "one of the states setting (default active, review, checkin, done)",
    "kind": '"area" for a long-lived area of responsibility: it gets a panel on the board '
            "and done and prune leave it alone",
    "area": "the area the project belongs to",
    "jira": "Jira key, if the name doesn't start with one (cs12345-...)",
    "review": "review request, if it can't be found by cl or the Jira key",
    "mr": "merge request url, if it can't be found by branch or the Jira key",
    "build, test, ...": "shell commands for run",
}
PRUNED_DIRS = {".git", "target", "node_modules"}


class Project:
    def __init__(self, path, cfg: Config):
        self.path = Path(path)
        self.cfg = cfg
        self._keys: Optional[dict[str, str]] = None

    def __repr__(self):
        return f"Project({str(self.path)!r})"

    @property
    def name(self) -> str:
        return self.path.name

    @property
    def session(self) -> str:
        return tmux.session_name(self.name)

    def exists(self) -> bool:
        return projfile.has_file(self.path)

    @property
    def keys(self) -> dict[str, str]:
        if self._keys is None:
            self._keys = projfile.read(self.path)
        return self._keys

    def get(self, key: str) -> str:
        return self.keys.get(key, "")

    def update(self, values: dict[str, str]) -> None:
        projfile.write(self.path, values)
        self._keys = None

    @property
    def is_area(self) -> bool:
        return self.get("kind") == "area"

    @property
    def area(self) -> str:
        """Its own name if it's an area, else the area it belongs to."""
        if self.is_area:
            return self.name
        return self.get("area")

    def working_dir(self) -> str:
        """dir, or for a branch= project the worktree that has the branch checked out."""
        d = self.get("dir")
        branch = self.get("branch")
        if branch and worktrees.enabled(self.cfg):
            slot = worktrees.branch_slot(self.cfg, branch)
            if slot:
                subdir = self.get("subdir") or self.cfg.text("worktrees.subdir")
                d = os.path.join(slot, subdir) if subdir else slot
        return d

    @property
    def jira_key(self) -> str:
        return self.get("jira") or jira_key_from_name(self.name)

    def notes_file(self) -> Optional[Path]:
        for name in ("notes.md", "notes.txt"):
            f = self.path / name
            if f.is_file():
                return f
        return None

    def last_touched(self) -> int:
        """Newest mtime of anything in the project, itself included."""
        return newest_mtime(self.path, include_root=True)

    def contents_touched(self) -> int:
        """Newest mtime of anything in the project other than its project file; 0 if nothing."""
        return newest_mtime(self.path, include_root=False,
                            skip={projfile.FILE})


def jira_key_from_name(name: str) -> str:
    """CS-59850 from a name like cs59850-foo or cs-59850."""
    m = re.match(r"^([a-z]{2,})-?([0-9]+)(-|$)", name)
    if not m:
        return ""
    return f"{m.group(1).upper()}-{m.group(2)}"


def jira_name(name: str, key: str) -> str:
    """name prefixed with Jira key key (cs12345-foo), unless it already starts with it."""
    if not key:
        return name
    prefix = key.lower().replace("-", "")
    if name.lower().startswith(key.lower()) or name.lower().startswith(prefix):
        return name
    return f"{prefix}-{name}"


def newest_mtime(root: Path, include_root: bool, skip: frozenset = frozenset()) -> int:
    newest = 0
    if include_root:
        try:
            newest = int(root.stat().st_mtime)
        except OSError:
            return 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in PRUNED_DIRS and d not in skip]
        for name in dirnames + [f for f in filenames if f not in PRUNED_DIRS and f not in skip]:
            try:
                t = int(os.lstat(os.path.join(dirpath, name)).st_mtime)
            except OSError:
                continue
            if t > newest:
                newest = t
    return newest


def check_name(name: str) -> None:
    if not name or "/" in name or name.startswith(".") or name == "archive":
        raise Fail(f"bad project name '{name}'")


def all_projects(cfg: Config) -> Iterator[Project]:
    try:
        entries = sorted(os.listdir(cfg.root))
    except OSError:
        return
    for name in entries:
        if name == "archive":
            continue
        p = Project(cfg.root / name, cfg)
        if p.path.is_dir() and p.exists():
            yield p


def areas(cfg: Config) -> list[Project]:
    return [p for p in all_projects(cfg) if p.is_area]


def resolve(cfg: Config, name_or_path: str) -> Project:
    """A project by name or by path."""
    if "/" in name_or_path or name_or_path in (".", ".."):
        path = Path(os.path.abspath(os.path.expanduser(name_or_path)))
    else:
        path = cfg.root / name_or_path
    p = Project(path, cfg)
    if not p.exists():
        raise Fail(f"no project file in {path}")
    return p


def env_proj() -> str:
    return os.environ.get("PROJ", "")


def _cwd() -> str:
    pwd = os.environ.get("PWD", "")
    try:
        if pwd and os.path.samefile(pwd, "."):
            return pwd
    except OSError:
        pass
    return os.getcwd()


def find_current(cfg: Config) -> Optional[Project]:
    """$PROJ, else the project the current dir is in."""
    if env_proj():
        return Project(env_proj(), cfg)
    root = str(cfg.root)
    cwd = _cwd()
    if cwd.startswith(root + "/"):
        first = cwd[len(root) + 1:].split("/", 1)[0]
        return Project(cfg.root / first, cfg)
    return None


def require_current(cfg: Config) -> Project:
    p = find_current(cfg)
    if p is None:
        raise Fail(f"can't determine current project (no $PROJ, not under {cfg.root})")
    return p


def require_env(cfg: Config) -> Project:
    if not env_proj():
        raise Fail("$PROJ is not set")
    return Project(env_proj(), cfg)


def current_area(cfg: Config) -> str:
    """The area of $PROJ, if any."""
    if not env_proj():
        return ""
    p = Project(env_proj(), cfg)
    if not p.exists():
        return ""
    return p.area


def check_area(cfg: Config, area: str) -> None:
    if area and not Project(cfg.root / area, cfg).is_area:
        raise Fail(f"{area} is not an area (a project with kind=area)")


def area_dir(cfg: Config, area: str) -> str:
    return Project(cfg.root / area, cfg).working_dir()


def states(cfg: Config) -> list[tuple[str, str]]:
    """The configured states as (name, board key), in board order."""
    out: list[tuple[str, str]] = []
    for word in cfg.text("states").split():
        name, _, key = word.partition(":")
        key = key or name[:1]
        if not re.fullmatch(r"[a-z][a-z0-9_-]*", name) or len(key) != 1:
            raise Fail(f"states: bad entry '{word}' (want name or name:key)")
        if key in RESERVED_KEYS:
            raise Fail(f"states: '{name}' can't use board key '{key}'; give it one with {name}:<key>")
        if any(n == name or k == key for n, k in out):
            raise Fail(f"states: '{word}' repeats a name or key")
        out.append((name, key))
    if not out:
        raise Fail("states: no states configured")
    return out


def state_names(cfg: Config) -> list[str]:
    return [n for n, _ in states(cfg)]


def default_state(cfg: Config) -> str:
    """The state of a project that has none (or one no longer configured)."""
    return state_names(cfg)[0]


def check_state(cfg: Config, state: str) -> None:
    names = state_names(cfg)
    if state not in names:
        raise Fail(f"state must be one of: {' '.join(names)}")


def set_keys(cfg: Config, project: Project, pairs: list[str]) -> None:
    """Validate and set key=value pairs; an empty value removes the key."""
    if not pairs:
        raise Fail("usage: gc-proj set key=value ...")
    updates = {}
    for kv in pairs:
        m = re.match(r"^([a-z_]+)=(.*)$", kv, re.S)
        if not m:
            raise Fail(f"expected key=value, got '{kv}'")
        key, value = m.groups()
        if key == "state" and value:
            check_state(cfg, value)
        if key == "kind" and value not in ("", "area"):
            raise Fail("kind must be area or empty")
        if key == "area":
            check_area(cfg, value)
        updates[key] = value
    project.update(updates)


def open_project(project: Project) -> int:
    start = project.working_dir() or str(project.path)
    if not os.path.isdir(start):
        start = str(project.path)
    return tmux.open_session(project.session, start, str(project.path))
