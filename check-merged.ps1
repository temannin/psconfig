# Prints merge status of the current branch's PR; prints nothing outside a git repo or on the default branch.
# Never blocks on the network: answers from a per-branch cache file and refreshes it in a hidden background process.
param([switch]$Refresh, [string]$CacheFile)

if ($Refresh) {
    $status = gh api 'repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=closed' --jq '[.[] | select(.merged_at != null)] | first | if . then "merged PR #" + (.number | tostring) else "not merged" end' 2>$null
    if ($status) { Set-Content -LiteralPath $CacheFile -Value $status -NoNewline }
    return
}

if (git rev-parse --is-inside-work-tree 2>$null) {
    $branch = git branch --show-current 2>$null
    $default = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
    if (-not $branch -or $branch -eq $default -or (-not $default -and $branch -in 'main', 'master')) { return }

    $dir = Join-Path $env:LOCALAPPDATA 'psconfig\cache'
    $key = (git rev-parse --show-toplevel 2>$null) + '|' + $branch
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($key))).Replace('-', '')
    $cache = Join-Path $dir $hash

    $item = Get-Item -LiteralPath $cache -ErrorAction SilentlyContinue
    if ($item) { Get-Content -LiteralPath $cache -Raw }

    # Merged is final, so only refresh unmerged/unknown branches (every 2 min).
    $merged = $item -and (Get-Content -LiteralPath $cache -Raw) -like 'merged*'
    if (-not $merged -and (-not $item -or ((Get-Date) - $item.LastWriteTime).TotalMinutes -gt 2)) {
        New-Item -ItemType Directory $dir -Force | Out-Null
        if ($item) { $item.LastWriteTime = Get-Date }  # debounce concurrent prompts
        Start-Process pwsh -WindowStyle Hidden -ArgumentList '-NoProfile', '-File', $PSCommandPath, '-Refresh', '-CacheFile', $cache
    }
}
