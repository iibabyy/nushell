# Nushell completions for Claude Code CLI

def "nu-complete claude subcommands" [] {
    [
        { value: "auth", description: "Manage authentication" }
        { value: "doctor", description: "Check the health of your Claude Code auto-updater" }
        { value: "install", description: "Install Claude Code native build" }
        { value: "mcp", description: "Configure and manage MCP servers" }
        { value: "plugin", description: "Manage Claude Code plugins" }
        { value: "setup-token", description: "Set up a long-lived authentication token" }
        { value: "update", description: "Check for updates and install if available" }
    ]
}

def "nu-complete claude effort" [] {
    [ "low" "medium" "high" ]
}

def "nu-complete claude output-format" [] {
    [ "text" "json" "stream-json" ]
}

def "nu-complete claude input-format" [] {
    [ "text" "stream-json" ]
}

def "nu-complete claude permission-mode" [] {
    [ "acceptEdits" "bypassPermissions" "default" "delegate" "dontAsk" "plan" ]
}

def "nu-complete claude model" [] {
    [
        { value: "sonnet", description: "Claude Sonnet (latest)" }
        { value: "opus", description: "Claude Opus (latest)" }
        { value: "haiku", description: "Claude Haiku (latest)" }
        { value: "claude-sonnet-4-6", description: "Claude Sonnet 4.6" }
        { value: "claude-opus-4-6", description: "Claude Opus 4.6" }
        { value: "claude-haiku-4-5-20251001", description: "Claude Haiku 4.5" }
    ]
}

def "nu-complete claude mcp scope" [] {
    [ "local" "user" "project" ]
}

def "nu-complete claude mcp transport" [] {
    [ "stdio" "sse" "http" ]
}

def "nu-complete claude mcp servers" [] {
    try {
        ^claude mcp list
        | lines
        | where { $in =~ ' - [✓✗]' }
        | each { |line|
            let parts = ($line | parse --regex '(?P<name>.+?):\s+(?P<cmd>\S+.+)\s+-\s+(?P<status>.+)')
            if ($parts | is-not-empty) {
                let row = $parts | first
                { value: $row.name, description: $row.status }
            }
        }
        | where { $in != null }
    } catch {
        []
    }
}

def "nu-complete claude mcp subcommands" [] {
    [
        { value: "add", description: "Add an MCP server" }
        { value: "add-from-claude-desktop", description: "Import MCP servers from Claude Desktop" }
        { value: "add-json", description: "Add an MCP server with a JSON string" }
        { value: "get", description: "Get details about an MCP server" }
        { value: "list", description: "List configured MCP servers" }
        { value: "remove", description: "Remove an MCP server" }
        { value: "reset-project-choices", description: "Reset approved/rejected project-scoped servers" }
        { value: "serve", description: "Start the Claude Code MCP server" }
    ]
}

def "nu-complete claude plugin scope" [] {
    [ "user" "project" "local" ]
}

def "nu-complete claude plugin update scope" [] {
    [ "user" "project" "local" "managed" ]
}

def "nu-complete claude plugin subcommands" [] {
    [
        { value: "disable", description: "Disable an enabled plugin" }
        { value: "enable", description: "Enable a disabled plugin" }
        { value: "install", description: "Install a plugin from available marketplaces" }
        { value: "list", description: "List installed plugins" }
        { value: "marketplace", description: "Manage Claude Code marketplaces" }
        { value: "uninstall", description: "Uninstall an installed plugin" }
        { value: "update", description: "Update a plugin to the latest version" }
        { value: "validate", description: "Validate a plugin or marketplace manifest" }
    ]
}

def "nu-complete claude plugin installed" [] {
    try {
        ^claude plugin list --json
        | from json
        | each { |p|
            let status = if $p.enabled { "enabled" } else { "disabled" }
            { value: $p.id, description: $"($p.version) (($status))" }
        }
    } catch {
        []
    }
}

def "nu-complete claude plugin marketplace subcommands" [] {
    [
        { value: "add", description: "Add a marketplace from a URL, path, or GitHub repo" }
        { value: "list", description: "List all configured marketplaces" }
        { value: "remove", description: "Remove a configured marketplace" }
        { value: "update", description: "Update marketplace(s) from their source" }
    ]
}

