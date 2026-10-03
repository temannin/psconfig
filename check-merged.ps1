# Prints merge status of the current branch's PR; prints nothing outside a git repo or on the default branch.
if (git rev-parse --is-inside-work-tree 2>$null) {
    $branch = git branch --show-current 2>$null
    $default = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
    if (-not $branch -or $branch -eq $default -or (-not $default -and $branch -in 'main', 'master')) { return }

    gh api 'repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=closed' --jq '[.[] | select(.merged_at != null)] | first | if . then "merged PR #" + (.number | tostring) else "not merged" end' 2>$null
}
