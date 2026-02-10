# This file demonstrates the full refactoring pattern for span preservation
# Compare the BEFORE and AFTER sections to see the changes

use span-utils.nu [make-spanned make-spanned-default make-error make-error-with-span]

# ============================================================================
# EXAMPLE 1: Top-level command refactoring
# ============================================================================

# BEFORE: Original gtree-create function
def gtree-create-old [
    branch: string
    custom_path?: path
    base_branch?: string
    custom_workdir?: path
]: nothing -> string {
    # Extract metadata spans (tedious!)
    let path_span = if $custom_path != null { (metadata $custom_path).span } else { null }
    let workdir_span = if $custom_workdir != null { (metadata $custom_workdir).span } else { null }
    let base_branch_span = if $base_branch != null { (metadata $base_branch).span } else { null }

    let workdir = ($custom_workdir | default $env.PWD | path expand)
    # ... rest of function
}

# AFTER: Refactored with spanned values
def gtree-create-new [
    branch: string
    custom_path?: path
    base_branch?: string
    custom_workdir?: path
]: nothing -> string {
    # Wrap all user-provided parameters once at entry
    let spanned_branch = (make-spanned $branch)
    let spanned_path = if $custom_path != null { make-spanned $custom_path } else { null }
    let spanned_base = if $base_branch != null { make-spanned $base_branch } else { null }
    let spanned_workdir = (make-spanned-default $custom_workdir $env.PWD)

    # Pass spanned values down - they preserve spans automatically
    validate-git-repo $spanned_workdir

    if ($spanned_branch.value | is-empty) {
        make-error "branch_name cannot be empty" $spanned_branch --label "empty branch name"
    }

    # Resolve target path (computed value, not spanned)
    # Only unwrap when passing to functions that CAN'T fail because of the input
    # resolve-worktree-path just constructs a path, so it's safe to unwrap
    let workdir = ($spanned_workdir.value | path expand)
    let target = resolve-worktree-path $spanned_branch.value $workdir $spanned_path?.value

    # Always validate with FULL spanned values - they might need the span for errors
    validate-path-available $target $spanned_path
    validate-branch-exists $spanned_base $spanned_workdir
    validate-branch-available $spanned_branch $spanned_workdir

    # ... rest of function
    "Worktree created"
}

# ============================================================================
# EXAMPLE 2: Validation functions (used frequently - unwrap once)
# ============================================================================

# BEFORE: Manual span threading
def validate-git-repo-old [
    workdir: path
    workdir_span?: any
]: nothing -> nothing {
    if (do -i { git -C $workdir rev-parse --is-inside-work-tree | complete } | get exit_code) != 0 {
        let help = if $workdir_span == null {
            "Use --workdir to specify a git repository"
        } else {
            null
        }
        make_error_with_span $"Not in a git repository: ($workdir)" $workdir_span "not a git repository" --hint $help
    }
}

# AFTER: Spanned value with unwrapping once (workdir used multiple times)
export def validate-git-repo [
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    # Unwrap once since we use it multiple times
    let workdir = $spanned_workdir.value

    if (do -i { git -C $workdir rev-parse --is-inside-work-tree | complete } | get exit_code) != 0 {
        let hint = if $spanned_workdir.span == null {
            "Use --workdir to specify a git repository"
        } else {
            null
        }
        make-error-with-span {
            msg: $"Not in a git repository: ($workdir)"
            label: { text: "not a git repository", span: $spanned_workdir.span }
            help: $hint
        }
    }
}

# ============================================================================
# EXAMPLE 3: Validation with inline access (value used only once)
# ============================================================================

# BEFORE: Separate span parameter
def validate-directory-exists-old [
    dir: path
    dir_span?: any
    context: string = "directory"
]: nothing -> nothing {
    if not ($dir | path exists) {
        make_error_with_span $"($context | str capitalize) does not exist: ($dir)" $dir_span "directory not found" --hint "Check the path"
    }
}

# AFTER: Inline access (dir only used in error message)
export def validate-directory-exists [
    spanned_dir: record<value: path, span: any>
    context: string = "directory"
]: nothing -> nothing {
    if not ($spanned_dir.value | path exists) {
        make-error $"($context | str capitalize) does not exist: ($spanned_dir.value)" $spanned_dir --label "directory not found" --hint "Check the path"
    }

    if ($spanned_dir.value | path type) != "dir" {
        make-error $"($context | str capitalize) path is not a directory: ($spanned_dir.value)" $spanned_dir --label "not a directory" --hint "Specify a valid directory path"
    }
}

# ============================================================================
# EXAMPLE 4: Branch validation (mixed usage)
# ============================================================================

