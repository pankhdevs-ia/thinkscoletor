@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0coletor.ps1"
echo.
echo Processo finalizado! Pressione qualquer tecla para fechar.
pause >nul