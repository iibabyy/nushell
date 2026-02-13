use std/util "path add"
path add "~/.local/bin"
$env.config.buffer_editor = "code"
$env.config.show_banner = false

# Bun
path add $"($env.HOME)/.bun/bin"

# Cargo
path add (do {
	let cargo_home = $env.CARGO_HOME?
		| default ($env.HOME | path join .cargo)
		| path join bin
	
	if ($cargo_home | path exists) {
		$cargo_home
	}
})

$env.CARGO_TARGET_DIR = (
	$env.CARGO_HOME?
	| default ($env.HOME | path join .cargo)
	| path join "target"
)

# Go Binary Path
path add (do {
	let go_path = (which go | get 0?.path | default /usr/local/go/bin/go )
	if not (which $go_path | is-empty) and ($go_path | path exists) {
		[
			($go_path | path dirname),
			(do { ^$go_path env GOPATH } | path join bin),
		]
	}
})

# Zoxide init file
const cache = ($nu.default-config-dir | path join .cache)
const zoxide_path = ($cache | path join "zoxide.nu")
let has_zoxide = (which zoxide | is-not-empty)	

if $has_zoxide and not ($zoxide_path | path exists) {
	touch $zoxide_path
}

# Only regenerate if zoxide is installed AND the file is currently empty
if $has_zoxide and (ls $zoxide_path | get 0.size) == 0B {
    ^zoxide init nushell | save -f $zoxide_path
}

if not (which starship | is-empty) {
	const starship_init = ($nu.data-dir | path join "vendor/autoload/starship.nu")
	if not ($starship_init | path exists) {
		mkdir ($starship_init | path dirname)
		starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
	}

	let starship_config = $env.STARSHIP_CONFIG? | default ~/.config/starship.toml
	if not ($starship_config | path exists) {
		starship preset catppuccin-powerline -o ~/.config/starship.toml
	}
}
