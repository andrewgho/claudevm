# claudevm — development notes

claudevm is a bash CLI that creates and manages isolated Debian 13 VMs (via Lima)
for running Claude Code with full permissions. The VM is the sandbox; Claude can do
anything inside it without touching the host.

## Repository layout

```
bin/claudevm      Main CLI script (~430 lines bash)
template.yaml      Lima VM definition (OS, resources, provision script, port forwards)
home-seed/         Dotfiles seeded into /home/claude/ on every new VM
README.md          User-facing documentation
```

## Key design decisions

**No `--dangerously-skip-permissions` flag.** That flag triggers an interactive
acknowledgment prompt that cannot be pre-accepted. Instead, set
`"defaultMode": "bypassPermissions"` in `~/.claude/settings.json` — same effect,
no prompt.

**`permissions.allow` in settings.json.** `bypassPermissions` mode doesn't suppress
per-tool confirmation prompts. The `allow` list in settings.json pre-approves all
tools so Claude never pauses to ask.

**`~/.claude.json` (not `~/.claude/settings.json`) controls the initialization
wizard.** The color-picker wizard appears when this file is missing or when
`hasCompletedOnboarding` is false. We copy the Mac's `~/.claude.json` into the VM
during `sync_credentials`, then inject a project entry for `/home/claude/work` with
`hasTrustDialogAccepted: true` and `hasCompletedProjectOnboarding: true`.

**`silent_init` runs `claude -p hello` before the interactive session.** This
triggers OAuth token refresh, creates `~/.claude/sessions/`, and syncs plugins
without showing the interactive wizard. Must use `bash -l -c '...'` (login shell)
so `~/.bashrc` is sourced and `claude` is on PATH.

**SSH as the `claude` user.** Lima creates a default user matching the host macOS
username. We SSH as `claude` instead, parsing Lima's `~/.lima/<name>/ssh.config`
directly (the deprecated `limactl show-ssh` is gone in Lima 2.x). We pass
`-o ControlMaster=no` to avoid inheriting Lima's ControlMaster socket (which is
keyed to the Lima user, not claude).

**BSD tar xattr suppression.** `COPYFILE_DISABLE=1` and `--no-xattrs` are both
required to suppress macOS extended-attribute entries (PAX headers like
`com.apple.provenance`) that otherwise produce GNU tar warnings inside the VM.

**SSH key detection.** The Lima user's UID on macOS is typically 501 (not ≥1000),
so `awk -F: '$3>=1000'` misses it. We use
`find /home -maxdepth 3 -name authorized_keys | head -1` instead.

**tmux session management.** `cmd_claude` checks whether Claude Code is still the
foreground process in the existing session; if not (Claude exited, leaving a bare
shell), it sends `cd ~/work && claude` to the session before attaching. This avoids
creating a second tmux window.

## credentials sync (`sync_credentials`)

Three things are written into the VM:

1. `~/.claude/.credentials.json` — OAuth tokens from macOS Keychain
   (`security find-generic-password -s "Claude Code-credentials" -w`)
2. `~/.claude/settings.json` — `defaultMode: bypassPermissions` + full `allow` list
3. `~/.claude.json` — copied from Mac with `/home/claude/work` project entry injected

Tokens expire ~12 hours after issue. Both access and refresh tokens rotate on each
use (this is normal). Run `claudevm creds <name>` to re-sync after re-authenticating
on the Mac.

## Settings written to the VM

```json
{
  "defaultMode": "bypassPermissions",
  "permissions": {
    "allow": [
      "Bash(*)", "Read(*)", "Edit(*)", "Write(*)", "MultiEdit(*)",
      "NotebookEdit(*)", "WebFetch(*)", "WebSearch(*)", "Skill(*)", "Agent(*)"
    ]
  }
}
```

## Adding a new command

1. Write a `cmd_<name>()` function in `bin/claudevm`
2. Add a `<name>) cmd_<name> "$@" ;;` line in the `case` dispatch block
3. Add a line to the `usage()` heredoc

## Common gotchas

- `limactl create` requires `--tty=false` to suppress the interactive instance-type
  picker.
- `limactl start` blocks until the Lima guest agent is ready, but cloud-init
  provision scripts continue after. `wait_provision` polls for
  `/var/lib/cloud/instance/boot-finished`.
- Port forwards in `template.yaml` only apply to newly created VMs. Use
  `claudevm forward <name> <port>` for existing VMs.
- `limactl shell <name> -- <cmd>` runs as the Lima user (macOS username), not as
  `claude`. Use `claude_ssh` for commands that need to run as the `claude` user.
