use std/util "path add"
path add "~/.local/bin" 
path add ($env.CARGO_HOME? | default ($env.HOME | path join .cargo) | path join bin)
$env.config.buffer_editor = "code"
$env.config.show_banner = false

# Bun
$env.BUN_INSTALL = $"($env.HOME)/.bun"
path add $"($env.BUN_INSTALL)/bin"

# Cargo Target Directory
$env.CARGO_TARGET_DIR = ($env.HOME | path join ".cargo" "target")

# Go Binary Path
path add "/usr/local/go/bin/"
path add (go env GOPATH | path join bin)
