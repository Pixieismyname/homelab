@echo off
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo Python not found. Install it from https://python.org and re-run this.
  pause
  exit /b 1
)

python -c "import yaml" >nul 2>nul
if errorlevel 1 (
  echo Installing pyyaml...
  python -m pip install --quiet pyyaml
)

echo Fetching latest videos...
python fetch_videos.py

start "boredgamertracker-fetcher" /min fetcher_loop.bat

echo Starting local server on http://localhost:8000 ...
start "" http://localhost:8000/comment-tracker.html
python api_server.py
