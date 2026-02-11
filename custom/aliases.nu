export alias cfg = z ($env.HOME | path join ".config")
export alias c = clear
export alias res = exec nu

# Git Aliases
export alias g = git
export alias ga = git add
export alias gc = git commit -m
export alias gcl = git clone
export alias gp = git push

# Cargo Aliases
export alias cr = cargo run
export alias cb = cargo build
export alias cmod = cargo modules structure
export alias ct = cargo nextest run
export alias cw = cargo watch -q -c -x

# Antigravity Aliases
export alias anti = antigravity

# xclip
export alias clip = clipboard copy
export alias paste = clipboard paste
