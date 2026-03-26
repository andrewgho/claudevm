# claudevm

Isolated Debian development VMs for running Claude Code without permission
restrictions. Each VM is fully independent — Claude can do whatever it wants
inside the VM, and you can tear it down and recreate it at any time.

## Quick start

```bash
# Add claudevm to your PATH (one-time setup)
echo 'export PATH="$HOME/work/claudevm/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Create a new VM and drop into a Claude Code session
claudevm create myproject

# In another terminal: open a bash shell in the same VM
claudevm connect myproject

# Reconnect to an existing Claude Code session (e.g., after closing the window)
claudevm claude myproject
```

## Installation

### Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- [Lima](https://lima-vm.io/) — `brew install lima`
- Internet access (to download the Debian image on first create)

Lima is already installed if you use Colima (`brew info lima` to verify).

### Setup

```bash
# Clone or place this repo
cd ~/work/claudevm

# Add to PATH
echo 'export PATH="$HOME/work/claudevm/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify
claudevm help
```

---

## Commands

| Command | Description |
|---|---|
| `claudevm create <name>` | Create VM, provision it, populate home dir, drop into Claude Code |
| `claudevm claude <name>` | Attach to existing Claude Code session, or start a new one |
| `claudevm connect <name>` | Interactive bash shell as user `claude` |
| `claudevm root <name>` | Interactive shell as root |
| `claudevm suspend <name>` | Stop VM (disk preserved) |
| `claudevm resume <name>` | Start a suspended VM |
| `claudevm destroy <name>` | Permanently delete VM and all its data |
| `claudevm list` | List all VMs with status |
| `claudevm ip <name>` | Show VM networking info |
| `claudevm ssh-config <name>` | Print SSH config block for `~/.ssh/config` |
| `claudevm forward <name> <port> [host-port]` | Ad-hoc port forward |

---

## VM specification

Defined in `template.yaml`. Defaults:

- **OS**: Debian 13 (Trixie), ARM64
- **CPU**: 4 vCPUs
- **RAM**: 6 GiB
- **Disk**: 40 GiB
- **Mounts**: None (VM is isolated from host filesystem)
- **User**: `claude` with passwordless sudo

### Installed software

Base system: `build-essential`, `git`, `emacs-nox`, `vim`, `tmux`, `curl`,
`wget`, `python3`, `golang`, `cmake`, `gcc`, `g++`, `make`, `jq`, `htop`,
`rsync`, and more.

Node.js 22 (from NodeSource), plus `@anthropic-ai/claude-code` globally installed.

Rust is **not** pre-installed (large download; install with `rustup` if needed).

---

## Session model

`claudevm create` and `claudevm claude` both connect you to a **tmux session**
named `claude` running inside the VM. This means:

- Closing the terminal window does **not** stop Claude Code.
- `claudevm claude <name>` always reattaches to the running session.
- If Claude Code has exited, `claudevm claude` starts a fresh session.
- Detach from the session at any time with **Ctrl-b d**.

Inside the tmux session, Claude Code runs as:

```
claude --dangerously-skip-permissions
```

This grants Claude full access to everything inside the VM. Because the VM has
no access to your Mac's filesystem or credentials, this is safe.

---

## Networking

Lima VMs use NAT for outbound internet access. Services running inside the VM
are reachable from your Mac via **localhost port forwarding**.

### Pre-configured forwarded ports

The following guest ports are forwarded to the same port on localhost:

| Port | Common use |
|------|-----------|
| 3000 | Node.js / React dev server |
| 4000 | Various frameworks |
| 5000 | Flask / various |
| 8000 | Python http.server / Django |
| 8080 | Alternative HTTP |
| 8888 | Jupyter notebooks |
| 9000 | Various |

So if Claude starts a web server on port 8080 inside the VM, you can open
`http://localhost:8080` on your Mac.

### Ad-hoc port forwarding

```bash
# Forward a specific port not in the pre-configured list
claudevm forward myproject 5432        # forwards postgres to localhost:5432
claudevm forward myproject 6379 16379  # forward guest:6379 -> host:16379
```

### Direct VM IP (optional, requires socket_vmnet)

For use cases where you need a real IP (not localhost), you can install
`socket_vmnet` to give VMs a directly-routable IP:

```bash
brew install socket_vmnet
sudo brew services start socket_vmnet
```

Then add to `template.yaml`:
```yaml
networks:
- lima: shared
```