# AFTER: Mixed pattern - unwrap once for repeated use
export def validate-branch-exists [
    spanned_branch: record<value: string, span: any>
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let branch = $spanned_branch.value
    let workdir = $spanned_workdir.value

    if not (branch-exists $branch $workdir) {
        let hint = if $spanned_branch.span == null {
            "Use --base-branch to specify a valid base branch"
        } else {
            null
        }
        make-error $"Base branch does not exist: ($branch)" $spanned_branch --label "Not found" --hint $hint
    }
}

export def validate-branch-available [
    spanned_branch: record<value: string, span: any>
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let branch = $spanned_branch.value
    let workdir = $spanned_workdir.value

    if (branch-exists $branch $workdir) {
        make-error $"Branch already exists: ($branch)" $spanned_branch --label "branch already exists"
    }
}

# ============================================================================
# EXAMPLE 5: Handling computed values with inherited spans
# ============================================================================

# Computed value validation: use span from the INPUT that led to the computation
export def validate-path-available [
    target: path                                        # Computed value (not spanned)
    spanned_path?: record<value: path, span: any>      # Original user input
]: nothing -> nothing {
    if ($target | path exists) {
        make-error-with-span {
            msg: $"Target path already exists: ($target)"
            label: { text: "path already exists", span: $spanned_path?.span }
            help: (if $spanned_path == null { "Use --path to specify a different worktree location" } else { null })
        }
    }
}

# ============================================================================
# EXAMPLE 6: Complete top-level command
# ============================================================================

export def gtree [
    branch: string                              # Name of the branch
    --rm                                        # Remove mode
    --path(-p): path                            # Custom path for worktree
    --base-branch: string                       # Base branch to branch from
    --workdir(-w): path                         # Base directory
    --delete-branch(-d)                         # Also delete branch
    --force(-f)                                 # Force removal
]: nothing -> string {
    # STEP 1: Wrap ALL user-provided parameters at entry
    let spanned_branch = (make-spanned $branch)
    let spanned_path = if $path != null { make-spanned $path } else { null }
    let spanned_base = if $base_branch != null { make-spanned $base_branch } else { null }
    let spanned_workdir = (make-spanned-default $workdir $env.PWD)

    # STEP 2: Validate flags (using .value for inline checks)
    if $rm {
        if $spanned_path != null {
            make-error "Cannot use --path with --rm" $spanned_path --label "incompatible with --rm"
        }
        if $spanned_base != null {
            make-error "Cannot use --base-branch with --rm" $spanned_base --label "incompatible with --rm"
        }
    }

    # STEP 3: Pass spanned values to helper functions
    if $rm {
        # Only unwrap for pure computation functions (can't fail)
        let workdir = ($spanned_workdir.value | path expand)
        let resolved_path = (resolve-worktree-path-from-branch $spanned_branch.value $workdir)

        # Pass spanned values to functions that might need to report errors
        gtree-remove $resolved_path $spanned_branch $spanned_workdir --force=$force
    } else {
        # Always pass spanned values to validation/creation functions
        gtree-create $spanned_branch $spanned_path $spanned_base $spanned_workdir
    }
}

# Helper function receiving spanned values
def gtree-remove [
    worktree_path: path                                 # Computed path
    spanned_branch: record<value: string, span: any>    # For error reporting
    spanned_workdir: record<value: path, span: any>
    --force: bool
]: nothing -> string {
    let workdir = ($spanned_workdir.value | path expand)

    # Validate with spanned values
    validate-directory-exists $spanned_workdir "working directory"
    validate-git-repo $spanned_workdir

    # Get branch info (uses .value inline since used once)
    let branch_name = get-worktree-branch $worktree_path $workdir

    # Check for uncommitted changes - use original branch span for errors
    if not $force and ($worktree_path | path exists) {
        validate-worktree-clean $worktree_path $spanned_branch
    }

    # ... rest of removal logic
    "Worktree removed"
}

# ============================================================================
# KEY PATTERNS SUMMARY
# ============================================================================

# 1. TOP-LEVEL: Wrap all user params with make-spanned / make-spanned-default
# 2. HELPER FUNCTIONS: Accept record<value: T, span: any>
# 3. PASSING TO SUBFUNCTIONS:
#    - Default: Pass spanned values (they might need the span for errors)
#    - Exception: Unwrap ONLY for pure functions that can't fail (e.g., path construction)
# 4. WITHIN A FUNCTION:
#    - Frequent use: Unwrap once at function entry (let x = $spanned_x.value)
#    - Infrequent use: Access inline with .value
# 5. COMPUTED VALUES: Stay as regular types, use span from input that led to them
# 6. ERROR REPORTING:
#    - Use make-error when you have the full spanned value
#    - Use make-error-with-span with error object: {msg, label: {text, span}, help}
