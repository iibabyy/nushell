# Homebrew (macOS)
if (sys host | get name) == "Darwin" {
  # Apple Silicon
  if ("/opt/homebrew/bin" | path exists) {
    $env.PATH = $env.PATH | prepend ["/opt/homebrew/bin" "/opt/homebrew/sbin"]
  }
  # Intel Mac
  if ("/usr/local/bin" | path exists) {
    $env.PATH = $env.PATH | prepend "/usr/local/bin"
  }
}

$env.PATH = $env.PATH | prepend ($env.HOME | path join ".local/bin")

# Bun
$env.PATH = $env.PATH | prepend $"($env.HOME)/.bun/bin"

# Opencode
$env.PATH = $env.PATH | prepend $"($env.HOME)/.opencode/bin"

# Cargo
if (which cargo | is-not-empty) {
  let cargo_home = $env.CARGO_HOME?
    | default ($env.HOME | path join .cargo)

  if ($cargo_home | path exists) {
    $env.PATH = $env.PATH | prepend ($cargo_home | path join "bin")
    $env.CARGO_TARGET_DIR = $cargo_home | path join "target"
  }
}

# Go Binary Path
let go_path = (which go | get 0?.path | default /usr/local/go/bin/go)
if ($go_path | path exists) {
  let gopath_result = (do { ^$go_path env GOPATH } | complete)
  let go_paths = [
    ($go_path | path dirname),
    ...(if $gopath_result.exit_code == 0 { [($gopath_result.stdout | str trim | path join bin)] } else { [] })
  ]

  $env.PATH = $env.PATH | prepend $go_paths
}

# Cache directory
const cache = ($nu.default-config-dir | path join .cache)
mkdir $cache

# Ensure source files exist (config.nu sources them unconditionally)
const zoxide_path = ($cache | path join "zoxide.nu")
const carapace_path = ($cache | path join "carapace.nu")
if not ($zoxide_path | path exists) { touch $zoxide_path }
if not ($carapace_path | path exists) { touch $carapace_path }

# Populate zoxide init if installed and file is empty
if (which zoxide | is-not-empty) {
  if (ls $zoxide_path | get 0.size) == 0B {
    ^zoxide init nushell --no-cmd | save -f $zoxide_path
  }
}

# Populate carapace init if installed and file is empty
if (which carapace | is-not-empty) {
  if (ls $carapace_path | get 0.size) == 0B {
    ^carapace _carapace nushell | save -f $carapace_path
  }
}

# starship init/config files
if not (which starship | is-empty) {
	const starship_init = ($nu.data-dir | path join "vendor/autoload/starship.nu")
	if not ($starship_init | path exists) {
		try {
			mkdir ($starship_init | path dirname)
			starship init nu | save -f $starship_init
		} catch { |err|
			print -e $"Warning: starship init failed: ($err.msg)"
		}
	}

	let starship_config = $env.STARSHIP_CONFIG? | default ~/.config/starship.toml
	if not ($starship_config | path exists) {
		try {
			starship preset catppuccin-powerline -o $starship_config
		} catch { |err|
			print -e $"Warning: starship preset failed: ($err.msg)"
		}
	}
}
