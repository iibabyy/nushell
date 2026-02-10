# Span Preservation Pattern - Migration Guide

## Overview

This guide shows how to migrate from manual span threading to the spanned value pattern.

## Core Utilities (span-utils.nu)

```nu
# Create spanned value from user input
make-spanned $value
# => { value: <original-value>, span: <metadata-span> }

# Create spanned value with default
make-spanned-default $optional_value $default
# => { value: <value-or-default>, span: <span-or-null> }

# Error with spanned value
make-error "message" $spanned_value --label "..." --hint "..."

# Error with error object (auto-detects if span is present)
make-error-with-span {
    msg: "message"
    label: { text: "error", span: $some_span }
    help: "hint"
}
```

## Migration Steps

### Step 1: Identify Entry Points

Find all public `export def` commands that accept user parameters:
- `gtree`
- `cp-gitignored`
- Any other commands users call directly

### Step 2: Wrap Parameters at Entry

**Before:**
```nu
export def gtree [
    branch: string
    --path: path
    --workdir: path
]: nothing -> string {
    let path_span = if $path != null { (metadata $path).span } else { null }
    let workdir_span = if $workdir != null { (metadata $workdir).span } else { null }
    # ...
}
```

**After:**
```nu
use span-utils.nu [make-spanned make-spanned-default]

export def gtree [
    branch: string
    --path: path
    --workdir: path
]: nothing -> string {
    let spanned_branch = (make-spanned $branch)
    let spanned_path = if $path != null { make-spanned $path } else { null }
    let spanned_workdir = (make-spanned-default $workdir $env.PWD)
    # ...
}
```

### Step 3: Update Helper Function Signatures

**Before:**
```nu
def validate-git-repo [
    workdir: path
    workdir_span?: any
]: nothing -> nothing { ... }
```

**After:**
```nu
def validate-git-repo [
    spanned_workdir: record<value: path, span: any>
]: nothing -> nothing {
    let workdir = $spanned_workdir.value  # Unwrap once if used frequently
    # ...
}
```

### Step 4: Update Error Calls

**Before:**
```nu
make_error_with_span
    $"Not in a git repository: ($workdir)"
    $workdir_span
    "not a git repository"
    --hint $help
```

**After:**
```nu
make-error
    $"Not in a git repository: ($workdir)"
    $spanned_workdir
    --label "not a git repository"
    --hint $help
```

### Step 5: Update Call Sites

**Before:**
```nu
validate-git-repo $workdir $workdir_span
validate-branch-exists $base $base_branch_span $workdir
```

**After:**
```nu
validate-git-repo $spanned_workdir
validate-branch-exists $spanned_base $spanned_workdir
```

## Decision Trees

### When passing to subfunctions

```
Can the subfunction fail because of this argument?
├─ YES: Pass the full spanned value
│  └─ validate-git-repo $spanned_workdir
│  └─ validate-branch-exists $spanned_base $spanned_workdir
│
└─ NO (pure computation, can't fail): Unwrap before passing
   └─ resolve-worktree-path $spanned_branch.value $workdir
   └─ get-current-branch $workdir
```

**Rule of thumb:** When in doubt, pass the spanned value. The subfunction might need it for error reporting.

### Within a function (accessing the value)

```
Is the value used more than 2-3 times in the function?
├─ YES: Unwrap once at function entry
│  └─ let workdir = $spanned_workdir.value
│
└─ NO: Access inline with .value
   └─ if ($spanned_dir.value | path exists) { ... }
```

## Handling Edge Cases

### Case 1: Nullable Optional Parameters

```nu
# When parameter might be null
let spanned_path = if $custom_path != null {
    make-spanned $custom_path
} else {
    null
}

# Later, check for null before accessing
if $spanned_path != null {
    validate-path $spanned_path
}
```

### Case 2: Computed Values That Need Error Reporting

```nu
# Computed value from user input
let target = resolve-worktree-path $spanned_branch.value $workdir

# If target causes error, use span from the INPUT that led to it
if ($target | path exists) {
    make-error-with-span {
        msg: $"Target path exists: ($target)"
        label: { text: "path already exists", span: $spanned_branch.span }
    }
}
```

