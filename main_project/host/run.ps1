param(
    [string]$Python = 'python',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ReceiverArgs
)
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    & $Python -B -m ads807 @ReceiverArgs
    if ($LASTEXITCODE -ne 0) { throw "Receiver exited with code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
