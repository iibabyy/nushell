export def fish_completer [argv: list<string>] {
    try {
		fish --command $"complete '--do-complete=($argv | str replace --all "'" "\\'" | str join ' ')'"
			| from tsv --flexible --noheaders --no-infer
			| rename value description
			| update value {|row|
				let value = $row.value
				let need_quote = ['\' ',' '[' ']' '(' ')' ' ' '\t' "'" '"' "`"] | any {$in in $value}
				if ($need_quote and ($value | path exists)) {
					let expanded_path = if ($value starts-with ~) {$value | path expand --no-symlink} else {$value}
					$'"($expanded_path | str replace --all "\"" "\\\"")"'
				} else {$value}
			}
    } catch {
        return null
    }
}

export def custom_completer [argv: list<string>] {
    let lookup = (which $argv.0 | get 0?)
    let argv = if ($lookup | get definition?) != null {
        let definition = ($lookup | get definition | split row ' ' | where { $in != '' })
        $argv | skip 1 | prepend $definition
    } else {
        $argv
    }

	if ($argv | is-empty) {
		return null
	}

	let cmd_type = (which $argv.0 | get type?)
	if $cmd_type == "external" {
        let fish_completions = fish_completer $argv
		if $fish_completions == null or ($fish_completions | is-empty) {
			null
		} else {
			$fish_completions
		}
    } else {
        null
    }
}
