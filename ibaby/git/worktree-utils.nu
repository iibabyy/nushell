# Utility functions for git worktree operations
# These are internal helpers following Single Responsibility Principle

use span-utils.nu [make-error make-error-with-span]

# Validate that a directory is a git repository
export def validate-git-repo [
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let workdir = $spanned_workdir.value

    if (do -i { git -C $workdir rev-parse --is-inside-work-tree | complete } | get exit_code) != 0 {
        make-error-with-span {
            msg: $"Not in a git repository: ($workdir)"
            label: { text: "not a git repository", span: $spanned_workdir.span }
            help: (if $spanned_workdir.span == null { "Use --workdir to specify a git repository" } else { null })
        }
    }
}

# Validate that a directory exists and is actually a directory
export def validate-directory-exists [
    spanned_dir: record<value: path, span: any>
    context: string = "directory"
]: nothing -> nothing {
    if not ($spanned_dir.value | path exists) {
        make-error-with-span {
            msg: $"($context | str capitalize) does not exist: ($spanned_dir.value)"
            label: { text: "directory not found", span: $spanned_dir.span }
            help: "Check the path"
        }
    }

    if ($spanned_dir.value | path type) != "dir" {
        make-error-with-span {
            msg: $"($context | str capitalize) path is not a directory: ($spanned_dir.value)"
            label: { text: "not a directory", span: $spanned_dir.span }
            help: "Specify a valid directory path"
        }
    }
}

# Check if a branch exists in the repository
export def branch-exists [
    branch: string
    workdir: path = "."
]: nothing -> bool {
    (do -i { git -C $workdir rev-parse --verify $branch | complete } | get exit_code) == 0
}

# Validate that a branch exists, error if it doesn't
export def validate-branch-exists [
    spanned_branch: record<value: string, span: any>
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let branch = $spanned_branch.value
    let workdir = $spanned_workdir.value

    if not (branch-exists $branch $workdir) {
        make-error-with-span {
            msg: $"Base branch does not exist: ($branch)"
            label: { text: "Not found", span: $spanned_branch.span }
            help: (if $spanned_branch.span == null { "Use --base-branch to specify a valid base branch" } else { null })
        }
    }
}

# Validate that a branch name is available (doesn't exist yet)
export def validate-branch-available [
    spanned_branch: record<value: string, span: any>
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let branch = $spanned_branch.value
    let workdir = $spanned_workdir.value

    if (branch-exists $branch $workdir) {
        make-error-with-span {
            msg: $"Branch already exists: ($branch)"
            label: { text: "branch already exists", span: $spanned_branch.span }
        }
    }
}

# Resolve the worktree target path
export def resolve-worktree-path [
    branch: string
    workdir: path
    custom_path?: path
]: nothing -> path {
    if ($custom_path | is-not-empty) {
        $custom_path | path expand
    } else {
        let safe_name = ($branch | str replace --all "/" "-")
        $"($workdir)/.worktrees/($safe_name)" | path expand
    }
}

# Validate that the target path doesn't already exist
export def validate-path-available [
    target: path                                        # Computed value (not spanned)
    spanned_path?: record<value: path, span: any>      # Original user input
]: nothing -> nothing {
    if ($target | path exists) {
        let hint = if $spanned_path == null { "Use --path to specify a different worktree location" } else { null }
        make-error $"Target path already exists: ($target)" $spanned_path --label "path already exists" --hint $hint
    }
}

# Get the current branch name
export def get-current-branch [
    workdir: path = "."
]: nothing -> string {
    git -C $workdir branch --show-current | str trim
}

# Create a new git worktree
export def create-worktree [
    branch: string
    target: path
    base_branch: string
    workdir: path = "."
]: nothing -> nothing {
    let result = (do -i { ^git -C $workdir worktree add -b $branch $target $base_branch | complete })
    if $result.exit_code != 0 {
        error make --unspanned { msg: $"Failed to create worktree: ($result.stderr)" }
    }
}

# Check if bun is available
export def has-bun []: nothing -> bool {
    which bun | is-not-empty
}

export def has-npm []: nothing -> bool {
    which npm | is-not-empty
}

# Run bun install in a directory, fallback to npm if bun doesn't exist
export def run-bun-install [
    target: path
]: nothing -> nothing {
    let package_json_path = $target | path join "package.json"

    if ($package_json_path | path exists) {
        if (has-bun) {
            do -i { ^bun install --cwd $target }
        } else if (has-npm) {
            do -i { ^npm install --prefix $target }
        }
    }
}

# Copy path to clipboard, return message
export def copy-to-clipboard [
    path: path
]: nothing -> string {
    try {
        $path | clipboard copy | ignore
        $"Path copied to clipboard ($path)"
    } catch { |err|
        $"Could not copy path to clipboard: ($err.msg)"
    }
}

# Get worktree list as structured data
export def get-worktree-list [
    workdir: path = "."
]: nothing -> table {
    ^git -C $workdir worktree list
    | lines
    | split column -r '\s+' path hash branch
}

# Get branch name from worktree path
export def get-worktree-branch [
    worktree_path: path
    workdir: path = "."
]: nothing -> string {
    let worktree_info = (
        get-worktree-list $workdir
        | where path == $worktree_path
        | get 0?
    )

    if $worktree_info == null {
        null
    } else {
        let branch_raw = ($worktree_info | get branch)
        if $branch_raw != null {
            $branch_raw | str replace -r '^\[' '' | str replace -r '\]$' ''
        } else {
            null
        }
    }
}

