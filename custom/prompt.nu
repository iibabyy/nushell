export def create_left_prompt [] {
    let dir = ($env.PWD | str replace $env.HOME "~") # Shorten home dir to ~
    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })

    # Get git branch safely (handles both regular branches and detached HEAD)
    let git_branch = (do { git branch --show-current } | complete)
    let git_ref = if $git_branch.exit_code == 0 {
        let branch = ($git_branch.stdout | str trim)
        if ($branch | is-empty) {
            # Detached HEAD - show short commit hash
            let head = (do { git rev-parse --short HEAD } | complete)
            if $head.exit_code == 0 { $head.stdout | str trim } else { "" }
        } else {
            $branch
        }
    } else {
        ""
    }

    # Check how many commits ahead/behind upstream
    let ahead_behind = if ($git_ref | is-not-empty) {
        let rev_list = (do { git rev-list --left-right --count HEAD...@{upstream} } | complete)
        if $rev_list.exit_code == 0 {
            let counts = ($rev_list.stdout | str trim | split row "\t")
            if ($counts | length) >= 2 {
                { ahead: ($counts.0 | into int), behind: ($counts.1 | into int) }
            } else {
                { ahead: 0, behind: 0 }
            }
        } else {
            { ahead: 0, behind: 0 }
        }
    } else {
        { ahead: 0, behind: 0 }
    }

    let git_display = if ($git_ref | is-not-empty) {
        let ahead = if $ahead_behind.ahead > 0 {
            $"(ansi green) ↑($ahead_behind.ahead)"
        } else {
            ""
        }
        let behind = if $ahead_behind.behind > 0 {
            $"(ansi red) ↓($ahead_behind.behind)"
        } else {
            ""
        }
        # Using the Unicode escape for the branch symbol
        $"(ansi yellow) \u{e0a0} ($git_ref)($ahead)($behind)"
    } else {
        ""
    }

    $"(ansi reset)($path_color)($dir)($git_display)\n(ansi cyan) (ansi reset)"
}

export-env {
    $env.PROMPT_COMMAND = {|| create_left_prompt }
}
