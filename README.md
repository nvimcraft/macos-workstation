# macOS Workstation

Opinionated, repeatable setup for my personal macOS development workstation.
It prioritizes reproducibility and reversibility over completeness.

This repository exists to answer a single question:

> If I get a new Mac today, how do I make it feel like my machine again?

## Bootstrap

### Recommended (clone + run locally)

This keeps the bootstrap script reviewable and avoids executing remote code directly.

```bash
git clone https://github.com/nvimcraft/macos-workstation.git
cd macos-workstation
./bin/dev-bootstrap.sh
```

### One-liner

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvimcraft/macos-workstation/main/bin/dev-bootstrap.sh)"
```

> **NOTE**: the one-liner executes code from this repo over the network.
> If you want to audit changes, use the clone + run path.

## Preview (dry run)

Run any script with `--help` to see supported options. If available, `--dry-run` previews actions without applying changes:

```bash
./bin/dev-bootstrap.sh --help
./bin/dev-bootstrap.sh --dry-run
```

## Rollback

Rollback is intentionally explicit and interactive by default:

```bash
./bin/dev-rollback.sh
```

> **NOTE** Rollback is designed to undo what bootstrap manages (symlinks + selected packages),
> not to wipe the machine.

## Repository Layout

```bash
macos-workstation/
├── bin/
│   ├── dev-bootstrap.sh
│   ├── dev-rollback.sh
│   ├── jj-set-identity.sh
│   ├── tmux-opencode-popup.sh
│   └── tmux-session.sh
├── LICENSE
├── README.md
└── scripts/
    ├── apps-bootstrap.sh
    ├── apps-rollback.sh
    ├── brew-maintenance.sh
    ├── ssh-bootstrap.sh
    └── system-cleanup.sh
```

> **NOTE** Tailored for my workflow. Adapt as needed.
