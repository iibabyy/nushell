use util.nu [to-go-duration, gum-path]

export def "gum choose" [
    ...options: string
    --header: string
    --height: int
    --cursor: string
    --limit: int
    --no-limit
    --ordered
    --show-help
    --select-if-one
    --selected: list<string>
    --timeout: duration
]: [list<string> -> string, list<string> -> list<string>, nothing -> string, nothing -> list<string>] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $header != null { $args = ($args | append [--header $header]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $cursor != null { $args = ($args | append [--cursor $cursor]) }
    if $limit != null { $args = ($args | append [--limit ($limit | into string)]) }
    if $no_limit { $args = ($args | append "--no-limit") }
    if $ordered { $args = ($args | append "--ordered") }
    if $show_help { $args = ($args | append "--show-help") }
    if $select_if_one { $args = ($args | append "--select-if-one") }
    if $selected != null { $args = ($args | append [--selected ($selected | str join ",")]) }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let multi = $no_limit or ($limit != null and $limit > 1)

    let result = if ($input | is-not-empty) {
        $input | str join "\n" | ^$gum choose ...$args | complete
    } else {
        ^$gum choose ...$args ...$options | complete
    }

    if $result.exit_code != 0 {
        error make --unspanned { msg: $"gum choose failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }

    let output = $result.stdout | str trim --right --char "\n"
    if $multi {
        $output | lines
    } else {
        $output
    }
}
