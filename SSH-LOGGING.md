# 🛠️ Project: SSH Session Logging & Clipboard/File Transfer Helper

## 🎯 Goal

To build a developer-focused system that:

* Transparently logs all SSH sessions to the local machine
* Allows remote clipboard or small binary file content to be pushed back to the local machine without SCP
* Requires **no configuration** on remote servers
* Works **entirely from the local Mac**, even if running from an external SSD

---

## ✅ Phase 1: SSH Logging (Completed)

### Summary

* Implemented a custom `ssh` wrapper script in `~/.init/bin/ssh`
* Uses `script -q` to log entire SSH session locally with session output
* Stores logs in `~/Projects/logs/<host>/<host>_<YYYY-MM-DD>_ssh.log` to consolidate sessions per day
* Adds metadata headers and footers including command, start time, end time, duration, and exit code
* Clearly separates metadata from session content using visually distinct markers
* Avoided `~/.zshrc` function wrapping for clarity and discoverability (`which ssh` works correctly)
* Bypasses the logging wrapper when stdin or stdout are not a terminal (`[[ -t 0 && -t 1 ]]`) to support non-interactive uses like `git pull`, `rsync`, or remote commands
* Chose `~/Projects/logs/` as a safe and SIP-avoiding storage location on external drives

### Example Output

```text
=== BEGIN SSH ===
Command:    ssh propcheck-digitalocean
Start Time: 2025-07-20 06:19:09
End Time:   2025-07-20 06:19:25
Duration:   0:00:16
Exit Code:  0
BEGIN SSH session content
==============================================================================
[... SSH session output ...]
==============================================================================
END SSH session content
=== END SSH ===
```

### Notes

* `script -q` used for macOS compatibility (no `-f` flag)
* Log files are appended per host per day
* ANSI codes from SSH session are retained; can optionally be stripped later
* Wrapper bypasses logging entirely for non-TTY calls (fixing `git pull` and similar failures)
* Legacy special-case logic for `git@github.com` and `SSH_ORIGINAL_COMMAND` was removed in favor of general-purpose TTY detection

---

## ✅ Phase 1B: SCP Logging (Completed)

### Summary

* Implemented a custom `scp` wrapper script in `~/.init/bin/scp`
* Logs each `scp` invocation to `~/Projects/logs/<host>/<host>_<YYYY-MM-DD>_scp.log`
* Appends multiple transfers to a single file per day per host
* Logs command, start time, end time, duration, and exit code
* Does **not** interfere with real-time SCP output or progress bars

### Example Log Entry

```text
=== BEGIN SCP ===
Command:    scp propcheck-digitalocean:/root/root-files.txt .
Start Time: 2025-07-20 06:08:23
End Time:   2025-07-20 06:08:24
Duration:   0:00:01
Exit Code:  0
=== END SCP ===
```

### Notes

* SCP output is shown live to terminal (no `tee`, no buffering)
* Duration calculated with `date +%s` before and after
* Uses only metadata logging, not full transfer capture

---

## 🔜 Phase 2: Remote Clipboard / File Transfer (Planned)

### Objective

Enable pushing clipboard contents or small files from the SSH session back to the Mac via the existing SSH tunnel, without requiring SCP or file juggling.

### Requirements

* Must not require remote configuration (i.e., no `.zshrc` or daemons on the server)
* Should work with reverse port forwarding
* Ideally uses a persistent agent on the Mac to receive content

### Architecture Sketch

1. **Local Agent on Mac (always running)**

    * Listens on `localhost:22222` (or Unix socket)
    * Can write to temp files, copy to clipboard, etc.
    * Runs via `launchd` as `~/Library/LaunchAgents/sshClipboard.plist`

2. **Reverse SSH Tunnel**

    * From remote server, establish with:

      ```bash
      ssh -R 22222:localhost:22222 user@server
      ```

3. **Remote Helper Script (one-liner)**

    * Pipe clipboard or file into:

      ```bash
      cat file | nc localhost 22222
      ```

4. **Optional Protocol Layer**

    * Add header lines to indicate `CLIPBOARD`, `SAVE`, `APPEND`, etc.
    * Enable richer automation in the local agent

---

## 📝 Future Enhancements

### Phase 3: Automation Tools

* Auto-compress log files older than N days
* Log rotation/cleanup with retention policy
* Searchable log index with timestamps and host metadata

### Phase 4: Clipboard Pull (Mac pulls from remote)

* From Mac: issue a remote command to pull clipboard or file
* Use `ssh server 'cat somefile' > ~/Desktop/somefile`

### Phase 5: Optional GUI Dashboard (macOS App)

* Display recent SSH and SCP sessions
* Open logs in a terminal-like viewer
* Searchable and filterable logs by host/date/session

---

## 🪧 Possible Blog Post Outline

### Title:

"Logging All Your SSH and SCP Sessions Locally (No Remote Setup Required)"

### Sections:

1. **Problem Statement** — Why you want local logs and clipboard/file transfers
2. **How Apple Makes This Hard** — SIP, provenance, and ACL gotchas on external drives
3. **Simple, Powerful Solution** — Custom `ssh` and `scp` wrappers
4. **macOS-Compatible Logging with `script`** — Why `-f` fails and `-t 1` is optional
5. **Avoiding Pitfalls** — Why `.ssh/log` fails, and `~/Projects/logs` is the sweet spot
6. **Daily Logs with Clear Structure** — A format that's easy to grep and review
7. **The Path Forward** — Reverse-tunnel clipboard/file transfer and agent setup

---

## 📦 Repository Naming Ideas (optional future work)

* `ssh-tools`
* `ssh-utils-mac`
* `local-ssh-recorder`
* `logmyssh`

---

## 🔚 Final Notes

You now have a robust, portable, and Apple-compatible SSH + SCP session logging system. With a minimal listener agent and reverse SSH tunnel, clipboard and file transfer is within easy reach next.
