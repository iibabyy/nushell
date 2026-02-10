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

    let result = if ($input | is-not-empty) {
        $input | ^$gum format ...$args | complete
    } else {
        ^$gum format ...$args ...$template | complete
    }

    if $result.exit_code != 0 {
        error make --unspanned { msg: $"gum format failed \(exit ($result.exit_code)): ($result.stderr | str trim)" }
    }
    $result.stdout | str trim --right --char "\n"
}
