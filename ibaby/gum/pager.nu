use util.nu [to-go-duration, gum-path]

export def "gum pager" [
    content?: string
    --show-line-numbers
    --soft-wrap
    --timeout: duration
]: [string -> nothing, nothing -> nothing] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $show_line_numbers { $args = ($args | append "--show-line-numbers") }
    if $soft_wrap { $args = ($args | append "--soft-wrap") }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let text = if ($input | is-not-empty) {
        $input
    } else if ($content | is-not-empty) {
        $content
    } else {
        ""
    }

    let result = $text | ^$gum pager ...$args | complete
    if $result.exit_code != 0 {
        error make --unspanned { msg: $"gum pager failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }
}
