$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName   = 'scottimizer'
  unzipLocation = $toolsDir
  url           = 'https://github.com/SCOTTYinCntrl/Scottimizer/releases/download/v2.1.3/Scottimizer-Advanced.zip'
  checksum      = 'A980FF14744EB98842AF55E35740C20B8A4D8C54A40C867C2FDDE6E3CD90BBC9'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Scottimizer is a GUI app; expose it on PATH and the Start Menu.
$exe = Join-Path $toolsDir 'Scottimizer.exe'
if (Test-Path -LiteralPath $exe) {
  Install-BinFile -Name 'scottimizer' -Path $exe
  $menu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
  if (Test-Path -LiteralPath $menu) {
    Install-ChocolateyShortcut -ShortcutFilePath (Join-Path $menu 'Scottimizer.lnk') `
      -TargetPath $exe -WorkingDirectory $toolsDir -IconLocation $exe
  }
}