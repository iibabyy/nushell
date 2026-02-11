use util.nu [to-go-duration, gum-path, is-interrupted]

export def "gum confirm" [
    prompt?: string
    --default
    --affirmative: string
    --negative: string
    --show-help
    --timeout: duration
]: nothing -> bool {
    let gum = (gum-path)
    mut args: list<string> = []
    if $default { $args = ($args | append "--default") }
    if $affirmative != null { $args = ($args | append [--affirmative $affirmative]) }
    if $negative != null { $args = ($args | append [--negative $negative]) }
    if $show_help { $args = ($args | append "--show-help") }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }
    if $prompt != null { $args = ($args | append $prompt) }

    try {
        ^gum confirm ...$args
        true
    } catch {
        # Exit code 1 means user selected "No" - return false
        if $env.LAST_EXIT_CODE == 1 {
            false
        # Exit codes 128+ mean interrupted by signal (Ctrl+C, etc.) - throw custom error
        } else if (is-interrupted $env.LAST_EXIT_CODE) {
            error make --unspanned {
                msg: "Operation cancelled by user"
                help: "Interrupted by signal (Ctrl+C)"
            }
        # Other exit codes are actual errors
        } else {
            error make --unspanned { msg: $"gum confirm failed with exit code ($env.LAST_EXIT_CODE)" }
        }
    }
}
