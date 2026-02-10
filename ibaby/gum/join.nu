use util.nu [gum-path]

export def "gum join" [
    ...text: string
    --align: string
    --horizontal
    --vertical
]: nothing -> string {
    let gum = (gum-path)
    mut args: list<string> = []
    if $align != null { $args = ($args | append [--align $align]) }
    if $horizontal { $args = ($args | append "--horizontal") }
    if $vertical { $args = ($args | append "--vertical") }

    let result = ^$gum join ...$args ...$text | complete
    if $result.exit_code != 0 {
        error make --unspanned { msg: $"gum join failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }
    $result.stdout | str trim --right --char "\n"
}
