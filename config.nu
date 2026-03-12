# Default editor (change this to your preferred editor, e.g. "nano", "code", "emacs")
$env.config.buffer_editor = "vim"
$env.config.show_banner = false

# Environment variables
do --env {
  use std/util "path add"

  def add --env [paths] {
    let type = ($paths | describe)
    let paths = if $type == "string" {
      [$paths]
    } else if $type == "list<string>" {
      $paths
    }

    for path in $paths {
      if ($path | path exists) {
        path add $path
      }
    }
  }

  # Homebrew (macOS)
  if (sys host | get name) == "Darwin" {
    # Apple Silicon
    if ("/opt/homebrew/bin" | path exists) {
      add ["/opt/homebrew/bin", "/opt/homebrew/sbin"]
    }
    # Intel Mac
    if ("/usr/local/bin" | path exists) {
      add "/usr/local/bin"
    }
  }

  add ($env.HOME | path join ".local/bin")

  # Bun
  add ($env.HOME | path join .bun bin)

  # Cargo
  let cargo_home = ($env.CARGO_HOME? | default ($env.HOME | path join .cargo))
  if ($cargo_home | path exists) {
    add ($cargo_home | path join "bin")
    # Shared target directory across all Cargo projects (saves disk, etc...)
    # $env.CARGO_TARGET_DIR = $cargo_home | path join "target"
  }

}

# Zoxide / Carapace
# ---------------------
const zoxide_path = ($nu.cache-dir | path join "zoxide.nu")
const carapace_path = ($nu.cache-dir | path join "carapace.nu")

# If seeing "File not found" error in IDE, don't worry
# The init files will be created by env.nu (before config.nu is executed)
source $zoxide_path
source $carapace_path

# Nupm Package Manager
# ---------------------
# overlay use nupm/nupm --prefix

use custom *

