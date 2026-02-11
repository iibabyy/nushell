export def make_error_with_span [msg: string, span?: any, label?: string, --hint: string] {
    if $span != null {
        if $hint != null {
            error make { msg: $msg, label: { text: $label, span: $span }, help: $hint }
        } else {
            error make { msg: $msg, label: { text: $label, span: $span } }
        }
    } else {
        if $hint != null {
            error make --unspanned { msg: $msg, help: $hint }
        } else {
            error make --unspanned { msg: $msg }
        }
    }
}

# Copy files listed in .gitignore from base to target directory
#
# Parses the .gitignore file in the base directory and copies all matching
# files/directories to the target location. Useful for seeding git worktrees
# with build artifacts, .env files, node_modules, or other ignored files that
# speed up development. Supports glob patterns like *.log, dist/, and **/*.env.
#
# Returns a list of messages: success messages (sorted) followed by error
# messages (sorted). With --quiet, only returns error messages. Error messages
# are always printed to stderr; success messages only print without --quiet.
#
# Files already existing at the target are skipped with an error message.
# Comment lines (#) and empty lines in .gitignore are ignored.
# .git and node_modules are always skipped regardless of .gitignore content.
@example "Copy gitignored files to a worktree" {cp-gitignored ~/project ~/worktrees/project/feature-branch}
@example "Copy quietly, only showing errors" {cp-gitignored ~/project ~/backup --quiet}
export def cp-gitignored [
  base: path           # Source directory containing .gitignore
  target: path         # Destination directory to copy files to
  --quiet(-q)          # Only show error messages, hide success messages
]: nothing -> string {
    let abs_base = ($base | path expand)
    let abs_target = ($target | path expand)

    # Validate base directory
    if not ($abs_base | path exists) {
        error make {
            msg: $"Base directory does not exist: ($abs_base)"
            label: { text: "Not found", span: (metadata $base).span }
        }
    }
    if ($abs_base | path type) != "dir" {
        error make {
            msg: $"Base path is not a directory: ($abs_base)"
            label: { text: "not a directory", span: (metadata $base).span }
        }
    }

    # Validate or create target directory
    if ($abs_target | path exists) {
        if ($abs_target | path type) != "dir" {
            error make {
                msg: $"Target path exists but is not a directory: ($abs_target)"
                label: { text: "not a directory", span: (metadata $target).span }
            }
        }
    } else {
        try {
            mkdir $abs_target
        } catch {
            error make {
                msg: $"Failed to create target directory: ($abs_target)"
                label: { text: "cannot create directory", span: (metadata $target).span }
            }
        }
    }

    let gitignore = ($abs_base | path join ".gitignore")

    let skipped_files = [
        ".git",
        "node_modules"
    ]

    # Process .gitignore patterns
    let result = if ($gitignore | path exists) {
        (try { open $gitignore } catch { |err| print -e $"Warning: could not read ($gitignore): ($err.msg)"; "" })
        | lines
        | each {|line| $line | str trim }
        | where { |line|
            # Skip empty lines, comments, and explicitly skipped files
            ($line | is-not-empty) and (not ($line | str starts-with "#")) and (not ($skipped_files | any {|skip| $line == $skip }))
        }
        | each { |pattern|
            let trimmed = ($pattern | str trim --right --char "/")
            let search_path = ($abs_base | path join $trimmed)
            # Try glob pattern first, fall back to literal path if no matches
            let matches = (try { glob $search_path } catch { |err| print -e $"Warning: invalid glob pattern '($trimmed)': ($err.msg)"; [] })
            if ($matches | is-empty) and ($search_path | path exists) {
                [$search_path]
            } else {
                $matches
            }
            | each { |src|
                let dest = ($abs_target | path join ($src | path relative-to $abs_base))
                let src_abs = ($src | path expand)

                # Skip if source is target, contains target, or is contained by target
                let should_skip = (
                    ($src_abs == $abs_target) or
                    ($src_abs | str starts-with $"($abs_target)/") or
                    ($abs_target | str starts-with $"($src_abs)/")
                )

                if $should_skip {
                    {success: [], errors: []}
                } else if ($dest | path exists) {
                    let msg = $"(ansi red)($dest) already exists(ansi reset)"
                    print -e $msg
                    {success: [], errors: [$msg]}
                } else {
                    try {
                        mkdir ($dest | path dirname)
                        cp -r $src $dest
                        let msg = $"Copied ($src) to ($dest)"
                        if not $quiet { print $msg }
                        {success: [$msg], errors: []}
                    } catch { |err|
                        let msg = $"(ansi red)Failed to copy ($src) to ($dest): ($err.msg)(ansi reset)"
                        print -e $msg
                        {success: [], errors: [$msg]}
                    }
                }
            }
        }
        | flatten
    } else {
        []
    }

    # Separate and sort messages
    let success = ($result | each { |r| $r.success } | flatten | sort)
    let errors = ($result | each { |r| $r.errors } | flatten | sort)

    let messages = if $quiet { $errors } else { $success | append $errors }
    $messages | str join '\n'
}
