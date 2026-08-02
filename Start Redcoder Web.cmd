@echo off
title Redcoder (web)
cd /d "%~dp0"
where py >nul 2>nul && (py server.py & goto :eof)
python server.py
