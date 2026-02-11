# Zoxide
# ---------------------
if not (which ^zoxide | is-empty) {
	const zoxide_path = ($nu.default-config-dir | path join zoxide.nu)
	if ($zoxide_path | path exists) {
		^zoxide init nushell | save -f $zoxide_path
	}
	source $zoxide_path
}

# Nupm Package Manager
# ---------------------
overlay use nupm/nupm --prefix

use ~/.config/nushell/ibaby/ *
