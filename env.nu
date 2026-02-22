use std/util "path add"

# Homebrew (macOS)
if (sys host | get name) == "Darwin" {
  # Apple Silicon
  if ("/opt/homebrew/bin" | path exists) {
    path add "/opt/homebrew/bin" "/opt/homebrew/sbin"
  }
  # Intel Mac
  if ("/usr/local/bin" | path exists) {
    path add "/usr/local/bin"
  }
}

path add ($env.HOME | path join ".local/bin")

# Bun
path add ($env.HOME | path join .bun bin)

# Opencode
path add ($env.HOME | path join .opencode bin)

# Cargo
let cargo_home = $env.CARGO_HOME?
  | default ($env.HOME | path join .cargo)
if ($cargo_home | path exists) {
  path add ($cargo_home | path join "bin")
  # Shared target directory across all Cargo projects (saves disk, slower parallel builds)
  # $env.CARGO_TARGET_DIR = $cargo_home | path join "target"
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

# Configure carapace to bridge completions from available shells.
# For commands without native carapace specs, it tries each bridge in order.
$env.CARAPACE_BRIDGES = 'zsh,fish,bash'

# Populate carapace init if installed and file is empty
# When carapace is available with zsh, creates a cascading completer (carapace → zsh)
# Falls back to zsh-only completer when carapace is unavailable
# To regenerate: delete .cache/carapace.nu and restart nushell
if (which carapace | is-not-empty) {
  if (ls $carapace_path | get 0.size) == 0B {
    let carapace_init = (^carapace _carapace nushell)
    if (which zsh | is-not-empty) {
      # Combine carapace with zsh fallback for commands carapace can't complete
      let zsh_wrapper = r#'
# Zsh fallback: try carapace first, fall back to zsh completions
let _carapace_completer = $env.config.completions.external.completer

let zsh_completer = {|spans|
  let expanded_alias = (scope aliases | where name == $spans.0 | $in.0?.expansion?)
  let spans = (if $expanded_alias != null {
    $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
  } else {
    $spans
  })

  let command = ($spans | str join " ")
  let result = (do {
    ^zsh -c $"autoload -Uz compinit; compinit -C; capture\(\) { compadd\(\) { print -l -- \${@[-1]}; builtin compadd \"$@\" }; _main_complete \"$@\" }; capture ($command)"
  } | complete)

  if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) {
    return null
  }

  $result.stdout | lines | where { $in != "" } | each {|line| { value: $line } }
}

$env.config.completions.external.completer = {|spans|
  let carapace_result = (try { do $_carapace_completer $spans } catch { null })
  if ($carapace_result != null) and ($carapace_result | is-not-empty) {
    $carapace_result
  } else {
    do $zsh_completer $spans
  }
}
'#
      [$carapace_init, $zsh_wrapper] | str join "\n" | save -f $carapace_path
    } else {
      $carapace_init | save -f $carapace_path
    }
  }
} else if (which zsh | is-not-empty) {
  if (ls $carapace_path | get 0.size) == 0B {
    r#'
let zsh_completer = {|spans|
  let expanded_alias = (scope aliases | where name == $spans.0 | $in.0?.expansion?)
  let spans = (if $expanded_alias != null {
    $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
  } else {
    $spans
  })

  let command = ($spans | str join " ")
  let result = (do {
    ^zsh -c $"autoload -Uz compinit; compinit -C; capture\(\) { compadd\(\) { print -l -- \${@[-1]}; builtin compadd \"$@\" }; _main_complete \"$@\" }; capture ($command)"
  } | complete)

  if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) {
    return null
  }

  $result.stdout | lines | where { $in != "" } | each {|line| { value: $line } }
}

mut current = (($env | default {} config).config | default {} completions)
$current.completions = ($current.completions | default {} external)
$current.completions.external = ($current.completions.external
| default true enable
| upsert completer { if $in == null { $zsh_completer } else { $in } })

$env.config = $current
'# | save -f $carapace_path
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