def "nu-complete claude plugin available" [] {
    try {
        ^claude plugin list --available --json
        | from json
        | get available
        | each { |p| { value: $p.pluginId, description: $p.description } }
    } catch {
        []
    }
}

def "nu-complete claude marketplace names" [] {
    try {
        ^claude plugin marketplace list --json
        | from json
        | each { |m| { value: $m.name, description: $"($m.source): ($m.repo)" } }
    } catch {
        []
    }
}

def "nu-complete claude agents" [] {
    let home_agents = (try {
        glob ($env.HOME | path join ".claude/agents/*.md")
        | each { |f| { value: ($f | path parse | get stem), description: "user" } }
    } catch { [] })

    let project_agents = (try {
        glob ($env.PWD | path join ".claude/agents/*.md")
        | each { |f| { value: ($f | path parse | get stem), description: "project" } }
    } catch { [] })

    let plugin_agents = (try {
        glob ($env.HOME | path join ".claude/plugins/cache/**/agents/*.md")
        | each { |f|
            # path: .../cache/<marketplace>/<plugin>/<version>/agents/<file>.md
            let plugin = ($f | path dirname | path dirname | path dirname | path basename)
            { value: ($f | path parse | get stem), description: $"plugin: ($plugin)" }
        }
    } catch { [] })

    $home_agents | append $project_agents | append $plugin_agents | uniq-by value
}

# Format a datetime or duration as a human-readable relative age
def fmt-session-age [dt] {
    let as_dt = (try { $dt | into datetime } catch { $dt })
    let secs = (try { ((date now) - $as_dt) | into int } catch { 0 }) // 1_000_000_000
    if $secs < 60 { $"($secs)s ago" } else if $secs < 3600 { $"($secs // 60)m ago" } else if $secs < 86400 { $"($secs // 3600)h ago" } else if $secs < 604800 { $"($secs // 86400)d ago" } else { $"($secs // 604800)w ago" }
}

# Extract metadata (branch, first prompt) from a session JSONL file header
def extract-session-meta [path: string] {
    let records = (try {
        open --raw $path
        | lines
        | first 20
        | each { |l| try { $l | from json } catch { null } }
        | compact
    } catch { [] })

    let branch = (try {
        $records
        | where { ($in | get -o gitBranch) != null }
        | first
        | get gitBranch
    } catch { "" })

    let user_msg = (try {
        $records
        | where { ($in | get -o type) == "user" and (not ($in | get -o isMeta | default false)) }
        | first
    } catch { null })

    let prompt = if $user_msg != null { try { $user_msg.message.content | into string | str replace --all --regex '<[a-z_-]+>[^<]*</[a-z_-]+>' '' | str replace --all --regex '<[a-z_-]+\s*/>' '' | str replace --all '\n' ' ' | str trim } catch { "" } } else { "" }

    { branch: $branch, prompt: $prompt }
}

