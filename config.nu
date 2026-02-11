# Zoxide
# ---------------------
const zoxide_path = ($nu.default-config-dir | path join "zoxide.nu")

# If seeing "File not found" error, don't worry
# The init file will be created by env.nu (before config.nu is executed)
source $zoxide_path

# Nupm Package Manager
# ---------------------
overlay use nupm/nupm --prefix

use ($nu.default-config-dir | path join ibaby) *
