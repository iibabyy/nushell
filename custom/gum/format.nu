use util.nu [gum-path]

export def "gum format" [
    ...template: string
    --theme: string
    --language(-l): string
    --type(-t): string
]: [string -> string, nothing -> string] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $theme != null { $args = ($args | append [--theme $theme]) }
    if $language != null { $args = ($args | append [--language $language]) }
    if $type != null { $args = ($args | append [--type $type]) }

    let output = try {
        if ($input | is-not-empty) {
            $input | ^gum format ...$args
        } else {
            ^gum format ...$args ...$template
        }
    } catch {
        error make --unspanned { msg: $"gum format failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
