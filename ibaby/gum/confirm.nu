use util.nu [to-go-duration, gum-path]

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

    let result = ^$gum confirm ...$args | complete
    match $result.exit_code {
        0 => true,
        1 => false,
        _ => {
            error make --unspanned { msg: $"gum confirm failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
        }
    }
}
