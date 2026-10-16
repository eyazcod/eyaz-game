param([string]$Godot="godot")
$ErrorActionPreference="Stop"
Push-Location $PSScriptRoot
try {
    $compiler=Join-Path $env:WINDIR "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    if(Test-Path -LiteralPath $compiler){
        & $compiler /nologo /target:winexe /out:native/EYAZ-Discord.exe native/DiscordPresence.cs
        if($LASTEXITCODE -ne 0){throw "Discord companion build failed"}
    }
    New-Item -ItemType Directory -Path build -Force | Out-Null
    & $Godot --headless --editor --import
    if($LASTEXITCODE -ne 0){throw "Godot import failed"}
    & $Godot --headless --export-release "Windows Desktop" build/EYAZ-Game.exe
    if($LASTEXITCODE -ne 0){throw "Windows export failed"}
} finally {Pop-Location}
