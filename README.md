# macOS Workstation

Opinionated, repeatable setup for my personal macOS development workstation.
It prioritizes reproducibility and reversibility over completeness.

This repository exists to answer a single question:

> If I get a new Mac today, how do I make it feel like my machine again?

## Bootstrap

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvimcraft/macos-workstation/main/bin/dev-bootstrap.sh)"
```

## Repository Layout

```bash
macos-workstation/
├── bin/
│   ├── dev-bootstrap.sh
│   ├── dev-rollback.sh
│   └── tmux-session.sh
│
├── scripts/
│   ├── apps-bootstrap.sh
│   ├── apps-rollback.sh
│   ├── brew-maintenance.sh
│   └── system-cleanup.sh
│
└── README.md
```

> **NOTE** This repository is tailored to my workflow but designed to be portable.
