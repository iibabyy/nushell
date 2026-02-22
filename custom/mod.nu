use gum *

export use aliases.nu *
export use prompt.nu *
export use completions *
export use git *
export use docker.nu *

export-env {
    use prompt.nu
    use completions
    use hooks.nu
}
