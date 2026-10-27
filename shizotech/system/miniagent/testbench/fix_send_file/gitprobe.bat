@echo off
cd /d C:\Users\neu\source\repos\shizoscript3\release\shizotech\system\miniagent
echo ===== HEAD info
git log -1 --format="%h %ad %s" --date=iso
echo ===== commits touching miniagent, newest 12
git log --oneline -12 -- .
echo ===== 2832e37d files
git show --stat --oneline 2832e37d
echo ===== 2832e37d diff of file-event related lines
git show 2832e37d -- system/miniagent/shizonet_ai.shio system/miniagent/router_api.shio system/miniagent/telegram_router.shio system/miniagent/megamind.shio
echo ===== c0813ff2 stat
git show --stat --oneline c0813ff2
echo ===== 8ec10bd1 diff
git show 8ec10bd1
