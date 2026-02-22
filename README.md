# Nushell Configuration

Personal Nushell configuration with custom prompt, utilities and aliases.

## Quick Start

### Install Nushell

First, install [Nushell](https://github.com/nushell/nushell)

**Using cargo:**
```bash
cargo install nu --locked
```

For more installation options, see the [official installation guide](https://www.nushell.sh/book/installation.html).

### Install Carapace (Recommended)

[Carapace](https://carapace-sh.github.io/carapace-bin/install.html) provides shell completions for many commands. This configuration uses it but will work without it.

**Linux:**

```bash
# /etc/apt/sources.list.d/fury.list
deb [trusted=yes] https://apt.fury.io/rsteube/ /

sudo apt-get update && sudo apt-get install carapace-bin
```

**macOS:**

```bash
brew install carapace
```

For more installation options, see the [official installation guide](https://carapace-sh.github.io/carapace-bin/install.html).

### Install This Configuration

```bash
nu -c 'git clone https://github.com/iibabyy/nushell-config.git $nu.default-config-dir --recursive'
```

> Or if you already have a config directory, backup and clone:
> ```bash
> nu -c '
>   let config_path = $nu.default-config-dir
>   let backup_path = $"($config_path | path dirname)/nushell.backup"
>
>   # Save the previous nushell directory and clone the new one
>   mv $config_path $backup_path
>   git clone https://github.com/iibabyy/nushell-config.git $config_path --recursive
>
>   # Copy your command history
>   let history_path = $"($backup_path)/history.txt"
>   if ($history_path | path exists) {
>   	cp $history_path $nu.history-path
>   }
> '
> ```

### Run Nushell
```bash
nu
```

## Requirements

- [Nushell](https://www.nushell.sh/) (v0.90+)

**Recommended:**
- [carapace](https://carapace-sh.github.io/carapace-bin/install.html) - For shell completions
- [zoxide](https://github.com/ajeetdsouza/zoxide) - For smart directory jumping

**Optional:**
- [gum](https://github.com/charmbracelet/gum) - For interactive CLI components
- [bun](https://bun.sh/) - For JavaScript project worktree setup (falls back to npm)

## Features

#### Custom Prompt
- Git-aware prompt with branch display, upstream tracking (↑ ↓ indicators) with background fetching

#### Shell Completions
- Completions for claude, with carapace for external commands (bridges to zsh/fish/bash for commands without native specs, plus nushell-level zsh fallback)

#### Git Worktree Management
- **`gtree`** - Simply create/remove git worktrees

## Structure

```
╭── config.nu           # Main configuration file
├── env.nu              # Environment setup
├── custom/             # Custom modules
│   ├── git/           # Git utilities and worktree management
│   ├── gum/           # Gum wrapper functions
│   ├── completions/   # Custom completions
│   ├── aliases.nu     # Command aliases
│   ├── prompt.nu      # Custom prompt
│   └── hooks.nu       # Shell hooks
└── completions/        # External completions
```

## Customization

Edit `config.nu` to modify imports and settings.

Add your own modules in `custom/` and export them in `custom/mod.nu`.
