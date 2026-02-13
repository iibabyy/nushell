# Completer that returns no completions
export def no_completion [context: string] {
    []
}

# Completer for git branches
export def git_branches [context: string] {
    try {
        let branches = (^git branch --list --format='%(refname:short)' | lines)
        let branches = if ($context | is-empty) {
            $branches 
        } else {
            $branches | where { |branch| $branch =~ $context }
        }

        $branches | each { |branch| { value: $branch, description: "" } }
    } catch {
        []
    }
}

# Completer for git worktree branches
export def git_worktree_branches [context: string] {
    let result = (do -i { ^git worktree list | complete })

    if $result.exit_code != 0 {
        return []
    }

    let branches = (
        $result.stdout
        | split column -r '\s+' path hash branch
        | where branch != null
        | get branch
        | each { |b| $b | str replace -r '^\[' '' | str replace -r '\]$' '' }
    )

    if ($context | str trim | is-empty) {
        $branches | each { |branch| { value: $branch, description: "" } }
    } else {
        $branches
        | where { |branch| $branch =~ $context }
        | each { |branch| { value: $branch, description: "" } }
    }
}

# Context-aware completer for the gtree command
# In --rm mode: returns existing worktree branches (for removal)
# In create mode: returns nothing (user types a new branch name)
export def gtree_branches [context: string] {
    if not ($context | str contains "--rm") {
        return []
    }

    let result = (do -i { ^git worktree list | complete })

    if $result.exit_code != 0 {
        return []
    }

    $result.stdout
    | lines
    | split column -r '\s+' path hash branch
    | where branch != null and branch != ""
    | each { |row|
        let branch = ($row.branch | str replace -r '^\[' '' | str replace -r '\]$' '')
        { value: $branch, description: $row.path }
    }
}
