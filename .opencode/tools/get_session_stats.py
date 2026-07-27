#!/usr/bin/env python3
"""Get token usage and session stats for the current opencode session."""

import json
import os
import sys
import platform


def get_storage_path():
    """Get the opencode storage path based on OS."""
    if platform.system() == "Windows":
        base = os.environ.get("USERPROFILE", os.path.expanduser("~"))
        return os.path.join(base, ".local", "share", "opencode", "storage")
    else:
        return os.path.join(
            os.path.expanduser("~"), ".local", "share", "opencode", "storage"
        )


def get_session_id_fallback(storage_path):
    """Get session ID by finding most recently modified message directory."""
    message_dir = os.path.join(storage_path, "message")

    if not os.path.isdir(message_dir):
        raise RuntimeError(f"Message directory not found: {message_dir}")

    sessions = [d for d in os.listdir(message_dir) if d.startswith("ses_")]

    if not sessions:
        raise RuntimeError("No session directories found")

    def get_mtime(session):
        msg_path = os.path.join(message_dir, session)
        if os.path.isdir(msg_path):
            return os.path.getmtime(msg_path)
        return 0

    sessions.sort(key=get_mtime, reverse=True)
    return sessions[0]


def get_session_stats(storage_path, session_id):
    """Extract all stats from the session."""
    input_tokens = 0
    output_tokens = 0
    user_word_count = 0
    lines_added = 0
    lines_deleted = 0
    files_changed = 0
    msg_ids = set()

    message_dir = os.path.join(storage_path, "message", session_id)
    session_file = os.path.join(storage_path, "session", "global", f"{session_id}.json")
    part_dir = os.path.join(storage_path, "part")

    if os.path.isdir(message_dir):
        for fname in os.listdir(message_dir):
            if fname.endswith(".json"):
                fpath = os.path.join(message_dir, fname)
                try:
                    with open(fpath, "r") as f:
                        msg = json.load(f)

                    if "tokens" in msg:
                        input_tokens += msg["tokens"].get("input", 0)
                        output_tokens += msg["tokens"].get("output", 0)

                    if msg.get("role") == "user":
                        content = msg.get("summary", {}).get("title", "")
                        if content:
                            user_word_count += len(content.split())

                    msg_ids.add(fname[:-5])
                except (json.JSONDecodeError, IOError):
                    pass

    if os.path.isfile(session_file):
        try:
            with open(session_file, "r") as f:
                session_data = json.load(f)
                summary = session_data.get("summary", {})
                files_changed = summary.get("files", 0)
        except (json.JSONDecodeError, IOError):
            pass

    for msg_id in msg_ids:
        msg_dir = os.path.join(part_dir, msg_id)
        if os.path.isdir(msg_dir):
            for fname in os.listdir(msg_dir):
                if fname.endswith(".json"):
                    fpath = os.path.join(msg_dir, fname)
                    try:
                        with open(fpath, "r") as f:
                            data = json.load(f)

                        tool = data.get("tool")
                        state = data.get("state", {})
                        inp = state.get("input", {})

                        if tool == "write":
                            content = inp.get("content", "")
                            if content:
                                lines_added += len(content.split("\n"))
                        elif tool == "edit":
                            old_str = inp.get("oldString", "")
                            new_str = inp.get("newString", "")
                            old_lines = len(old_str.split("\n")) if old_str else 0
                            new_lines = len(new_str.split("\n")) if new_str else 0
                            lines_added += new_lines
                            lines_deleted += old_lines
                    except (json.JSONDecodeError, IOError):
                        pass

    return {
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "user_word_count": user_word_count,
        "lines_added": lines_added,
        "lines_deleted": lines_deleted,
        "files_changed": files_changed,
    }


if __name__ == "__main__":
    storage_path = get_storage_path()
    session_id = os.environ.get("OPENCODE_SESSION_ID")
    if not session_id:
        session_id = get_session_id_fallback(storage_path)

    stats = get_session_stats(storage_path, session_id)
    print(json.dumps(stats))