# Get remote tracking branch for a local branch
export def get-remote-tracking-branch [
    branch: string
    workdir: path = "."
]: nothing -> string {
    let remote = (do -i { git -C $workdir config --get $"branch.($branch).remote" | complete })
    if $remote.exit_code == 0 and ($remote.stdout | str trim | is-not-empty) {
        let remote_name = ($remote.stdout | str trim)
        $"($remote_name)/($branch)"
    } else {
        null
    }
}

# Check if worktree has uncommitted changes
export def worktree-is-dirty [
    worktree_path: path
]: nothing -> bool {
    let dirty = (git -C $worktree_path status --porcelain | str trim)
    not ($dirty | is-empty)
}

# Validate worktree is clean
export def validate-worktree-clean [
    worktree_path: path                                 # Computed path
    spanned_source?: record<value: any, span: any>     # Original user input (branch or path)
]: nothing -> nothing {
    if (worktree-is-dirty $worktree_path) {
        let dirty = (git -C $worktree_path status --porcelain | str trim)
        let span = if $spanned_source != null { $spanned_source.span } else { null }
        make-error-with-span {
            msg: $"Worktree has uncommitted changes:\n($dirty)"
            label: { text: "dirty worktree", span: $span }
            help: "Use --force to remove anyway"
        }
    }
}

# Check if worktree exists in git's worktree list
export def worktree-exists [
    worktree_path: path
    workdir: path = "."
]: nothing -> bool {
    get-worktree-list $workdir
    | where path == $worktree_path
    | is-not-empty
}

# Remove a worktree using git
export def remove-worktree-git [
    worktree_path: path
    workdir: path = "."
    --force
]: nothing -> nothing {
    let remove_args = if $force { [--force] } else { [] }
    let result = (do -i { ^git -C $workdir worktree remove ...$remove_args $worktree_path | complete })
    if $result.exit_code != 0 {
        error make --unspanned { msg: $"Failed to remove worktree: ($result.stderr | str trim)" }
    }
}

# Remove an orphaned worktree directory (not tracked by git)
export def remove-orphaned-directory [
    worktree_path: path
]: nothing -> nothing {
    try {
        rm -rf $worktree_path
    } catch { |err|
        error make --unspanned { msg: $"Failed to remove orphaned directory: ($err.msg)" }
    }
}

# Delete a local branch
export def delete-local-branch [
    branch: string
    workdir: path = "."
    --force
]: [nothing -> record<success: bool, message: string>] {
    let delete_flag = if $force { "-D" } else { "-d" }
    let result = (^git -C $workdir branch $delete_flag $branch | complete)

    if $result.exit_code != 0 {
        {
            success: false,
            message: $"Warning: could not delete local branch ($branch): ($result.stderr | str trim)"
        }
    } else {
        {
            success: true,
            message: $"branch removed: ($branch)"
        }
    }
}

# Delete a remote branch
export def delete-remote-branch [
    remote: string
    branch: string
    workdir: path = "."
]: [nothing -> record<success: bool, message: string>] {
    let result = (^git -C $workdir push $remote --delete $branch | complete)

    if $result.exit_code != 0 {
        {
            success: false,
            message: $"Warning: could not delete remote branch ($remote)/($branch): ($result.stderr | str trim)"
        }
    } else {
        {
            success: true,
            message: $"Remote branch deleted: ($remote)/($branch)"
        }
    }
}

# Check if gum is available
export def has-gum []: nothing -> bool {
    which gum | is-not-empty
}

# Basic confirmation prompt using print and input (fallback when gum is not available)
export def confirm-basic [
    prompt: string
    --default  # If true, default is yes; otherwise default is no
]: nothing -> bool {
    let default_text = if $default { "Y/n" } else { "y/N" }
    print $"($prompt) \(($default_text)\)"

    let response = (input "> " | str trim | str downcase)

    # Handle empty input (use default)
    if ($response | is-empty) {
        return $default
    }

    # Check for yes/y
    if $response == "y" or $response == "yes" {
        return true
    }

    # Check for no/n
    if $response == "n" or $response == "no" {
        return false
    }

    # Invalid input, use default
    print $"Invalid input, using default: (if $default { 'yes' } else { 'no' })"
    $default
}

# Build gum prompt options for branch deletion
export def build-gum-options [
    has_remote: bool
]: nothing -> list<string> {
    if $has_remote {
        ["No, keep the branch", "Yes, delete local only", "Yes, delete local and remote"]
    } else {
        ["No, keep the branch", "Yes, delete local branch"]
    }
}

# Run gum interactive choice
export def prompt-with-gum [
    header: string
    options: list<string>
]: nothing -> string {
    let choice = (do -i {
        $options | ^gum choose --header $header | complete
    })

    if $choice.exit_code != 0 {
        null
    } else {
        $choice.stdout | str trim
    }
}

# Resolve worktree path with auto-detection
export def resolve-worktree-path-for-removal [
    path_input: path
    current_dir: path
]: nothing -> path {
    let expanded = ($path_input | path expand)
    if ($expanded | path exists) {
        $expanded
    } else {
        # Try .worktrees/<name> in current directory
        let auto_path = ($current_dir | path join ".worktrees" $path_input | path expand)
        if ($auto_path | path exists) {
            $auto_path
        } else {
            # Use original path (will error later if invalid)
            $expanded
        }
    }
}

# Find worktree path by branch name from git worktree list
# Returns null if no worktree exists for the branch
export def get-worktree-path-by-branch [
    branch: string
    workdir: path = "."
]: nothing -> path {
    let worktree_info = (
        get-worktree-list $workdir
        | where branch == $"[($branch)]"
        | get 0?
    )

    if $worktree_info == null {
        null
    } else {
        $worktree_info.path
    }
}
