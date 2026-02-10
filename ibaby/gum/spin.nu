use util.nu [to-go-duration, gum-path]

export def "gum spin" [
    ...command: string
    --title: string
    --spinner(-s): string
    --show-output
    --show-error
    --show-stdout
    --show-stderr
    --align(-a): string
    --timeout: duration
]: nothing -> string {
    let gum = (gum-path)
    mut args: list<string> = []
    if $title != null { $args = ($args | append [--title $title]) }
    if $spinner != null { $args = ($args | append [--spinner $spinner]) }
    if $show_output { $args = ($args | append "--show-output") }
    if $show_error { $args = ($args | append "--show-error") }
    if $show_stdout { $args = ($args | append "--show-stdout") }
    if $show_stderr { $args = ($args | append "--show-stderr") }
    if $align != null { $args = ($args | append [--align $align]) }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let result = ^$gum spin ...$args -- ...$command | complete
    if $result.exit_code != 0 {
        error make --unspanned { msg: $"gum spin failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }
    $result.stdout | str trim --right --char "\n"
}
