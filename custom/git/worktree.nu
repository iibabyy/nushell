use completers.nu [git_branches gtree_branches]
use utils.nu cp-gitignored
use worktree-utils.nu *
use span-utils.nu [make-spanned make-spanned-default make-error]
use ../gum "gum confirm"

# Create or remove a git worktree
#
# Creates a new git worktree on a fresh branch, copies gitignored files
# (like .env, build artifacts) from the current directory, and runs
# 'bun install' in parallel. The worktree path is automatically copied
# to the clipboard for easy navigation.
#
# With --rm flag, removes the worktree associated with the branch name.
# Uses gum confirmation prompts (unless --yes is used):
#   1. "Are you sure you want to delete {path}?" (default: yes)
#   2. "Do you want to delete the branch?" (default: no)
# If the branch has a remote tracking branch, both local and remote are deleted.
# Use --yes to skip prompts and automatically delete both worktree and branch.
#
# Default worktree location: <current-dir>/.worktrees/<branch-name>
# Branch names with slashes (e.g., feature/foo) are converted to hyphens.
@example "Create worktree for a feature branch" {gtree feature/new-auth}
@example "Create worktree at custom path" {gtree bugfix/login-error --path ~/temp/bugfix}
@example "Create worktree from specific base branch" {gtree hotfix/security --base-branch main}
@example "Remove a worktree by branch name (with confirmation prompts)" {gtree feature/new-auth --rm}
@example "Remove worktree and branch without prompts" {gtree feature/new-auth --rm --yes}
export def gtree [
  branch: string@gtree_branches  # Name of the branch (to create or remove with --rm)
  --rm                         # Remove mode: remove existing worktree for this branch
  --path(-p): path             # Custom path for the worktree (defaults to <workdir>/.worktrees/<branch>)
  --base-branch: string@git_branches  # Base branch to branch from (defaults to current branch)
  --workdir(-w): path          # Base directory for the worktree (defaults to $env.PWD)
  --force(-f)                  # [--rm only] Force removal of dirty worktrees and force-delete branch
  --yes(-y)                    # [--rm only] Skip confirmation prompts (deletes worktree and branch)
]: nothing -> string {
    # Wrap all user-provided parameters at entry
    let spanned_branch = (make-spanned $branch (metadata $branch))
    let spanned_path = if $path != null { make-spanned $path (metadata $path) } else { null }
    let spanned_base = if $base_branch != null { make-spanned $base_branch (metadata $base_branch) } else { null }
    let spanned_workdir = (make-spanned-default $workdir $env.PWD (metadata $workdir))

    # Handle remove mode
    if $rm {
        validate-remove-mode-flags $spanned_path $spanned_base

        # Validate git repo first
        validate-git-repo $spanned_workdir

        # Unwrap for pure computation (can't fail)
        let workdir = ($spanned_workdir.value | path expand)

        # Find worktree by branch name from git worktree list
        let resolved_path = (get-worktree-path-by-branch $spanned_branch.value $workdir)

        if $resolved_path == null {
            make-error $"No worktree found for branch '($spanned_branch.value)'" $spanned_branch --label "worktree not found" --hint "Use 'git worktree list' to see all worktrees"
        }

        # Call gtree-remove with spanned values
        match [$force, $yes] {
            [true, true] => { gtree-remove $resolved_path $spanned_branch $spanned_workdir --force --yes },
            [true, false] => { gtree-remove $resolved_path $spanned_branch $spanned_workdir --force },
            [false, true] => { gtree-remove $resolved_path $spanned_branch $spanned_workdir --yes },
            [false, false] => { gtree-remove $resolved_path $spanned_branch $spanned_workdir }
        }
    } else {
        # Create mode
        validate-create-mode-flags $force $yes
        gtree-create $spanned_branch $spanned_workdir $spanned_path $spanned_base
    }
}

# Validate flags that are incompatible with remove mode
def validate-remove-mode-flags [
    spanned_path?: record<value: path, span: any>
    spanned_base?: record<value: string, span: any>
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
}

