$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$pluginsPath = Join-Path $root "plugins.json"
$outputPath = Join-Path $root "repo.json"

$plugins = Get-Content $pluginsPath -Raw | ConvertFrom-Json

$headers = @{
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "GerullasPluginsRepoUpdater"
}

if ($env:GITHUB_TOKEN) {
    $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    $headers["X-GitHub-Api-Version"] = "2022-11-28"
}

$entries = @(
    foreach ($plugin in $plugins) {
        $releaseUrl = "https://api.github.com/repos/$($plugin.repo)/releases/latest"
        Write-Host "Checking $($plugin.repo)..."

        $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -Method Get
        $asset = @($release.assets) | Where-Object { $_.name -eq $plugin.asset } | Select-Object -First 1

        if (-not $asset) {
            throw "Release $($release.tag_name) in $($plugin.repo) does not contain asset '$($plugin.asset)'."
        }

        $version = [string]$release.tag_name
        if ($version.StartsWith("v", [StringComparison]::OrdinalIgnoreCase)) {
            $version = $version.Substring(1)
        }

        $entry = [ordered]@{
            Author = [string]$plugin.author
            Name = [string]$plugin.name
            InternalName = [string]$plugin.internal_name
            AssemblyVersion = $version
            TestingAssemblyVersion = $version
            RepoUrl = [string]$plugin.repo_url
            ApplicableVersion = [string]$plugin.applicable_version
            DalamudApiLevel = [int]$plugin.dalamud_api_level
            Punchline = [string]$plugin.punchline
            Description = [string]$plugin.description
            DownloadLinkInstall = [string]$asset.browser_download_url
            DownloadLinkUpdate = [string]$asset.browser_download_url
            DownloadLinkTesting = [string]$asset.browser_download_url
            DownloadCount = [int]$asset.download_count
            LastUpdate = [DateTimeOffset]::Parse($release.published_at).ToUnixTimeSeconds()
            Tags = @($plugin.tags)
        }

        if ($plugin.icon_url) {
            $entry.IconUrl = [string]$plugin.icon_url
        }

        [pscustomobject]$entry
    }
)

$json = $entries | ConvertTo-Json -Depth 20
Set-Content -Path $outputPath -Value ($json + "`n") -Encoding UTF8

# Validate JSON before committing.
$null = Get-Content $outputPath -Raw | ConvertFrom-Json

Write-Host "Updated repo.json with $($entries.Count) plugin(s)."