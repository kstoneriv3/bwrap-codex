# bcodex

`bcodex` runs `codex` inside a Bubblewrap sandbox so Codex can run with `--yolo` while filesystem writes are constrained.

## Security model

- Root filesystem is mounted read-only: `--ro-bind / /`
- Current working directory is mounted writable.
- `~/.codex` is mounted writable.
- Common secret paths are masked (for example `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube`, `~/.netrc`).
- Temporary/cache/state writes are redirected into `./.bcodex/`.

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

## Test

Run smoke tests:

```bash
./run_test.sh
```

The test script checks shell syntax, mount policy construction, sensitive-path masking, and `--yolo` injection.

## Notes

- Secret masking is best-effort and path-based.
- If you need to adjust masked paths, edit `mask_paths` in `bcodex`.