def "nu-complete claude sessions" [] {
    try {
    # Encode project path the same way as Claude Code (/ and . become -)
    let project_dir = ($env.PWD
        | str replace --all "/" "-"
        | str replace --all "." "-"
        | $"($env.HOME)/.claude/projects/($in)")

    # Include worktree project directories from the same git repo
    let session_dirs = do {
        mut dirs = [$project_dir]
        let wt_dirs = (try {
            ^git worktree list --porcelain
            | lines
            | where { $in starts-with "worktree " }
            | each { $in | str replace "worktree " "" | str replace --all "/" "-" | str replace --all "." "-" | $"($env.HOME)/.claude/projects/($in)" }
            | where { ($in | path exists) and $in != $project_dir }
        } catch { [] })
        $dirs = ($dirs | append $wt_dirs)
        $dirs
    }

    let index_file = ($project_dir | path join "sessions-index.json")

    # --- Fast path: sessions-index.json (rich metadata) ---
    let indexed = if ($index_file | path exists) {
        try {
            open $index_file | get entries | sort-by --reverse modified
            | each { |e|
                let age = (fmt-session-age $e.modified)
                let branch = ($e | get -o gitBranch | default "")
                let msgs = ($e | get -o messageCount | default 0)
                let summary = ($e | get -o summary | default "")
                let first_prompt = ($e | get -o firstPrompt | default "")
                let label = if ($summary | is-not-empty) and $summary not-in ["Session Cleared", "Conversation Cleared - No Code Discussion Yet"] { if ($summary | str length) > 80 { $"($summary | str substring 0..80)…" } else { $summary } } else if ($first_prompt | is-not-empty) and $first_prompt != "No prompt" { if ($first_prompt | str length) > 80 { $"($first_prompt | str substring 0..80)…" } else { $first_prompt } } else { "" }
                let desc = ([
                    $age
                    (if ($branch | is-not-empty) { $"[($branch)]" })
                    (if $msgs > 0 { $"($msgs)msg" })
                    $label
                ] | compact | str join " · ")
                { value: $e.sessionId, description: $desc, mtime: ($e.modified | into datetime) }
            }
        } catch { [] }
    } else { [] }

    let indexed_ids = ($indexed | each { $in.value })

    # --- Fallback: parse JSONL files not in the index ---
    let from_files = ($session_dirs
        | each { |dir| if ($dir | path exists) { glob ($dir | path join "*.jsonl") } else { [] } }
        | flatten
        | where { ($in | path parse | get stem) not-in $indexed_ids }
        | each { |f| try { { path: $f, mtime: (ls $f | get modified | first) } } catch { null } }
        | compact
        | sort-by --reverse mtime
        | first 30
        | each { |entry|
            let sid = ($entry.path | path parse | get stem)
            let age = (fmt-session-age $entry.mtime)
            let meta = (extract-session-meta $entry.path)
            let prompt = if ($meta.prompt | str length) > 80 { $"($meta.prompt | str substring 0..80)…" } else { $meta.prompt }
            let desc = ([
                $age
                (if ($meta.branch | is-not-empty) { $"[($meta.branch)]" })
                $prompt
            ] | compact | str join " · ")
            { value: $sid, description: $desc, mtime: $entry.mtime }
        })

    let completions = ($indexed | append $from_files | sort-by --reverse mtime | select value description)
    { options: { sort: false }, completions: $completions }
    } catch {
        { options: { sort: false }, completions: [] }
    }
}

def "nu-complete claude install target" [] {
    [ "stable" "latest" ]
}

# Main claude command — wraps ^claude with --allow-dangerously-skip-permissions
export def --wrapped main [
    command?: string@"nu-complete claude subcommands"                    # Subcommand or prompt
    --add-dir: path                                                     # Additional directories to allow tool access to
    --agent: string@"nu-complete claude agents"                           # Agent for the current session
    --agents: string                                                    # JSON object defining custom agents
    --allow-dangerously-skip-permissions                                # Enable bypassing permission checks as an option
    --allowedTools: string                                              # Comma/space-separated tool names to allow
    --allowed-tools: string                                             # Comma/space-separated tool names to allow
    --append-system-prompt: string                                      # Append to the default system prompt
    --betas: string                                                     # Beta headers for API requests
    --chrome                                                            # Enable Claude in Chrome integration
    --continue(-c)                                                      # Continue the most recent conversation
    --dangerously-skip-permissions                                      # Bypass all permission checks
    --debug(-d): string                                                 # Enable debug mode with optional category filter
    --debug-file: path                                                  # Write debug logs to a file path
    --disable-slash-commands                                            # Disable all skills
    --disallowedTools: string                                           # Comma/space-separated tool names to deny
    --disallowed-tools: string                                          # Comma/space-separated tool names to deny
    --effort: string@"nu-complete claude effort"                        # Effort level for the session (low, medium, high)
    --fallback-model: string@"nu-complete claude model"                 # Fallback model when default is overloaded
    --file: path                                                        # File resources to download at startup
    --fork-session                                                      # Create a new session ID when resuming
    --from-pr: string                                                   # Resume a session linked to a PR
    --help(-h)                                                          # Display help
    --ide                                                               # Auto-connect to IDE on startup
    --include-partial-messages                                          # Include partial message chunks (with --print)
    --input-format: string@"nu-complete claude input-format"            # Input format (with --print)
    --json-schema: string                                               # JSON Schema for structured output validation
    --max-budget-usd: number                                            # Maximum dollar amount for API calls
    --mcp-config: path                                                  # Load MCP servers from JSON files or strings
    --mcp-debug                                                         # [DEPRECATED] Enable MCP debug mode
    --model: string@"nu-complete claude model"                          # Model for the current session
    --no-chrome                                                         # Disable Claude in Chrome integration
    --no-session-persistence                                            # Disable session persistence (with --print)
    --output-format: string@"nu-complete claude output-format"          # Output format (with --print)
    --permission-mode: string@"nu-complete claude permission-mode"      # Permission mode for the session
    --plugin-dir: path                                                  # Load plugins from directories
    --print(-p)                                                         # Print response and exit
    --replay-user-messages                                              # Re-emit user messages on stdout
    --resume(-r): string@"nu-complete claude sessions"                   # Resume a conversation by session ID
    --session-id: string                                                # Use a specific session ID (UUID)
    --setting-sources: string                                           # Comma-separated list of setting sources
    --settings: path                                                    # Path to settings JSON file or JSON string
    --strict-mcp-config                                                 # Only use MCP servers from --mcp-config
    --system-prompt: string                                             # System prompt for the session
    --tools: string                                                     # Specify available tools from the built-in set
    --verbose                                                           # Override verbose mode setting
    --version(-v)                                                       # Output the version number
    ...rest: string
] {
    let args = if ($command | is-not-empty) {
        [$command ...$rest]
    } else {
        $rest
    }
    ^claude --allow-dangerously-skip-permissions ...$args
}

