#!/usr/bin/env python3
"""Mirrors ConferenceLinkResolver heuristics for quick CI-less checks."""

import re

URL_IN_TEXT = re.compile(r"https?://[^\s<>\"\]\)]+")


def first_url(text: str) -> str | None:
    m = URL_IN_TEXT.search(text)
    if not m:
        return None
    raw = m.group(0).rstrip(",.;)")
    return raw


def is_likely_conference(url: str) -> bool:
    u = url.lower()
    if not u.startswith(("http://", "https://")):
        return False
    if "meet.google.com" in u:
        return True
    if "zoom.us" in u:
        return True
    if "teams.microsoft.com" in u:
        return True
    if "google.com" in u and "calendar/event" in u:
        return False
    return "meet" in u or "/j/" in u


def test_notes_google_meet():
    notes = "Join with Google Meet\nhttps://meet.google.com/abc-defg-hij\n"
    url = first_url(notes)
    assert url == "https://meet.google.com/abc-defg-hij"
    assert is_likely_conference(url)


def test_location_zoom():
    loc = "https://us02web.zoom.us/j/123456789"
    assert is_likely_conference(loc)


if __name__ == "__main__":
    test_notes_google_meet()
    test_location_zoom()
    print("ok")
