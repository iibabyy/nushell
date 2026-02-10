use completers.nu git_branches
use utils.nu cp-gitignored
use worktree-utils.nu *
use span-utils.nu [make-spanned make-spanned-default make-error]

# Create or remove a git worktree
#
# Creates a new git worktree on a fresh branch, copies gitignored files
# (like .env, build artifacts) from the current directory, and runs
# 'bun install' in parallel. The worktree path is automatically copied
# to the clipboard for easy navigation.
#
# With --rm flag, removes the worktree associated with the branch name.
# Uses an interactive prompt (using gum) to delete the branch (local and/or remote).
#
# Default worktree location: <current-dir>/.worktrees/<branch-name>
# Branch names with slashes (e.g., feature/foo) are converted to hyphens.
@example "Create worktree for a feature branch" {gtree feature/new-auth}
@example "Create worktree at custom path" {gtree bugfix/login-error --path ~/temp/bugfix}
@example "Create worktree from specific base branch" {gtree hotfix/security --base-branch main}
@example "Remove a worktree by branch name (interactive)" {gtree feature/new-auth --rm}
export def gtree [
  branch: string               # Name of the branch (to create or remove with --rm)
  --rm                         # Remove mode: remove existing worktree for this branch
  --path(-p): path             # Custom path for the worktree (defaults to <workdir>/.worktrees/<branch>)
  --base-branch: string@git_branches  # Base branch to branch from (defaults to current branch)
  --workdir(-w): path          # Base directory for the worktree (defaults to $env.PWD)
  --delete-branch(-d)          # [--rm only] Also delete the branch after removing the worktree
  --force(-f)                  # [--rm only] Force removal of dirty worktrees; with -d, force-deletes branch
]: nothing -> string {
    # Wrap all user-provided parameters at entry
    let spanned_branch = (make-spanned $branch)
    let spanned_path = if $path != null { make-spanned $path } else { null }
    let spanned_base = if $base_branch != null { make-spanned $base_branch } else { null }
    let spanned_workdir = (make-spanned-default $workdir $env.PWD)

    # Handle remove mode
    if $rm {
        validate-remove-mode-flags $spanned_path $spanned_base $delete_branch

        # Unwrap for pure computation (can't fail)
        let workdir = ($spanned_workdir.value | path expand)
        let resolved_path = (resolve-worktree-path-from-branch $spanned_branch.value $workdir)

        # Call gtree-remove with spanned values
        if $force {
            gtree-remove $resolved_path $spanned_branch $spanned_workdir --interactive --force
        } else {
            gtree-remove $resolved_path $spanned_branch $spanned_workdir --interactive
        }
    } else {
        # Create mode
        validate-create-mode-flags $delete_branch $force
        gtree-create $spanned_branch $spanned_workdir $spanned_path $spanned_base
    }
}

# Validate flags that are incompatible with remove mode
def validate-remove-mode-flags [
    spanned_path?: record<value: path, span: any>
    spanned_base?: record<value: string, span: any>
    delete_branch?: bool
]: nothing -> nothing {
    if $spanned_path != null {
        error make {
            msg: "Cannot use --path with --rm"
            label: { text: "incompatible with --rm", span: $spanned_path.span }
            help: "The --path flag is only for creating worktrees. To remove a worktree, use: gtree <branch-name> --rm"
        }
    }
    if $spanned_base != null {
        error make {
            msg: "Cannot use --base-branch with --rm"
            label: { text: "incompatible with --rm", span: $spanned_base.span }
            help: "The --base-branch flag is only for creating worktrees. To remove a worktree, use: gtree <branch-name> --rm"
        }
    }
    if $delete_branch {
        error make {
            msg: "Cannot use --delete-branch with --rm"
            label: { text: "use interactive prompt instead", span: (metadata $delete_branch).span }
            help: "gtree --rm uses an interactive prompt to ask about branch deletion"
        }
    }
}