VMs will get IPs in the `192.168.105.x` range, reachable from your Mac.
Run `claudevm ip <name>` to see the IP.

---

## Home directory customization

On `claudevm create`, the contents of `home-seed/` are copied into the VM's
`/home/claude/` directory. To customize what every new VM gets:

```
home-seed/
  .bashrc         # shell config, PATH, aliases
  .bash_profile   # login shell
  .gitconfig      # git settings
  .inputrc        # readline settings
  bin/            # ~/bin is on PATH; put custom scripts here
```

You can add any dotfiles here. The seed is applied once at VM creation.

To add dotfiles to existing VMs, use `claudevm connect` and copy them manually,
or use `claudevm forward` + `rsync`.

---

## VM lifecycle

```
claudevm create myproject   # → Running (Claude Code session)
claudevm suspend myproject  # → Stopped (disk preserved)
claudevm resume myproject   # → Running again
claudevm destroy myproject  # → Gone (requires typing name to confirm)
```

Suspended VMs don't use CPU or RAM, but their disk image remains on your Mac
(typically at `~/.lima/<name>/`).

---

## Cookbook

### Running multiple VMs simultaneously

Each `claudevm create <name>` creates a fully independent VM. You can run
several at once:

```bash
claudevm create project-a
claudevm create project-b
claudevm list
```

Each gets its own SSH port, disk, and tmux session.

### Copying files into a VM

```bash
# From your Mac to the VM
limactl copy myfile.txt myproject:/home/claude/work/

# Or pipe through ssh
cat myfile.txt | claudevm connect myproject  # paste via stdin
```

### Using VS Code Remote SSH

```bash
# Add SSH config for a VM
claudevm ssh-config myproject >> ~/.ssh/config

# Then connect in VS Code:
# Remote-SSH: Connect to Host → claudevm-myproject
```

### Giving Claude a GitHub token

```bash
# Connect to the VM and set the token
claudevm connect myproject
# Inside VM:
echo 'export GITHUB_TOKEN=ghp_...' >> ~/.bashrc.local
source ~/.bashrc.local
```

Or set environment variables in `home-seed/.bashrc.local` before creating the VM.

### Recreating a VM from scratch

```bash
claudevm destroy myproject   # type name to confirm
claudevm create myproject    # fresh VM, same name
```

Since the home-seed is re-applied, your dotfiles and PATH are always consistent.

### Changing VM resources

Edit `template.yaml` before creating a VM:

```yaml
cpus: 8
memory: "12GiB"
disk: "80GiB"
```

To change resources on an existing VM, you must destroy and recreate it.
(Lima does not support live resource changes.)

### Adding more forwarded ports

Edit the `portForwards` section in `template.yaml`:

```yaml
portForwards:
- guestPort: 5432
  hostPort: 5432
```

This affects newly created VMs. For existing VMs, use `claudevm forward`.

### Checking what's running in the VM

```bash
claudevm connect myproject
# Inside VM:
ps aux
tmux ls        # list tmux sessions
tmux attach    # reattach to claude session
```

### Installing Rust in the VM

```bash
claudevm connect myproject
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
```

### Installing additional languages

```bash
claudevm connect myproject
# Java
sudo apt-get install -y openjdk-21-jdk
# Ruby
sudo apt-get install -y ruby-full
# PHP
sudo apt-get install -y php php-cli
```

---

## Troubleshooting

### `claudevm create` hangs at provisioning

Provisioning downloads packages (Node.js, etc.) and may take 5–10 minutes on
first run. The Debian base image is ~300MB and is cached after first download.

Check progress with `limactl shell <name> -- journalctl -f`.

### SSH connection refused

If `claudevm connect` fails with "connection refused", the VM may still be
booting. Wait a moment and retry, or check status with `claudevm status <name>`.

### Claude Code not found in VM

If `claude` command is not found, Node.js global bin may not be on PATH.
Check with `npm bin -g` and add to `~/.bashrc` if needed.

### Port forwarding not working

Lima sets up port forwarding when the VM starts. If a port isn't working:
1. Verify the service is actually listening inside the VM: `ss -tlnp | grep <port>`
2. Check the port is in `portForwards` in `template.yaml`
3. Try `claudevm forward <name> <port>` for an explicit tunnel

### Reclaim disk space

```bash
# Remove a VM entirely
claudevm destroy myproject

# Prune Lima's image cache (frees downloaded images)
limactl prune
```
