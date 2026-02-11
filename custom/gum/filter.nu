use util.nu [to-go-duration, gum-path]

export def "gum filter" [
    ...options: string
    --header: string
    --height: int
    --limit: int
    --no-limit
    --placeholder: string
    --prompt: string
    --width: int
    --value: string
    --reverse
    --fuzzy
    --fuzzy-sort
    --strict
    --indicator: string
    --select-if-one
    --selected: list<string>
    --show-help
    --timeout: duration
]: [list<string> -> string, list<string> -> list<string>, nothing -> string, nothing -> list<string>] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $header != null { $args = ($args | append [--header $header]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $limit != null { $args = ($args | append [--limit ($limit | into string)]) }
    if $no_limit { $args = ($args | append "--no-limit") }
    if $placeholder != null { $args = ($args | append [--placeholder $placeholder]) }
    if $prompt != null { $args = ($args | append [--prompt $prompt]) }
    if $width != null { $args = ($args | append [--width ($width | into string)]) }
    if $value != null { $args = ($args | append [--value $value]) }
    if $reverse { $args = ($args | append "--reverse") }
    if $fuzzy { $args = ($args | append "--fuzzy") }
    if $fuzzy_sort { $args = ($args | append "--fuzzy-sort") }
    if $strict { $args = ($args | append "--strict") }
    if $indicator != null { $args = ($args | append [--indicator $indicator]) }
    if $select_if_one { $args = ($args | append "--select-if-one") }
    if $selected != null { $args = ($args | append [--selected ($selected | str join ",")]) }
    if $show_help { $args = ($args | append "--show-help") }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }

    let multi = $no_limit or ($limit != null and $limit > 1)

    let output = try {
        if ($input | is-not-empty) {
            $input | str join "\n" | ^gum filter ...$args
        } else {
            ^gum filter ...$args ...$options
        }
    } catch {
        error make --unspanned { msg: $"gum filter failed with exit code ($env.LAST_EXIT_CODE)" }
    }

    let output = $output | str trim --right --char "\n"
    if $multi {
        $output | lines
    } else {
        $output
    }
}
