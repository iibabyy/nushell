# Remove all Docker containers, images, volumes, and system data
#
# This is a destructive operation that deletes ALL Docker resources.
# Returns a summary of what was deleted with statistics and any errors.
# Use --force to skip the confirmation prompt for automated scripts.
@example "Clean all Docker resources with confirmation" {deldocker}
@example "Clean without confirmation" {deldocker --force}
export def deldocker [
  --force(-f)        # Skip confirmation prompt
]: nothing -> nothing {
    # Check Docker is available
    let docker_check = (do { ^docker info } | complete)
    if $docker_check.exit_code != 0 {
        error make --unspanned { msg: "Docker is not running or not installed" }
    }

    # Confirmation prompt (skip if --force is used)
    if not $force {
        print -e $"(ansi red_bold)WARNING: This will delete ALL Docker containers, images, and volumes!(ansi reset)"
        let response = (input "Continue? (yes/no): ")
        if $response != "yes" {
            return "Operation cancelled"
        }
        print ""
    }

    # Collect all resources first
    let containers = (^docker ps -a -q | lines | where { not ($in | is-empty) })
    let images = (^docker images -a -q | lines | where { not ($in | is-empty) })
    let volumes = (
            ^docker volume ls --format json
            | lines
            | where { not ($in | is-empty) }
            | each { |line| try { $line | from json } catch { null } }
            | compact
            | get Name
    )

    # Containers
    if not ($containers | is-empty) {
        try {
            $containers | each { |id| ^docker stop $id }
            $containers | each { |id| ^docker rm $id }
            print $" - Removed ($containers | length) containers"
        } catch { |err|
            print -e $" - Failed to remove containers: ($err.msg)"
        }
    }

    # Images
    if not ($images | is-empty) {
        try {
            $images | each { |id| ^docker rmi $id }
            print $" - Removed ($images | length) images"
        } catch { |err|
            print -e $" - Failed to remove images: ($err.msg)"
        }
    }

    # Volumes
    if not ($volumes | is-empty) {
        try {
            $volumes | each { |vol| ^docker volume rm -f $vol }
            print $" - Removed ($volumes | length) volumes"
        } catch { |err|
            print -e $" - Failed to remove volumes: ($err.msg)"
        }
    }

    # System prune
    try {
        ^docker volume prune -f
        ^docker container prune -f
        ^docker system prune --all --force --volumes
    } catch { |err|
        print -e $" - Failed to prune system: ($err.msg)"
    }
}
