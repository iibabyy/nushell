export def gum-path []: nothing -> string {
    let result = (which gum)
    if ($result | is-empty) {
        error make --unspanned {
            msg: "gum is not installed or not in PATH. Install: https://github.com/charmbracelet/gum"
        }
    }
    $result.0.path
}

export def to-go-duration []: duration -> string {
    let ns = $in | into int
    if $ns == 0 { return "0s" }

    mut remaining = $ns
    mut parts: list<string> = []

    let hours = $remaining // 3_600_000_000_000
    if $hours > 0 {
        $remaining = $remaining - ($hours * 3_600_000_000_000)
        $parts = ($parts | append $"($hours)h")
    }

    let minutes = $remaining // 60_000_000_000
    if $minutes > 0 {
        $remaining = $remaining - ($minutes * 60_000_000_000)
        $parts = ($parts | append $"($minutes)m")
    }

    let seconds = $remaining // 1_000_000_000
    if $seconds > 0 {
        $remaining = $remaining - ($seconds * 1_000_000_000)
        $parts = ($parts | append $"($seconds)s")
    }

    let millis = $remaining // 1_000_000
    if $millis > 0 {
        $remaining = $remaining - ($millis * 1_000_000)
        $parts = ($parts | append $"($millis)ms")
    }

    let micros = $remaining // 1_000
    if $micros > 0 {
        $remaining = $remaining - ($micros * 1_000)
        $parts = ($parts | append $"($micros)us")
    }

    if $remaining > 0 {
        $parts = ($parts | append $"($remaining)ns")
    }

    $parts | str join ""
}

# Check if an exit code indicates the process was interrupted by a signal
# Returns true for signal-based exits (Ctrl+C, SIGTERM, etc.)
export def is-interrupted [
    exit_code: int
]: nothing -> bool {
    # Exit codes for common signals:
    # 130 = SIGINT (Ctrl+C) = 128 + 2
    # 143 = SIGTERM = 128 + 15
    # Generally, exit codes 128-192 indicate signal termination
    $exit_code >= 128 and $exit_code < 192
}
