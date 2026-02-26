# Zoxide / Carapace
# ---------------------

# Cache directory
mkdir $"($nu.cache-dir)"

const zoxide_path = ($nu.cache-dir | path join "zoxide.nu")
const carapace_path = ($nu.cache-dir | path join "carapace.nu")

# Ensure source files exist (config.nu sources them unconditionally)
let has_zoxide = (which zoxide | is-not-empty)
if $has_zoxide {
  ^zoxide init nushell | save --force $zoxide_path
} else try {
  touch $zoxide_path 
}

let has_carapace = (which carapace | is-not-empty)
if $has_carapace {
  $env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
  carapace _carapace nushell | save --force $carapace_path
} else try {
  touch $carapace_path 
}

let has_starship = (which starship | is-not-empty)
if $has_starship {
  mkdir ($nu.data-dir | path join "vendor/autoload")
  starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
}