# Check the health of your Claude Code auto-updater
export extern "claude doctor" [
    --help(-h)                                                          # Display help
]

# Install Claude Code native build
export extern "claude install" [
    target?: string@"nu-complete claude install target"                 # Version to install (stable, latest, or specific)
    --force                                                             # Force installation even if already installed
    --help(-h)                                                          # Display help
]

# Set up a long-lived authentication token
export extern "claude setup-token" [
    --help(-h)                                                          # Display help
]

# Check for updates and install if available
export extern "claude update" [
    --help(-h)                                                          # Display help
]

# Check for updates and install if available (alias)
export extern "claude upgrade" [
    --help(-h)                                                          # Display help
]

# --- Auth commands ---

def "nu-complete claude auth subcommands" [] {
    [
        { value: "login", description: "Sign in to your Anthropic account" }
        { value: "logout", description: "Log out from your Anthropic account" }
        { value: "status", description: "Show authentication status" }
    ]
}

# Manage authentication
export extern "claude auth" [
    command?: string@"nu-complete claude auth subcommands"               # Auth subcommand
    --help(-h)                                                          # Display help
]

# Sign in to your Anthropic account
export extern "claude auth login" [
    --email: string                                                     # Pre-populate email address on the login page
    --help(-h)                                                          # Display help
    --sso                                                               # Force SSO login flow
]

# Log out from your Anthropic account
export extern "claude auth logout" [
    --help(-h)                                                          # Display help
]

# Show authentication status
export extern "claude auth status" [
    --help(-h)                                                          # Display help
    --json                                                              # Output as JSON (default)
    --text                                                              # Output as human-readable text
]

# --- MCP commands ---

# Configure and manage MCP servers
export extern "claude mcp" [
    command?: string@"nu-complete claude mcp subcommands"               # MCP subcommand
    --help(-h)                                                          # Display help
]

# Add an MCP server to Claude Code
export extern "claude mcp add" [
    name: string                                                        # Server name
    commandOrUrl: string                                                # Command or URL for the server
    ...args: string                                                     # Additional arguments for the server command
    --callback-port: int                                                # Fixed port for OAuth callback
    --client-id: string                                                 # OAuth client ID for HTTP/SSE servers
    --client-secret                                                     # Prompt for OAuth client secret
    --env(-e): string                                                   # Set environment variables (KEY=value)
    --header(-H): string                                                # Set WebSocket headers
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude mcp scope"                  # Configuration scope (default: local)
    --transport(-t): string@"nu-complete claude mcp transport"          # Transport type (default: stdio)
]

