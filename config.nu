$env.config.buffer_editor = "vi"
$env.config.show_banner = false

# Zoxide
# ---------------------

const cache = ($nu.default-config-dir | path join .cache)
const zoxide_path = ($cache | path join "zoxide.nu")
const carapace_path = ($cache | path join "carapace.nu")

# If seeing "File not found" error, don't worry
# The init files will be created by env.nu (before config.nu is executed)
source $zoxide_path
source $carapace_path

# Nupm Package Manager
# ---------------------
overlay use nupm/nupm --prefix

use ($nu.default-config-dir | path join custom) *
