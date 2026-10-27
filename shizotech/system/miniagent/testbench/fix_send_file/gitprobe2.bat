@echo off
cd /d C:\Users\neu\source\repos\shizoscript3\release\shizotech\system\miniagent
echo ===== dates
git log --format=fuller -1 c0813ff2
echo ---
git log --format=fuller -1 8ec10bd1
echo ---
git log --format=fuller -1 2832e37d
echo ===== tgbot module history (binaries)
git log --oneline -8 -- bundles/windows_x64/data/shizotech/modules/tgbot
echo ===== c0813ff2 telegram_router diff (outbound part only, first 120 lines)
git show c0813ff2 -- shizotech/system/miniagent/telegram_router.shio
echo ===== c0813ff2 router_api.md diff
git show c0813ff2 -- shizotech/system/miniagent/router_api.md
