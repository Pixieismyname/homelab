@echo off
cd /d "%~dp0"
:loop
timeout /t 1800 /nobreak >nul
python fetch_videos.py
goto loop
