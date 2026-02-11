export-env {
    let bg_fetch = {|| job spawn {
        if (do { ^git rev-parse --is-inside-work-tree } | complete).exit_code == 0 {
            ^git fetch --quiet | ignore
        }
    } }

    $env.config.hooks.pre_prompt = $env.config.hooks.pre_prompt? | default [] | append $bg_fetch
    $env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default [] | append {|before, after| do $bg_fetch }
}
