use util.nu [to-go-duration, gum-path]

export def "gum table" [
    --separator(-s): string
    --columns(-c): list<string>
    --widths(-w): list<int>
    --height: int
    --print(-p)
    --file(-f): string
    --border(-b): string
    --show-help
    --return-column(-r): int
    --timeout: duration
]: [table -> string, string -> string, nothing -> string] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $separator != null { $args = ($args | append [--separator $separator]) }
    if $columns != null { $args = ($args | append [--columns ($columns | str join ",")]) }
    if $widths != null { $args = ($args | append [--widths ($widths | each { into string } | str join ",")]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $print { $args = ($args | append "--print") }
    if $file != null { $args = ($args | append [--file $file]) }
    if $border != null { $args = ($args | append [--border $border]) }
    if $show_help { $args = ($args | append "--show-help") }
    if $return_column != null { $args = ($args | append [--return-column ($return_column | into string)]) }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let csv_input = match ($input | describe | str replace --regex '<.*' '') {
        "table" | "list" => { $input | to csv },
        "string" => $input,
        _ => ""
    }

    let output = try {
        $csv_input | ^gum table ...$args
    } catch {
        error make --unspanned { msg: $"gum table failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
