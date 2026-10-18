powershell -NoProfile -ExecutionPolicy Bypass -File testbench/dedup_task_events/grep.ps1 -Pattern "on_task_finished|_task_finish_cb|on_notify|_notify_cb|add_task" -Path "*.shio"
