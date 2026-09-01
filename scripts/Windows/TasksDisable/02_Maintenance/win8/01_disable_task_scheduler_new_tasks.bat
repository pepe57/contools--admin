@echo off

rem Description:
rem   Script prevents the Task Scheduler of a new task creation for everyone.

setlocal

call "%%~dp0..\__init__\__init__.bat" || exit /b

call "%%CONTOOLS_ADMIN_PROJECT_ROOT%%/scripts/Windows/TaskSched/disable_tasksched_new_tasks.bat" %%*
