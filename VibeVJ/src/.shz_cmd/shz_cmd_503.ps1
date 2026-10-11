cmd /c "..\x64\Release\shzscript_x64.exe --check menu\timeline\timeline.shio < nul 1> ..\.megamind\issues_wave_2026_10_10\F-TL\check_head_out.txt 2> ..\.megamind\issues_wave_2026_10_10\F-TL\check_head_err.txt"
"EXIT=$LASTEXITCODE"
"--- stdout ---"
Get-Content ..\.megamind\issues_wave_2026_10_10\F-TL\check_head_out.txt
"--- stderr ---"
Get-Content ..\.megamind\issues_wave_2026_10_10\F-TL\check_head_err.txt
