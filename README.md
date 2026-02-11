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

## Requirements

- [Nushell](https://www.nushell.sh/) (v0.90+)

**Recommended:**
- [zoxide](https://github.com/ajeetdsouza/zoxide) - For smart directory jumping

**Optional:**
- [gum](https://github.com/charmbracelet/gum) - For interactive CLI components
- [bun](https://bun.sh/) - For JavaScript project worktree setup (falls back to npm)

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

## Usage

After installation, restart Nushell with:
```nushell
exec nu
```

## Customization

Edit `config.nu` to modify imports and settings.

Add your own modules in `custom/` and export them in `custom/mod.nu`.
