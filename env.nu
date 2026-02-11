use std/util "path add"
path add "~/.local/bin"
$env.config.buffer_editor = "code"
$env.config.show_banner = false

# Bun
if not (which ^bun | is-empty) {
	path add $"($env.HOME)/.bun/bin"
}

# Cargo Target Directory
if not (which ^cargo | is-empty) {
	path add (
		$env.CARGO_HOME?
		| default ($env.HOME | path join .cargo)
		| path join bin
	)

	$env.CARGO_TARGET_DIR = (
		$env.CARGO_HOME?
		| default ($env.HOME | path join .cargo)
		| path join "target"
	)
}

# Go Binary Path
if not (which ^go | is-empty) {
	path add (^go env GOPATH)
	path add (^go env GOBIN)
}

# Zoxide init file
const zoxide_path = ($nu.default-config-dir | path join "zoxide.nu")
let has_zoxide = (which zoxide | is-not-empty)	

if not ($has_zoxide) {
	rm $zoxide_path
} else if not ($zoxide_path | path exists) {
	touch $zoxide_path
}

# Only regenerate if zoxide is installed AND the file is currently empty
if $has_zoxide and (ls $zoxide_path | get 0.size) == 0B {
    ^zoxide init nushell | save -f $zoxide_path
}
