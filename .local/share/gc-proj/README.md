# gc-proj

One directory and one tmux session per project. Projects live under a root
(`~/proj` by default). Each has a `.proj.json` that says where its source is and
tracks its state through review and check-in. Areas are long-lived projects that
group others. `gc-proj board` shows everything by state and lets you jump, rename,
re-file and finish projects.

Python 3.9+, standard library only. The source is in `~/repos/gc-proj`, a link
to `~/.local/share/gc-proj`, so edits there take effect immediately. `gc-proj`
there is the launcher, and `~/bin/gc-proj` links to it. `gc-proj help` lists the
commands.

## Project file

`.proj.json` is a flat JSON object of strings, written by `gc-proj new`/`set`/`cd`:

```json
{
  "dir": "/home/me/src/thing",
  "area": "infra",
  "state": "review",
  "build": "cd \"$dir\" && make"
}
```

`gc-proj keys` describes every key, including the ones plugins add.

Scripts should ask gc-proj instead of reading it: `gc-proj dir [project]` prints
the working dir (resolving `branch=`), `gc-proj get <key> [-p project]` prints a
key, and `gc-proj get` prints all of them.

## Settings

`~/.config/gc-proj/config.toml`, then `config.local.toml` for site settings.
Every setting can be overridden with `GC_PROJ_<SECTION>_<KEY>`, for example
`GC_PROJ_JIRA_PROJECT`. `gc-proj config` shows each value and where it came from.

States are whatever `states` lists. A project with no state (or one no longer listed)
is in the first; `review`, if listed, also catches projects with an open review or MR,
and `done` tells `gc-proj done` the work is finished. A state's board key defaults to
its first letter; keys the board already uses (h j k l u o A R n b x * g q /) need
`name:key`.

No settings are needed: without them `new` asks for a dir (or uses the area's),
and projects, areas, states, the board, `done` and `prune` all work. Each extra
is off until configured:

```toml
root = "~/proj"
sandboxes = "~/src/*"           # offered by new and cd when no dir is given
sandbox_subdir = ""             # appended to a picked sandbox
branch_prefix = "me/"           # for new --tree branches
new_tree = false                # make --tree the default for new
area_stale_days = 21            # flag areas untouched this long; 0 turns it off
states = "active review checkin done"  # board columns in order; name or name:key, first is the default

[worktrees]                     # branch= projects share a pool of worktrees; see activate
repo = "~/src/big-repo"
subdir = ""
main_branch = "main"
upstream = "origin/main"        # where submitted work lands

[trees]                         # new --tree makes one, done drops it
new = "git -C ~/src/repo worktree add -q -b {branch} ~/trees/{name} >&2"
drop = "git -C ~/src/repo worktree remove ~/trees/{name}"
path = "~/trees/{name}"
exists = ""                     # command that succeeds while the tree exists; default: path is a dir

[jira]                          # keys on the board, jira-new, done opens the issue
url = "https://example.atlassian.net"
project = "ABC"
user = "me@example.com"

[reviewboard]                   # review requests on the board and in done
url = "https://rb.example.com"

[gitlab]                        # merge requests on the board and in done
url = "https://gitlab.example.com"
```

Tree commands run in bash with `{name}`, `{branch}` and `{repo}` replaced (shell-quoted).
`{repo}` is the git repo of the new project's area, so one set of commands makes trees in
any area's repo; it's kept in the project's `tree_repo` key for `done`.
`trees.new` may print the tree's path as its last line of output.

API tokens come from `~/.netrc` entries for each host (Jira also takes
`$ATLASSIAN_API_TOKEN`).

## Plugins

Every `~/.config/gc-proj/plugins/*.py` is loaded, and may define any of the hooks
listed in `gc_proj/plugins.py`: what a project's board card shows, whether its
work is checked in, extra `done` steps, and checks before touching worktrees.
Site-specific workflows (a version control system, a CI's job states) go there
rather than in the core.
