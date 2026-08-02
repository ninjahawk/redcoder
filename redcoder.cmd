@echo off
rem Redcoder CLI launcher — runs the offline coding agent in the current directory.
rem %~dp0 = the folder this .cmd lives in, so it works no matter where it's moved.
where py >nul 2>nul && (py "%~dp0redcoder.py" %* & goto :eof)
python "%~dp0redcoder.py" %*
