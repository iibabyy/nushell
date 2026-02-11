use std/util "path add"
path add "~/.local/bin"
$env.config.buffer_editor = "code"
$env.config.show_banner = false

# Bun
if not (which ^bun | is-emtpy) {
	path add $"($env.HOME)/.bun/bin"
}

# Cargo Target Directory
if not (which ^cargo | is-emtpy) {
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
if not (which ^go | is-emtpy) {
	path add (^go env GOPATH)
	path add (^go env GOBIN)
}
