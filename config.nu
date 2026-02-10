# Zoxide
# ---------------------
# zoxide init nushell | save -f ~/.config/nushell/zoxide.nu
source ~/.config/nushell/zoxide.nu

# Nupm Package Manager
# ---------------------
overlay use ~/.local/share/nushell/overlay/nupm/nupm/ --prefix

use ~/.config/nushell/ibaby/ *
