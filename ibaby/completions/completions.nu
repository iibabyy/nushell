export-env {
    let fish_completer = {|spans|
        try {
            let cmd = $spans | str join ' '
            ^fish --command $"complete --do-complete='($cmd)'"
            | from tsv --flexible --noheaders --no-infer
            | rename value description
        } catch {
            []
        }
    }

    let z_completer = {|spans|
        # 1. Safely get the command name
        let cmd = $spans.0
        let lookup = (which $cmd | get --optional 0)

        let supported_cmds = ["z", "zi", "zoxide"]

        # 2. Check if the command is one of our zoxide aliases
        let is_supported = ($cmd in $supported_cmds)

        # 3. Logic: If it's a known internal Nu command AND NOT a zoxide command,
        # return empty list to allow native Nushell completions.
        # (null would fall back to file completion, which overrides native flags)
        if ($lookup != null) and ($lookup.type != "external") and (not $is_supported) {
            []
        } else {
            do $fish_completer $spans
        }
    }

    $env.config.completions.external = {
        enable: true
        max_results: 100
        completer: $z_completer
    }
}