# Validate flags that are only for remove mode
def validate-create-mode-flags [
    delete_branch?: bool
    force?: bool
]: nothing -> nothing {
    if $delete_branch {
        error make {
            msg: "The --delete-branch flag requires --rm"
            label: { text: "requires --rm", span: (metadata $delete_branch).span }
            help: "Use: gtree --rm <branch-name> --delete-branch"
        }
    }
    if $force {
        error make {
            msg: "The --force flag requires --rm"
            label: { text: "requires --rm", span: (metadata $force).span }
            help: "Use: gtree --rm <branch-name> --force"
        }
    }
}

# Create a new worktree
def gtree-create [
    spanned_branch: record<value: string, span: any>
    spanned_workdir: record<value: path, span: any>
    spanned_path?: record<value: path, span: any>
    spanned_base?: record<value: string, span: any>
]: nothing -> string {
    # Validate git repo first
    validate-git-repo $spanned_workdir

    if ($spanned_branch.value | is-empty) {
        make-error "branch_name cannot be empty" $spanned_branch --label "empty branch name"
    }

    # Unwrap for pure computation functions (can't fail)
    let workdir = ($spanned_workdir.value | path expand)
    let custom_path = if $spanned_path != null { $spanned_path.value } else { null }
    let target = (resolve-worktree-path $spanned_branch.value $workdir $custom_path)

    # Validate computed values, passing original spanned inputs
    validate-path-available $target $spanned_path

    # Resolve and validate branches
    let base = if $spanned_base != null { $spanned_base.value } else { get-current-branch $workdir }
    if $spanned_base != null {
        validate-branch-exists $spanned_base $spanned_workdir
    }
    validate-branch-available $spanned_branch $spanned_workdir

    # Create the worktree (unwrap for pure operations)
    create-worktree $spanned_branch.value $target $base $workdir

    # Setup the worktree (unwrap for non-validating operations)
    let copy_errors = (cp-gitignored $workdir $target --quiet)
    run-bun-install $target

    # Build output messages
    build-create-output $target $copy_errors
}

# Build output message for worktree creation
def build-create-output [
    target: path
    copy_errors: string
]: nothing -> string {
    let output = [
        ...($copy_errors | if ($in | is-not-empty) { lines } else { [] })
        $"Worktree created at: ($target)"
        (copy-to-clipboard $target)
    ]

    $output | where { |msg| not ($msg | is-empty) } | str join "\n"
}

# Remove a git worktree by path
#
# Removes a worktree at the specified path, validates it's clean,
# and optionally deletes the associated branch. Use --interactive for
# a gum-based prompt to choose branch deletion options (local/remote).
def gtree-remove [
  worktree_path: path                                 # Path to the worktree to remove (computed)
  spanned_branch: record<value: string, span: any>    # Original user input (for error reporting)
  spanned_workdir: record<value: path, span: any>     # Original user input

  --delete-branch(-d)        # Also delete the branch after removing the worktree
  --force(-f)                # Force removal of dirty worktrees; with -d, force-deletes branch
  --interactive(-i)          # Prompt for branch deletion after removing worktree
]: nothing -> string {
    let workdir = ($spanned_workdir.value | path expand)
    let worktree_path = ($worktree_path | path expand)

    print $"DEBUG gtree-remove: worktree_path=($worktree_path), workdir=($workdir)"

    # Validate environment with spanned values
    validate-directory-exists $spanned_workdir "working directory"
    validate-git-repo $spanned_workdir

    # Get branch information (unwrap for pure query operations)
    let branch_name = if $delete_branch or $interactive {
        get-worktree-branch $worktree_path $workdir
    } else {
        null
    }

    let remote_branch = if $interactive and $branch_name != null {
        get-remote-tracking-branch $branch_name $workdir
    } else {
        null
    }

    # Check for uncommitted changes (use branch span for error reporting)
    if not $force and ($worktree_path | path exists) {
        print $"DEBUG: Checking for uncommitted changes in ($worktree_path)"
        validate-worktree-clean $worktree_path $spanned_branch
    }

    # Remove the worktree
    let remove_msg = handle-worktree-removal $worktree_path $workdir $force

    # Handle branch deletion
    let branch_msg = if $interactive {
        handle-branch-deletion-interactive $workdir $force $branch_name $remote_branch
    } else if $delete_branch {
        handle-branch-deletion-direct $workdir $force $branch_name
    } else {
        null
    }

    # Combine messages
    [$remove_msg $branch_msg]
    | compact
    | where { |msg| not ($msg | is-empty) }
    | str join "\n"
}

