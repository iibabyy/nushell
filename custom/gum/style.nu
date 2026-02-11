use util.nu [gum-path]

export def "gum style" [
    ...text: string
    --foreground: string
    --background: string
    --border: string
    --border-foreground: string
    --border-background: string
    --align: string
    --height: int
    --width: int
    --margin: string
    --padding: string
    --bold
    --faint
    --italic
    --strikethrough
    --underline
    --trim
]: [string -> string, nothing -> string] {
    let input = $in
    let gum = (gum-path)
    mut args: list<string> = []
    if $foreground != null { $args = ($args | append [--foreground $foreground]) }
    if $background != null { $args = ($args | append [--background $background]) }
    if $border != null { $args = ($args | append [--border $border]) }
    if $border_foreground != null { $args = ($args | append [--border-foreground $border_foreground]) }
    if $border_background != null { $args = ($args | append [--border-background $border_background]) }
    if $align != null { $args = ($args | append [--align $align]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $width != null { $args = ($args | append [--width ($width | into string)]) }
    if $margin != null { $args = ($args | append [--margin $margin]) }
    if $padding != null { $args = ($args | append [--padding $padding]) }
    if $bold { $args = ($args | append "--bold") }
    if $faint { $args = ($args | append "--faint") }
    if $italic { $args = ($args | append "--italic") }
    if $strikethrough { $args = ($args | append "--strikethrough") }
    if $underline { $args = ($args | append "--underline") }
    if $trim { $args = ($args | append "--trim") }

    let output = try {
        if ($input | is-not-empty) {
            $input | ^gum style ...$args
        } else {
            ^gum style ...$args ...$text
        }
    } catch {
        error make --unspanned { msg: $"gum style failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
