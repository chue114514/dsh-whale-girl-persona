<#
.SYNOPSIS
  dsh-whale-persona 发版一条龙：改版本号 → 打 tarball → 自检 → 打印上传清单。

.DESCRIPTION
  纯文本正则改 package.json / README.md，不重新序列化 JSON，格式与键顺序原样保留。

.PARAMETER Bump
  不填 = 只重新打包当前版本；patch / minor / major = 递增；也可直接给 x.y.z。

.PARAMETER GithubUser
  把 package.json 与 README.md 里的 YOUR_GITHUB_USER 换成你的 GitHub 用户名。

.PARAMETER DryRun
  只打印将要做什么，不落盘、不打包。

.EXAMPLE
  .\release.ps1 -GithubUser dsh-fan
.EXAMPLE
  .\release.ps1 -Bump patch
.EXAMPLE
  .\release.ps1 -Bump 0.2.0 -DryRun
#>
[CmdletBinding()]
param(
  [string]$Bump = '',
  [string]$GithubUser = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root      = $PSScriptRoot
$pkgPath   = Join-Path $root 'package.json'
$readmePath = Join-Path $root 'README.md'
$placeholder = 'YOUR_GITHUB_USER'

# Windows PowerShell 5.1 没有 utf8NoBOM 编码选项，用 .NET 直接写无 BOM UTF-8。
function Write-TextNoBom {
  param([string]$Path, [string]$Text)
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-NextVersion {
  param([string]$Current, [string]$Request)
  if ([string]::IsNullOrWhiteSpace($Request)) { return $Current }
  if ($Request -match '^\d+\.\d+\.\d+(-[\w.]+)?$') { return $Request }
  $parts = $Current.Split('.')
  $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
  switch ($Request.ToLowerInvariant()) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
    default { throw "Bump 只接受 patch / minor / major / x.y.z，收到：$Request" }
  }
  return "$major.$minor.$patch"
}

# ---- 1. 读当前版本 ---------------------------------------------------------
$pkgText = Get-Content -Raw -Path $pkgPath
$verMatch = [regex]::Match($pkgText, '"version"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"')
if (-not $verMatch.Success) { throw "在 package.json 里找不到 version 字段" }
$currentVersion = $verMatch.Groups[1].Value
$nameMatch = [regex]::Match($pkgText, '"name"\s*:\s*"([^"]+)"')
$pkgName = $nameMatch.Groups[1].Value

# ---- 2. 计算目标版本 -------------------------------------------------------
$newVersion = Get-NextVersion -Current $currentVersion -Request $Bump
$tarballName = "$pkgName-$newVersion.tgz"
$tarballPath = Join-Path $root $tarballName

Write-Host ""
Write-Host "  $pkgName" -ForegroundColor Cyan
Write-Host "  版本：$currentVersion  ->  $newVersion" -ForegroundColor Cyan
if ($GithubUser) { Write-Host "  占位符 -> $GithubUser" -ForegroundColor Cyan }
Write-Host ""

if ($DryRun) {
  Write-Host "[DryRun] 会写入：$pkgPath" -ForegroundColor Yellow
  Write-Host "[DryRun] 会写入：$readmePath（若含 $placeholder）" -ForegroundColor Yellow
  Write-Host "[DryRun] 会产出：$tarballName" -ForegroundColor Yellow
  return
}

# ---- 3. 改版本号 -----------------------------------------------------------
if ($newVersion -ne $currentVersion) {
  $pkgText = $pkgText -replace '("version"\s*:\s*")[0-9]+\.[0-9]+\.[0-9]+(")', ('${1}' + $newVersion + '${2}')
  Write-Host "  已改版本号" -ForegroundColor Green
}

# ---- 4. 替换 GitHub 占位符 -------------------------------------------------
if ($GithubUser) {
  if ($pkgText -match [regex]::Escape($placeholder)) {
    $pkgText = $pkgText -replace [regex]::Escape($placeholder), $GithubUser
    Write-Host "  package.json 占位符已替换" -ForegroundColor Green
  }
  $readmeText = Get-Content -Raw -Path $readmePath
  if ($readmeText -match [regex]::Escape($placeholder)) {
    $readmeText = $readmeText -replace [regex]::Escape($placeholder), $GithubUser
    Write-TextNoBom -Path $readmePath -Text $readmeText
    Write-Host "  README.md 占位符已替换" -ForegroundColor Green
  }
}

Write-TextNoBom -Path $pkgPath -Text $pkgText

# ---- 5. 清理旧包并打包 -----------------------------------------------------
Get-ChildItem -Path $root -Filter '*.tgz' -File | ForEach-Object {
  Remove-Item $_.FullName -Force
  Write-Host "  已清理旧包：$($_.Name)" -ForegroundColor DarkGray
}

$deps = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies'
$nodeExe = Join-Path $deps 'node\bin\node.exe'
$pnpmCjs = Join-Path $deps 'pnpm\bin\pnpm.cjs'

Push-Location $root
try {
  if ((Test-Path $nodeExe) -and (Test-Path $pnpmCjs)) {
    $packOutput = & $nodeExe $pnpmCjs pack --pack-destination $root 2>&1
  } else {
    Write-Host "  未找到内置 node/pnpm，改用 PATH 上的 pnpm" -ForegroundColor Yellow
    $packOutput = & pnpm pack --pack-destination $root 2>&1
  }
} finally {
  Pop-Location
}

if ($LASTEXITCODE -ne 0) { throw "pnpm pack 失败：`n$($packOutput -join "`n")" }

# ---- 6. 自检 ---------------------------------------------------------------
if (-not (Test-Path $tarballPath)) { throw "打包结束但没找到 $tarballName" }

$entries = & tar -tzf $tarballPath
$required = @('package/package.json', 'package/index.js', 'package/cordis.patch.yml')
$missing = $required | Where-Object { $entries -notcontains $_ }
if ($missing) { throw "tarball 缺少必需文件：$($missing -join ', ')" }

$sizeKb = [math]::Round((Get-Item $tarballPath).Length / 1KB, 1)

# ---- 7. 打印结果 -----------------------------------------------------------
Write-Host ""
Write-Host "  ✓ $tarballName  ($sizeKb KB, $($entries.Count) 个条目)" -ForegroundColor Green
$entries | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }

$repoField = [regex]::Match($pkgText, '"url"\s*:\s*"git\+([^"]+)"').Groups[1].Value
$stillPlaceholder = $pkgText -match [regex]::Escape($placeholder) -or
                    (Get-Content -Raw $readmePath) -match [regex]::Escape($placeholder)

Write-Host ""
Write-Host "  上传清单" -ForegroundColor Cyan
Write-Host "    1) 仓库：$repoField"
Write-Host "    2) Release 附件：$tarballName"
Write-Host "    3) npm：npm publish    （先 npm view $pkgName 查重名）"
Write-Host "    4) 上架：向 awesome-dsh-plugin 提 PR"
if ($stillPlaceholder) {
  Write-Host ""
  Write-Host "  ! 还有 $placeholder 没换，先跑：.\release.ps1 -GithubUser <你的用户名>" -ForegroundColor Yellow
}
Write-Host ""
