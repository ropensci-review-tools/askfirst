# install.ps1 -- PowerShell bootstrap for askfirst's agent hooks installer.
#
# Downloads agent-hooks/install-agent-hooks.sh from GitHub and runs it
# through a located `bash` (Git Bash, falling back to WSL). Not a
# reimplementation of installer logic -- see agent-hooks/install-agent-hooks.sh
# for the canonical implementation, and install.sh for the bash equivalent
# of this wrapper.
#
# Usage:
#   irm https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/install.ps1))) -tool claude

param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$installerUrl = "https://raw.githubusercontent.com/ropensci-review-tools/askfirst/main/agent-hooks/install-agent-hooks.sh"
$tempScript = New-TemporaryFile

try {
  Invoke-WebRequest -Uri $installerUrl -OutFile $tempScript.FullName -UseBasicParsing

  $bash = Get-Command bash -ErrorAction SilentlyContinue
  if ($bash) {
    Write-Host "Found bash at $($bash.Source) (e.g. Git Bash) -- running the installer through it."
    & $bash.Source $tempScript.FullName @Args
    exit $LASTEXITCODE
  }

  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  if ($wsl) {
    Write-Host "No native bash found; found WSL -- running the installer through 'wsl bash'."
    $wslPath = & wsl wslpath -u ($tempScript.FullName -replace '\\', '/')
    & wsl bash $wslPath @Args
    exit $LASTEXITCODE
  }

  Write-Error "askfirst's agent-hooks installer is a bash script, and no bash executable was found on this machine. Install one of the following, then re-run this script: Git Bash (https://git-scm.com/downloads) or WSL (https://learn.microsoft.com/windows/wsl/install)."
  exit 1
} finally {
  Remove-Item -Path $tempScript.FullName -ErrorAction SilentlyContinue
}
