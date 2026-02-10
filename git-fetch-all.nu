#!/usr/bin/env nu

# Git fetch all repositories in the current directory
ls | where type == dir | where { |dir| $dir.name | path join ".git" | path exists } | par-each { |dir|
  cd $dir.name
  try {
    git fetch --all | ignore
    print $"($dir.name) - Ok"
  } catch { |err|
    print $"($dir.name) - ($err.msg)"
  }
}

null