# Import MCP servers from Claude Desktop
export extern "claude mcp add-from-claude-desktop" [
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude mcp scope"                  # Configuration scope (default: local)
]

# Add an MCP server with a JSON string
export extern "claude mcp add-json" [
    name: string                                                        # Server name
    json: string                                                        # JSON configuration string
    --client-secret                                                     # Prompt for OAuth client secret
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude mcp scope"                  # Configuration scope (default: local)
]

# Get details about an MCP server
export extern "claude mcp get" [
    name: string@"nu-complete claude mcp servers"                       # Server name
    --help(-h)                                                          # Display help
]

# List configured MCP servers
export extern "claude mcp list" [
    --help(-h)                                                          # Display help
]

# Remove an MCP server
export extern "claude mcp remove" [
    name: string@"nu-complete claude mcp servers"                       # Server name
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude mcp scope"                  # Configuration scope
]

# Reset all approved/rejected project-scoped servers
export extern "claude mcp reset-project-choices" [
    --help(-h)                                                          # Display help
]

# Start the Claude Code MCP server
export extern "claude mcp serve" [
    --debug(-d)                                                         # Enable debug mode
    --help(-h)                                                          # Display help
    --verbose                                                           # Override verbose mode setting
]

# --- Plugin commands ---

# Manage Claude Code plugins
export extern "claude plugin" [
    command?: string@"nu-complete claude plugin subcommands"             # Plugin subcommand
    --help(-h)                                                          # Display help
]

# Install a plugin from available marketplaces
export extern "claude plugin install" [
    plugin: string@"nu-complete claude plugin available"                 # Plugin name (use plugin@marketplace for specific)
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin scope"               # Installation scope (default: user)
]

# Uninstall an installed plugin
export extern "claude plugin uninstall" [
    plugin: string@"nu-complete claude plugin installed"                # Plugin name
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin scope"               # Uninstall from scope (default: user)
]

# Uninstall an installed plugin (alias)
export extern "claude plugin remove" [
    plugin: string@"nu-complete claude plugin installed"                # Plugin name
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin scope"               # Uninstall from scope (default: user)
]

# Enable a disabled plugin
export extern "claude plugin enable" [
    plugin: string@"nu-complete claude plugin installed"                # Plugin name
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin scope"               # Installation scope (default: user)
]

# Disable an enabled plugin
export extern "claude plugin disable" [
    plugin?: string@"nu-complete claude plugin installed"               # Plugin name
    --all(-a)                                                           # Disable all enabled plugins
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin scope"               # Installation scope (default: user)
]

# List installed plugins
export extern "claude plugin list" [
    --available                                                         # Include available plugins from marketplaces (requires --json)
    --help(-h)                                                          # Display help
    --json                                                              # Output as JSON
]

# Update a plugin to the latest version
export extern "claude plugin update" [
    plugin: string@"nu-complete claude plugin installed"                # Plugin name
    --help(-h)                                                          # Display help
    --scope(-s): string@"nu-complete claude plugin update scope"        # Installation scope (default: user)
]

# Validate a plugin or marketplace manifest
export extern "claude plugin validate" [
    path: path                                                          # Path to the plugin or manifest
    --help(-h)                                                          # Display help
]

# --- Plugin marketplace commands ---

# Manage Claude Code marketplaces
export extern "claude plugin marketplace" [
    command?: string@"nu-complete claude plugin marketplace subcommands" # Marketplace subcommand
    --help(-h)                                                           # Display help
]

# Add a marketplace from a URL, path, or GitHub repo
export extern "claude plugin marketplace add" [
    source: string                                                      # URL, path, or GitHub repo
    --help(-h)                                                          # Display help
]

# List all configured marketplaces
export extern "claude plugin marketplace list" [
    --help(-h)                                                          # Display help
    --json                                                              # Output as JSON
]

# Remove a configured marketplace
export extern "claude plugin marketplace remove" [
    name: string@"nu-complete claude marketplace names"                  # Marketplace name
    --help(-h)                                                          # Display help
]

# Update marketplace(s) from their source
export extern "claude plugin marketplace update" [
    name?: string@"nu-complete claude marketplace names"                 # Marketplace name (updates all if omitted)
    --help(-h)                                                          # Display help
]
