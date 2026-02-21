def "nu-complete zoxide path" [context: string] {
    let args = $context | split row ' ' | skip 1 |  where ($it | is-not-empty)
    let completions = ^zoxide query --list --score ...$args | lines | where ($it | is-not-empty) | each {|line|
        let parts = $line | str trim | split row ' ' | where ($it | is-not-empty)
        let score = $parts.0 | into float
        let full_path = $parts | skip 1 | str join ' '
        let display = $full_path | str replace $env.HOME '~'
        let value = $full_path | str replace $"($env.HOME)/" ''
        { value: $value, description: $"($display) | score: ($score)", score: $score }
    } | sort-by score --reverse | each {|row| { value: $row.value, description: $row.description } }

    { completions: $completions, options: { sort: false, completion_algorithm: substring } }
}

export def --env --wrapped z [...rest: string@"nu-complete zoxide path"] {
    let path = match $rest {
        [] => {'~'},
        [ '-' ] => {'-'},
        [ $arg ] if ($arg | path expand | path type) == 'dir' => {$arg}
        _ => {
            ^zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
        }
    }
    cd $path
}

export def --env --wrapped zi [...rest: string@"nu-complete zoxide path"] {
    cd $'(^zoxide query --interactive -- ...$rest | str trim -r -c "\n")'
}

def "nu-complete-zoxide-import" [] {
  ["autojump", "z"]
}

def "nu-complete zoxide shells" [] {
  ["bash", "elvish", "fish", "nushell", "posix", "powershell", "xonsh", "zsh"]
}

def "nu-complete zoxide hooks" [] {
  ["none", "prompt", "pwd"]
}

# Add a new directory or increment its rank
export extern "zoxide add" [
  ...paths: path
]

# Edit the database
export extern "zoxide edit" [ ]

# Import entries from another application
export extern "zoxide import" [
  --from: string@nu-complete-zoxide-import  # Application to import from
  --merge                                     # Merge into existing database
]

# Generate shell configuration
export extern "zoxide init" [
  shell: string@"nu-complete zoxide shells"
  --no-cmd                                    # Prevents zoxide from defining the `z` and `zi` commands
  --cmd: string                               # Changes the prefix of the `z` and `zi` commands [default: z]
  --hook: string@"nu-complete zoxide hooks"   # Changes how often zoxide increments a directory's score [default: pwd]
]

# Search for a directory in the database
export extern "zoxide query" [
  ...keywords: string
  --all(-a)             # Show unavailable directories
  --interactive(-i)     # Use interactive selection
  --list(-l)            # List all matching directories
  --score(-s)           # Print score with results
  --exclude: path       # Exclude the current directory
]

# Remove a directory from the database
export extern "zoxide remove" [
  ...paths: path
]

export extern zoxide [
  --help(-h)            # Print help
  --version(-V)         # Print version
]
