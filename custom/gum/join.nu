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

    let output = try {
        ^gum join ...$args ...$text
    } catch {
        error make --unspanned { msg: $"gum join failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