# Validate flags that are only for remove mode
def validate-create-mode-flags [
    force?: bool
    yes?: bool
]: nothing -> nothing {
    if $force {
        error make {
            msg: "The --force flag requires --rm"
            label: { text: "requires --rm", span: (metadata $force).span }
            help: "Use: gtree --rm <branch-name> --force"
        }
    }
    if $yes {
        error make {
            msg: "The --yes flag requires --rm"
            label: { text: "requires --rm", span: (metadata $yes).span }
            help: "Use: gtree --rm <branch-name> --yes"
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
# and prompts for confirmation before deletion. Uses gum for interactive prompts.
def gtree-remove [
  worktree_path: path                                 # Path to the worktree to remove (computed)
  spanned_branch: record<value: string, span: any>    # Original user input (for error reporting)
  spanned_workdir: record<value: path, span: any>     # Original user input

  --force(-f)                # Force removal of dirty worktrees and force-delete branch
  --yes(-y)                  # Skip confirmation prompts (deletes worktree and branch)
]: nothing -> string {
    let workdir = ($spanned_workdir.value | path expand)
    let worktree_path = ($worktree_path | path expand)

    # print $"DEBUG gtree-remove: worktree_path=($worktree_path), workdir=($workdir)"

    # Validate environment with spanned values
    validate-directory-exists $spanned_workdir "working directory"
    validate-git-repo $spanned_workdir

    # Get branch information BEFORE removing the worktree
    # (once removed, it won't be in git worktree list anymore)
    let branch_name = (get-worktree-branch $worktree_path $workdir)
    let remote_branch = if $branch_name != null {
        get-remote-tracking-branch $branch_name $workdir
    } else {
        null
    }

    # VALIDATION PHASE: Check everything before prompting
    # Check for uncommitted changes (use branch span for error reporting)
    if not $force and ($worktree_path | path exists) {
        # print $"DEBUG: Checking for uncommitted changes in ($worktree_path)"
        validate-worktree-clean $worktree_path $spanned_branch
    }

    # PROMPTING PHASE: Ask user for all confirmations BEFORE making any changes
    # Check if gum is available
    let use_gum = (has-gum)

    # Prompt 1: Confirm worktree deletion (default yes)
    let confirm_delete = if $yes {
        true
    } else if $use_gum {
        (gum confirm $"Are you sure you want to delete ($worktree_path)?" --default)
    } else {
        (confirm-basic $"Are you sure you want to delete ($worktree_path)?" --default)
    }

    if not $confirm_delete {
        return "Worktree deletion cancelled"
    }

    # Prompt 2: Confirm branch deletion (default no) - only if branch exists
    let confirm_branch = if $branch_name == null {
        false
    } else if $yes {
        true
    } else if $use_gum {
        (gum confirm $"Do you want to delete the branch '($branch_name)'?" --affirmative "Yes" --negative "No")
    } else {
        (confirm-basic $"Do you want to delete the branch '($branch_name)'?")
    }

    # EXECUTION PHASE: Now perform all the actual deletions
    # Remove the worktree
    let remove_msg = handle-worktree-removal $worktree_path $workdir $force

    # Delete the branch if confirmed
    let branch_msg = if $confirm_branch and $branch_name != null {
        if $remote_branch != null {
            # Delete both local and remote
            handle-branch-deletion-both $workdir $force $branch_name $remote_branch
        } else {
            # Delete local only
            handle-branch-deletion-direct $workdir $force $branch_name
        }
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
    # print $"DEBUG: Checking if worktree exists in git worktree list"
    let exists = (worktree-exists $worktree_path $workdir)
    # print $"DEBUG: worktree_exists=($exists)"

    if $exists {
        # print $"DEBUG: Attempting to remove worktree via git"
        if $force {
            remove-worktree-git $worktree_path $workdir --force
        } else {
            remove-worktree-git $worktree_path $workdir
        }
        $"Worktree removed: ($worktree_path)"
    } else if ($worktree_path | path exists) {
        # Orphaned directory
        # print $"DEBUG: Orphaned worktree directory found, removing manually"
        remove-orphaned-directory $worktree_path
        $"Removed orphaned worktree directory: ($worktree_path)"
    } else {
        # print $"DEBUG: Worktree not found in git worktree list and directory doesn't exist"
        $"Worktree not found: ($worktree_path)"
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
        return "Warning: could not find branch for worktree, skipping branch deletion"
    }

    let result = (delete-local-branch $branch_name $workdir --force=$force)
    $result.message
}
