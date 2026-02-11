# Concrete Refactoring Example

This shows the actual refactoring of `validate-git-repo` and its callers.

## Before: Current Implementation

### worktree-utils.nu
```nu
use utils.nu make_error_with_span

export def validate-git-repo [
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
```

### worktree.nu (caller)
```nu
def gtree-create [
    branch: string
    custom_path?: path
    base_branch?: string
    custom_workdir?: path
]: nothing -> string {
    # Manual span extraction
    let path_span = if $custom_path != null { (metadata $custom_path).span } else { null }
    let workdir_span = if $custom_workdir != null { (metadata $custom_workdir).span } else { null }
    let base_branch_span = if $base_branch != null { (metadata $base_branch).span } else { null }

    let workdir = ($custom_workdir | default $env.PWD | path expand)
    validate-git-repo $workdir $workdir_span  # Pass both value and span
    # ...
}
```

---

## After: Refactored with Spanned Values

### span-utils.nu (new file)
```nu
# Core utilities for span preservation
# NOTE: Metadata must be passed explicitly because calling (metadata $value)
# inside the function would capture the span at the function's call site,
# not from where the user originally provided the value.
export def make-spanned [value: any, meta: record]: nothing -> record<value: any, span: any> {
    { value: $value, span: ($meta | get span) }
}

export def make-spanned-default [value: any, default: any, meta?: record]: nothing -> record<value: any, span: any> {
    if $value != null {
        { value: $value, span: ($meta | get span) }
    } else {
        { value: $default, span: null }
    }
}

export def make-error [
    msg: string
    spanned_value?: record<value: any, span: any>
    --label: string = "error"
    --hint: string
]: nothing -> nothing {
    let span = if $spanned_value != null { $spanned_value.span } else { null }

    if $span != null {
        let err = { msg: $msg, label: { text: $label, span: $span } }
        let full = if $hint != null { $err | insert help $hint } else { $err }
        error make $full
    } else {
        let err = { msg: $msg }
        let full = if $hint != null { $err | insert help $hint } else { $err }
        error make --unspanned $full
    }
}

export def make-error-with-span [
    error_object: any
]: nothing -> nothing {
    let has_span = (
        ($error_object.label? != null) and
        ($error_object.label.span? != null)
    )

    if $has_span {
        error make $error_object
    } else {
        error make --unspanned $error_object
    }
}
```

### worktree-utils.nu (refactored)
```nu
use span-utils.nu [make-error make-error-with-span]

# Validate that a directory is a git repository
export def validate-git-repo [
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    # Unwrap once - used twice
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
    # Inline access - only used in error messages
    if not ($spanned_dir.value | path exists) {
        make-error
            $"($context | str capitalize) does not exist: ($spanned_dir.value)"
            $spanned_dir
            --label "directory not found"
            --hint "Check the path"
    }

    if ($spanned_dir.value | path type) != "dir" {
        make-error
            $"($context | str capitalize) path is not a directory: ($spanned_dir.value)"
            $spanned_dir
            --label "not a directory"
            --hint "Specify a valid directory path"
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
        let hint = if $spanned_branch.span == null {
            "Use --base-branch to specify a valid base branch"
        } else {
            null
        }
        make-error
            $"Base branch does not exist: ($branch)"
            $spanned_branch
            --label "Not found"
            --hint $hint
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
        make-error
            $"Branch already exists: ($branch)"
            $spanned_branch
            --label "branch already exists"
    }
}

# Resolve the worktree target path
export def resolve-worktree-path [
    branch: string                     # Unwrapped value
    workdir: path                      # Unwrapped value
    custom_path?: path                 # Unwrapped value (may be null)
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
    target: path                                       # Computed value (not spanned)
    spanned_path?: record<value: path, span: any>     # Original user input
]: nothing -> nothing {
    if ($target | path exists) {
        make-error-with-span {
            msg: $"Target path already exists: ($target)"
            label: { text: "path already exists", span: $spanned_path?.span }
            help: (if $spanned_path == null { "Use --path to specify a different worktree location" } else { null })
        }
    }
}
```

