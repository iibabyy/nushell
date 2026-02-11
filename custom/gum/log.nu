use util.nu [gum-path]

export def "gum log" [
    ...text: string
    --file(-o): string
    --format(-f): string
    --formatter: string
    --level(-l): string
    --prefix: string
    --structured(-s)
    --time(-t): string
    --min-level: string
]: nothing -> nothing {
    let gum = (gum-path)
    mut args: list<string> = []
    if $file != null { $args = ($args | append [--file $file]) }
    if $format != null { $args = ($args | append [--format $format]) }
    if $formatter != null { $args = ($args | append [--formatter $formatter]) }
    if $level != null { $args = ($args | append [--level $level]) }
    if $prefix != null { $args = ($args | append [--prefix $prefix]) }
    if $structured { $args = ($args | append "--structured") }
    if $time != null { $args = ($args | append [--time $time]) }
    if $min_level != null { $args = ($args | append [--min-level $min_level]) }

    try {
        ^gum log ...$args ...$text
    } catch {
        error make --unspanned { msg: $"gum log failed with exit code ($env.LAST_EXIT_CODE)" }
    }
}
