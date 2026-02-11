use util.nu [to-go-duration, gum-path]

export def "gum write" [
    --header: string
    --placeholder: string
    --prompt: string
    --value: string
    --width: int
    --height: int
    --char-limit: int
    --max-lines: int
    --show-cursor-line
    --show-line-numbers
    --show-help
    --timeout: duration
]: nothing -> string {
    let gum = (gum-path)
    mut args: list<string> = []
    if $header != null { $args = ($args | append [--header $header]) }
    if $placeholder != null { $args = ($args | append [--placeholder $placeholder]) }
    if $prompt != null { $args = ($args | append [--prompt $prompt]) }
    if $value != null { $args = ($args | append [--value $value]) }
    if $width != null { $args = ($args | append [--width ($width | into string)]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $char_limit != null { $args = ($args | append [--char-limit ($char_limit | into string)]) }
    if $max_lines != null { $args = ($args | append [--max-lines ($max_lines | into string)]) }
    if $show_cursor_line { $args = ($args | append "--show-cursor-line") }
    if $show_line_numbers { $args = ($args | append "--show-line-numbers") }
    if $show_help { $args = ($args | append "--show-help") }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let output = try {
        ^gum write ...$args
    } catch {
        error make --unspanned { msg: $"gum write failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
