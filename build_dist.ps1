# build_dist.ps1 — Package GuildPvPLadder for distribution.
# Output: dist\GuildPvPLadder\  and symlinked into WoW AddOns folder.

$AddonName  = "GuildPvPLadder"
$DistDir    = "dist\$AddonName"
$WowAddOns  = "E:\World of Warcraft\_retail_\Interface\AddOns"
$WowLink    = "$WowAddOns\$AddonName"

# Clean previous build
if (Test-Path "dist") {
    Remove-Item -Recurse -Force "dist"
}

# Create directory structure
New-Item -ItemType Directory -Force "$DistDir\Core"   | Out-Null
New-Item -ItemType Directory -Force "$DistDir\Locale" | Out-Null
New-Item -ItemType Directory -Force "$DistDir\UI"     | Out-Null

# Root files
Copy-Item "$AddonName.toc" "$DistDir\"
Copy-Item "$AddonName.lua" "$DistDir\"

# Core module
Copy-Item "Core\GuildManager.lua"       "$DistDir\Core\"
Copy-Item "Core\RatingTracker.lua"      "$DistDir\Core\"
Copy-Item "Core\AchievementTracker.lua" "$DistDir\Core\"
Copy-Item "Core\DataCollector.lua"      "$DistDir\Core\"

# UI module
Copy-Item "UI\MainFrame.lua" "$DistDir\UI\"
Copy-Item "UI\MainFrame.xml" "$DistDir\UI\"
Copy-Item "UI\LadderRow.lua" "$DistDir\UI\"
Copy-Item "UI\Tooltips.lua"  "$DistDir\UI\"
Copy-Item "UI\Minimap.lua"   "$DistDir\UI\"

# Locale
Copy-Item "Locale\enUS.lua" "$DistDir\Locale\"

Write-Host ""
Write-Host "Build complete: $DistDir\" -ForegroundColor Green
Write-Host ""
Write-Host "Files included:" -ForegroundColor Yellow
Get-ChildItem -Recurse "$DistDir" -File | ForEach-Object {
    Write-Host "  $($_.FullName.Replace((Resolve-Path $DistDir).Path + '\', ''))"
}

# Symlink into WoW AddOns folder
Write-Host ""
if (-not (Test-Path $WowAddOns)) {
    Write-Host "WoW AddOns folder not found: $WowAddOns" -ForegroundColor Red
    Write-Host "Skipping symlink creation." -ForegroundColor Yellow
} else {
    # Remove existing symlink or folder if present
    if (Test-Path $WowLink) {
        Remove-Item -Recurse -Force $WowLink
    }

    $AbsDistDir = (Resolve-Path $DistDir).Path
    try {
        New-Item -ItemType SymbolicLink -Path $WowLink -Target $AbsDistDir | Out-Null
        Write-Host "Symlink created:" -ForegroundColor Green
        Write-Host "  $WowLink  ->  $AbsDistDir" -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to create symlink: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Tip: Run PowerShell as Administrator, or enable Developer Mode:" -ForegroundColor Yellow
        Write-Host "  Settings -> System -> For Developers -> Developer Mode: On" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done. Use /reload in WoW to pick up changes." -ForegroundColor Green
