# Nushell Configuration

Personal Nushell configuration with custom prompt, utilities and aliases.

## Quick Installation

### Install Nushell

First, install [Nushell](https://github.com/nushell/nushell):

**Using cargo:**
```bash
cargo install nu --locked
```

For more installation options, see the [official installation guide](https://www.nushell.sh/book/installation.html).

### Install This Configuration

```bash
nu -c 'git clone https://github.com/iibabyy/nushell.git $nu.default-config-dir --recursive'
```

> Or if you already have a config directory, backup and clone:
> ```bash
> mv ~/.config/nushell ~/.config/nushell.backup
> git clone https://github.com/iibabyy/nushell.git ~/.config/nushell --recursive
>
> # Copy your command history
> cp ~/.config/nushell.backup/history.txt ~/.config/nushell/
> ```

## Requirements

- [Nushell](https://www.nushell.sh/) (v0.90+)
- [gum](https://github.com/charmbracelet/gum) - For interactive CLI components
- [zoxide](https://github.com/ajeetdsouza/zoxide) - For smart directory jumping
- [bun](https://bun.sh/) (optional) - For JavaScript project worktree setup

## Features

### Git Utilities
- `gtree` - Create and remove git worktrees interactively
- Custom git completions and aliases

### Interactive CLI utilities (gum wrappers)
- Enhanced input, selection, and filtering commands
- Styled output and formatting helpers

### Completions
Integrated completions for:
- Git, GitHub CLI (gh)
- Docker, Cargo, npm, rustup, claude

Fallback to fish completions for unsupported commands

## Structure

```
~/.config/nushell/
├── config.nu           # Main configuration file
├── env.nu              # Environment setup
├── ibaby/              # Custom modules
│   ├── git/           # Git utilities and worktree management
│   ├── gum/           # Gum wrapper functions
│   ├── completions/   # Custom completions
│   ├── aliases.nu     # Command aliases
│   ├── prompt.nu      # Custom prompt
│   └── hooks.nu       # Shell hooks
└── completions/        # External completions
```

## Usage

After installation, restart Nushell with:
```nushell
exec nu
```

## Customization

Edit `~/.config/nushell/config.nu` to modify imports and settings.

Add your own modules in `~/.config/nushell/ibaby/` and export them in `ibaby/mod.nu`.