### worktree.nu (refactored caller)
```nu
use completers.nu git_branches
use utils.nu cp-gitignored
use worktree-utils.nu *
use span-utils.nu [make-spanned make-spanned-default make-error]

# Create a new worktree
def gtree-create [
    branch: string
    custom_path?: path
    base_branch?: string
    custom_workdir?: path
]: nothing -> string {
    # STEP 1: Wrap all user-provided parameters at entry point
    let spanned_branch = (make-spanned $branch (metadata $branch))
    let spanned_path = if $custom_path != null { make-spanned $custom_path (metadata $custom_path) } else { null }
    let spanned_base = if $base_branch != null { make-spanned $base_branch (metadata $base_branch) } else { null }
    let spanned_workdir = (make-spanned-default $custom_workdir $env.PWD (metadata $custom_workdir))

    # STEP 2: Validate with spanned values (pass full spanned values)
    validate-git-repo $spanned_workdir

    if ($spanned_branch.value | is-empty) {
        make-error "branch_name cannot be empty" $spanned_branch --label "empty branch name"
    }

    # STEP 3: Unwrap ONLY for pure computation functions (can't fail)
    let workdir = ($spanned_workdir.value | path expand)
    let target = (resolve-worktree-path $spanned_branch.value $workdir $spanned_path?.value)

    # STEP 4: Validate computed values, passing original spanned inputs
    validate-path-available $target $spanned_path

    # STEP 5: More validation - always pass full spanned values
    let base = ($spanned_base?.value | default (get-current-branch $workdir))
    if $spanned_base != null {
        validate-branch-exists $spanned_base $spanned_workdir
    }
    validate-branch-available $spanned_branch $spanned_workdir

    # STEP 6: Create the worktree (unwrap for pure operations)
    create-worktree $spanned_branch.value $target $base $workdir

    # STEP 7: Setup (unwrap for non-validating operations)
    let copy_errors = (cp-gitignored $workdir $target --quiet)
    run-bun-install $target

    # STEP 8: Build output
    build-create-output $target $copy_errors
}
```

---

## Key Improvements

### 1. Less Boilerplate
**Before:**
```nu
let path_span = if $custom_path != null { (metadata $custom_path).span } else { null }
let workdir_span = if $custom_workdir != null { (metadata $custom_workdir).span } else { null }
let base_branch_span = if $base_branch != null { (metadata $base_branch).span } else { null }
```

**After:**
```nu
let spanned_path = if $custom_path != null { make-spanned $custom_path (metadata $custom_path) } else { null }
let spanned_workdir = (make-spanned-default $custom_workdir $env.PWD (metadata $custom_workdir))
let spanned_base = if $base_branch != null { make-spanned $base_branch (metadata $base_branch) } else { null }
```

### 2. Cleaner Function Signatures
**Before:**
```nu
validate-git-repo [workdir: path, workdir_span?: any]
```

**After:**
```nu
validate-git-repo [spanned_workdir: record<value: path, span: any>]
```

### 3. Simpler Error Calls
**Before:**
```nu
make_error_with_span $"Not in a git repository: ($workdir)" $workdir_span "not a git repository" --hint $help
```

**After:**
```nu
make-error $"Not in a git repository: ($workdir)" $spanned_workdir --label "not a git repository" --hint $help
```

### 4. Automatic Span Preservation
Spans flow through function calls automatically - no manual threading!

---

## Migration Checklist for Your Codebase

- [ ] Add `span-utils.nu` to `git/` directory
- [ ] Update `git/mod.nu` to export span-utils
- [ ] Refactor `validate-git-repo` in worktree-utils.nu
- [ ] Refactor `validate-directory-exists` in worktree-utils.nu
- [ ] Refactor `validate-branch-exists` in worktree-utils.nu
- [ ] Refactor `validate-branch-available` in worktree-utils.nu
- [ ] Refactor `validate-path-available` in worktree-utils.nu
- [ ] Refactor `validate-worktree-clean` in worktree-utils.nu
- [ ] Update `gtree-create` in worktree.nu
- [ ] Update `gtree-remove` in worktree.nu
- [ ] Update `gtree` command entry point
- [ ] Remove old `make_error_with_span` from utils.nu (or keep for compatibility)
- [ ] Test all error paths to ensure spans point to correct locations
