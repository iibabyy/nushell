# Default editor (change this to your preferred editor, e.g. "nano", "code", "emacs")
$env.config.buffer_editor = "vim"
$env.config.show_banner = false

# Zoxide / Carapace
# ---------------------
const cache = ".cache"
const zoxide_path = ($cache | path join "zoxide.nu")
const carapace_path = ($cache | path join "carapace.nu")

# If seeing "File not found" error, don't worry
# The init files will be created by env.nu (before config.nu is executed)
source $zoxide_path
source $carapace_path

# Nupm Package Manager
# ---------------------
overlay use nupm/nupm --prefix

use custom *

