"""Jira, Review Board and GitLab: each is off until its url is configured."""
from __future__ import annotations

import base64
import os
from dataclasses import dataclass
from urllib.parse import quote, urlparse

from . import ui
from .util import HttpError, http_json, netrc_entry


def _host(url: str) -> str:
    return urlparse(url).hostname or ""


def jira_enabled(cfg) -> bool:
    return bool(cfg["jira.url"])


def jira_browse(cfg, key: str) -> str:
    return f"{cfg.text('jira.url').rstrip('/')}/browse/{key}"


def jira_create(cfg, summary: str) -> str:
    """Create an issue assigned to me and return its key. The API token comes
    from $ATLASSIAN_API_TOKEN or the Jira host's ~/.netrc entry."""
    if not jira_enabled(cfg):
        raise ui.Fail("set jira.url in the config to create issues")
    if not summary:
        raise ui.Fail("jira-new needs a summary")
    project = cfg.text("jira.project")
    if not project:
        raise ui.Fail("set jira.project in the config to create issues")
    url = cfg.text("jira.url").rstrip("/")
    host = _host(url)
    login = cfg.text("jira.user")
    token = os.environ.get("ATLASSIAN_API_TOKEN", "")
    if not token:
        netrc_login, token = netrc_entry(host)
        if "@" in netrc_login:
            login = netrc_login
    if not token:
        raise ui.Fail(f"no Jira API token; set ATLASSIAN_API_TOKEN or add {host} to ~/.netrc")
    if not login:
        raise ui.Fail("no Jira login; set jira.user in the config")
    creds = base64.b64encode(f"{login}:{token}".encode()).decode()
    headers = {"Authorization": "Basic " + creds}

    def call(method, path, body=None):
        try:
            return http_json(url + path, headers=headers, method=method, body=body, timeout=30)
        except HttpError as e:
            raise ui.Fail(f"Jira {method} {path}: {e}") from None

    me = call("GET", "/rest/api/3/myself")
    issue = call("POST", "/rest/api/3/issue", {"fields": {
        "project": {"key": project},
        "issuetype": {"name": cfg.text("jira.type")},
        "summary": summary,
        "assignee": {"accountId": me["accountId"]},
    }})
    return issue["key"]


@dataclass
class Review:
    id: str
    change: str
    summary: str


def rb_enabled(cfg) -> bool:
    return bool(cfg["reviewboard.url"])


def rb_review_url(cfg, review_id: str) -> str:
    return f"{cfg.text('reviewboard.url').rstrip('/')}/r/{review_id}/"


def pending_reviews(cfg) -> list[Review]:
    """My pending review requests."""
    url = cfg.text("reviewboard.url").rstrip("/")
    _, token = netrc_entry(_host(url))
    if not token:
        return []
    user = quote(cfg.text("reviewboard.user"))
    try:
        data = http_json(f"{url}/api/review-requests/?from-user={user}&status=pending&max-results=200",
                         headers={"Authorization": f"token {token}"})
    except HttpError:
        return []
    return [Review(str(r["id"]), str(r.get("changenum") or "-"), r.get("summary", ""))
            for r in data.get("review_requests", [])]


@dataclass
class MergeRequest:
    iid: str
    source_branch: str
    url: str
    title: str


def gitlab_enabled(cfg) -> bool:
    return bool(cfg["gitlab.url"])


def pending_mrs(cfg) -> list[MergeRequest]:
    """My open merge requests."""
    url = cfg.text("gitlab.url").rstrip("/")
    _, token = netrc_entry(_host(url))
    if not token:
        return []
    try:
        data = http_json(f"{url}/api/v4/merge_requests?scope=created_by_me&state=opened&per_page=100",
                         headers={"PRIVATE-TOKEN": token})
    except HttpError:
        return []
    return [MergeRequest(str(m["iid"]), m.get("source_branch", ""), m.get("web_url", ""), m.get("title", ""))
            for m in data]
