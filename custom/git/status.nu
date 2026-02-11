# Fetch from remote and show status
export def gst []: nothing -> string {
    # git fetch --quiet
    git status
}
