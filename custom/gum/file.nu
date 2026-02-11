use util.nu [to-go-duration, gum-path]

export def "gum file" [
    path?: string
    --cursor: string
    --all(-a)
    --permissions(-p)
    --size(-s)
    --file
    --directory
    --show-help
    --header: string
    --height: int
    --timeout: duration
]: nothing -> string {
    let gum = (gum-path)
    mut args: list<string> = []
    if $cursor != null { $args = ($args | append [--cursor $cursor]) }
    if $all { $args = ($args | append "--all") }
    if $permissions { $args = ($args | append "--permissions") }
    if $size { $args = ($args | append "--size") }
    if $file { $args = ($args | append "--file") }
    if $directory { $args = ($args | append "--directory") }
    if $show_help { $args = ($args | append "--show-help") }
    if $header != null { $args = ($args | append [--header $header]) }
    if $height != null { $args = ($args | append [--height ($height | into string)]) }
    if $timeout != null { $args = ($args | append [--timeout ($timeout | to-go-duration)]) }
    if $path != null { $args = ($args | append $path) }

    let output = try {
        ^gum file ...$args
    } catch {
        error make --unspanned { msg: $"gum file failed with exit code ($env.LAST_EXIT_CODE)" }
    }
    $output | str trim --right --char "\n"
}
