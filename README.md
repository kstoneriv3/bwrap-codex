# bcodex

`bcodex` runs `codex` inside a Bubblewrap sandbox so Codex can run with `--yolo` while filesystem writes are constrained.

## Security model

- Root filesystem is mounted read-only: `--ro-bind / /`
- Current working directory is mounted writable.
- `~/.codex` is mounted writable.
- `/tmp/bcodex/<session_id>` is mounted writable for per-session temp files.
- Common secret paths are masked (for example `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube`, `~/.netrc`).
- Cache/state/runtime writes are redirected into `./.bcodex/`.
- `TMPDIR` is set to `/tmp/bcodex/<session_id>`.

## Install

From this repo:

```bash
./install_bash.sh
```

```bash
./install_zsh.sh
```

```bash
./install_fish.sh
```

Optional: append bcodex awareness prompt into `~/.codex/AGENTS.md`:

```bash
./install_bash.sh -a
```

or

```bash
./install_bash.sh --append-prompt-to-default-agents-md
```

Each installer:

- Installs `bcodex` to `~/.local/bin/bcodex`
- Ensures `~/.local/bin` is on PATH
- Adds alias replacement for `codex`

Reload your shell after install, for example:

```bash
source ~/.bashrc
```

## Usage

```bash
bcodex
```

```bash
bcodex resume --last
```

Print the generated sandbox command without executing:

```bash
bcodex --print-cmd -- --help
```

Pass `--help` to Codex (not wrapper):

```bash
bcodex -- --help
```

## Agent Awareness

Inside `bcodex`, these environment variables are set:

- `BWRAP_CODEX=1`
- `BCODEX_SESSION_ID=<session_id>`
- `BCODEX_TMPDIR=/tmp/bcodex/<session_id>`

You can use `BCODEX_SESSION_ID` for per-session tracing and `BCODEX_TMPDIR` for temp file behavior.

## Test

Run smoke tests:

```bash
./run_test.sh
```

The test script checks shell syntax, mount policy construction, session tmp/env markers, sensitive-path masking, installer `-a` behavior, and `--yolo` injection.

## Notes

- Secret masking is best-effort and path-based.
- If you need to adjust masked paths, edit `mask_paths` in `bcodex`.

## Troubleshooting

If you see:

```text
bwrap: setting up uid map: Permission denied
```

your host is blocking unprivileged user namespaces for non-setuid `bwrap`.

Typical fixes:

```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

or install/use a setuid-enabled `bwrap` package for your distro.
