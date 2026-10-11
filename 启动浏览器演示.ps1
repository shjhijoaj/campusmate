param([int]$Port = 4179)
$ErrorActionPreference = 'Stop'
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$portableNode = Join-Path $PSScriptRoot 'runtime\node.exe'
$bundledNode = Join-Path $PSScriptRoot 'runtime\node.exe'
$nodeExecutable = if (Test-Path -LiteralPath $portableNode) { $portableNode } elseif ($nodeCommand) { $nodeCommand.Source } elseif (Test-Path -LiteralPath $bundledNode) { $bundledNode } else { throw '需要安装 Node.js 22.16 或更新版本。' }
$env:CAMPUSMATE_PORT = $Port.ToString()
Write-Host "CampusMate 浏览器伴随演示：http://127.0.0.1:$Port"
Write-Host '按 Ctrl+C 停止服务。'
& $nodeExecutable (Join-Path $PSScriptRoot 'browser-demo\server.mjs')