# Handle the actual worktree removal
def handle-worktree-removal [
    worktree_path: path
    workdir: path
    force: bool
]: nothing -> string {
    print $"DEBUG: Checking if worktree exists in git worktree list"
    let exists = (worktree-exists $worktree_path $workdir)
    print $"DEBUG: worktree_exists=($exists)"

    if $exists {
        print $"DEBUG: Attempting to remove worktree via git"
        if $force {
            remove-worktree-git $worktree_path $workdir --force
        } else {
            remove-worktree-git $worktree_path $workdir
        }
        $"Worktree removed: ($worktree_path)"
    } else if ($worktree_path | path exists) {
        # Orphaned directory
        print $"DEBUG: Orphaned worktree directory found, removing manually"
        remove-orphaned-directory $worktree_path
        $"(ansi yellow)Removed orphaned worktree directory: ($worktree_path)(ansi reset)"
    } else {
        print $"DEBUG: Worktree not found in git worktree list and directory doesn't exist"
        $"(ansi yellow)Worktree not found: ($worktree_path)(ansi reset)"
    }
}

# Handle branch deletion with interactive prompt
def handle-branch-deletion-interactive [
    workdir: path
    force: bool
    branch_name?: string
    remote_branch?: string
]: nothing -> string {
    if $branch_name == null {
        return null
    }

    if not (has-gum) {
        return $"(ansi yellow)Warning: gum is not installed. Install gum for interactive prompts, or use --delete-branch flag(ansi reset)"
    }

    # Build prompt
    let prompt_msg = if $remote_branch != null {
        $"Delete branch '($branch_name)' (tracking ($remote_branch))?"
    } else {
        $"Delete local branch '($branch_name)'?"
    }

    let options = (build-gum-options ($remote_branch != null))
    let choice = (prompt-with-gum $prompt_msg $options)

    if $choice == null {
        return $"(ansi yellow)Branch deletion cancelled(ansi reset)"
    }

    # Handle the choice
    match $choice {
        "No, keep the branch" => { null },
        "Yes, delete local branch" | "Yes, delete local only" => {
            let result = (delete-local-branch $branch_name $workdir --force=$force)
            $result.message
        },
        "Yes, delete local and remote" => {
            handle-branch-deletion-both $workdir $force $branch_name $remote_branch
        },
        _ => { null }
    }
}

# Handle deletion of both local and remote branches
def handle-branch-deletion-both [
    workdir: path
    force: bool
    branch_name: string
    remote_branch: string
]: nothing -> string {
    let local_result = (delete-local-branch $branch_name $workdir --force=$force)

    let remote_name = ($remote_branch | split row "/" | first)
    let remote_result = (delete-remote-branch $remote_name $branch_name $workdir)

    [$local_result.message $remote_result.message] | str join "\n"
}

# Handle direct branch deletion (non-interactive)
def handle-branch-deletion-direct [
    workdir: path
    force: bool
    branch_name?: string
]: nothing -> string {
    if $branch_name == null {
        return $"(ansi yellow)Warning: could not find branch for worktree, skipping branch deletion(ansi reset)"
    }

    let result = (delete-local-branch $branch_name $workdir --force=$force)
    $result.message
}
