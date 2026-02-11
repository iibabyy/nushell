use util.nu [to-go-duration, gum-path]

export def "gum input" [
    --header: string
    --placeholder: string
    --prompt: string
    --value: string
    --char-limit: int
    --width: int
    --password
    --show-help
    --timeout: duration
]: nothing -> string {
    let gum = (gum-path)
    mut args: list<string> = []
    if $header != null { $args = ($args | append [--header $header]) }
    if $placeholder != null { $args = ($args | append [--placeholder $placeholder]) }
    if $prompt != null { $args = ($args | append [--prompt $prompt]) }
    if $value != null { $args = ($args | append [--value $value]) }
    if $char_limit != null { $args = ($args | append [--char-limit ($char_limit | into string)]) }
    if $width != null { $args = ($args | append [--width ($width | into string)]) }
    if $password { $args = ($args | append "--password") }
    if $show_help { $args = ($args | append "--show-help") }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let output = try {
        ^gum input ...$args
    } catch {
        error make --unspanned { msg: $"gum input failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