### Case 3: Multiple Possible Span Sources

```nu
# When error could be caused by either parameter
let target = resolve-worktree-path $spanned_branch.value $spanned_path?.value

if ($target | path exists) {
    # Prefer the more specific parameter's span
    let error_span = if $spanned_path != null {
        $spanned_path.span
    } else {
        $spanned_branch.span
    }
    make-error-with-span {
        msg: "Target exists"
        label: { text: "path already exists", span: $error_span }
    }
}
```

### Case 4: Flags (Boolean Parameters)

```nu
# Flags don't need spans - they're not paths/values that can be "wrong"
export def gtree [
    branch: string
    --force  # No need to wrap this
    --rm     # Or this
] {
    let spanned_branch = (make-spanned $branch)  # Only wrap the value

    if $force {
        # Just use the flag directly
    }
}
```

### Case 5: Chaining Through Multiple Functions

```nu
# Top-level wraps
export def gtree [...] {
    let spanned_branch = (make-spanned $branch)
    gtree-create $spanned_branch  # Pass through
}

# Intermediate function passes through
def gtree-create [
    spanned_branch: record<value: string, span: any>
] {
    validate-branch-available $spanned_branch  # Pass through again
}

# Leaf function uses it
def validate-branch-available [
    spanned_branch: record<value: string, span: any>
] {
    if (branch-exists $spanned_branch.value) {
        make-error "Branch exists" $spanned_branch  # Finally used
    }
}
```

## Testing the Migration

### Test 1: User-Provided Value (Mandatory)
```nu
gtree "feature/test"
# Error should point to the branch string in the command
```

### Test 2: User-Provided Flag
```nu
gtree "feature/test" --workdir /invalid/path
# Error should point to /invalid/path
```

### Test 3: Default Value
```nu
gtree "feature/test"  # Uses $env.PWD as default
# Error should be unspanned (no specific location to point to)
```

### Test 4: Computed Value
```nu
gtree "feature/existing"  # Branch exists, target path computed
# Error should point back to the branch name (input that led to computation)
```

## Common Mistakes

### ❌ Wrong: Wrapping Computed Values
```nu
let target = resolve-worktree-path $branch $workdir
let spanned_target = (make-spanned $target)  # NO! Target has new metadata
```

### ✅ Right: Use Input's Span for Computed Values
```nu
let target = resolve-worktree-path $spanned_branch.value $workdir
# If error, use $spanned_branch.span
```

### ❌ Wrong: Double Unwrapping
```nu
let workdir = $spanned_workdir.value
validate-git-repo $workdir  # Lost the span!
```

### ✅ Right: Pass Spanned Value
```nu
let workdir = $spanned_workdir.value  # For local use
validate-git-repo $spanned_workdir    # Pass full spanned value
```

### ❌ Wrong: Inconsistent Naming
```nu
let branch_spanned = (make-spanned $branch)
let workdir_with_span = (make-spanned $workdir)
```

### ✅ Right: Consistent Prefix
```nu
let spanned_branch = (make-spanned $branch)
let spanned_workdir = (make-spanned $workdir)
```

## Performance Considerations

**Q: Does wrapping every parameter have performance overhead?**

A: Minimal. You're creating small records once per command invocation. The cost is:
- Memory: ~48 bytes per spanned value (pointer + span data)
- Time: ~1-2 microseconds per `make-spanned` call

For CLI tools, this is negligible compared to I/O operations (git commands, file access).

**Q: Should I avoid unwrapping in hot loops?**

A: Yes. If you have a loop processing many items:
```nu
let values = (get-many-items)
let workdir = $spanned_workdir.value  # Unwrap ONCE before loop

for item in $values {
    process-item $item $workdir  # Use unwrapped value
}
```

## Complete Before/After Example

See `REFACTORING-EXAMPLE.nu` for side-by-side comparisons of:
- Top-level commands
- Validation functions
- Mixed usage patterns
- Error reporting
