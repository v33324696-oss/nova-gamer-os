@echo off
setlocal EnableExtensions
title NOVA GAMER OS - Build ISO
set "DISTRO=Debian"
echo ==========================================
echo        NOVA GAMER OS - INTEL EDITION
echo ==========================================
echo.

where wsl.exe >nul 2>nul
if errorlevel 1 goto :no_wsl

rem "wsl -l -q" gera saida UTF-16; por isso testamos a distro executando um comando.
wsl.exe -d %DISTRO% -- true >nul 2>nul
if errorlevel 1 goto :no_distro

set "WINPATH=%~dp0"
if "%WINPATH:~-1%"=="\" set "WINPATH=%WINPATH:~0,-1%"

set "LINUXPATH="
for /f "usebackq delims=" %%P in (`wsl.exe -d %DISTRO% -- wslpath -a "%WINPATH%"`) do set "LINUXPATH=%%P"
if not defined LINUXPATH goto :no_path

echo Pasta do projeto: %WINPATH%
echo O projeto sera copiado para o disco Linux do WSL (ext4), pois o live-build
echo nao funciona de forma confiavel em pastas do Windows (/mnt/c).
echo Sudo pode pedir a senha do usuario Debian. Precisa de internet e ~25 GB livres.
echo.

rem Remove CRLF do script de build (arquivos vindos do Windows quebram o bash).
wsl.exe -d %DISTRO% -- sed -i "s/\r//g" "%LINUXPATH%/scripts/wsl-build.sh"

wsl.exe -d %DISTRO% -- bash "%LINUXPATH%/scripts/wsl-build.sh"
if errorlevel 1 goto :failed

echo.
echo ISO pronta em:
echo %WINPATH%\build\NOVA-GAMER-OS-amd64.iso
echo Confira o hash em %WINPATH%\build\SHA256SUMS.txt antes de gravar o pendrive.
pause
endlocal
exit /b 0

:no_wsl
echo ERRO: WSL nao foi encontrado.
echo Abra o PowerShell como Administrador e execute:
echo   wsl --install -d Debian
echo Reinicie se solicitado, abra o Debian uma vez e conclua a configuracao.
pause
exit /b 1

:no_distro
echo ERRO: a distribuicao "%DISTRO%" do WSL nao esta instalada ou nao inicia.
echo Execute no PowerShell como Administrador:
echo   wsl --install -d Debian
echo Depois abra o Debian pelo menu Iniciar, configure o usuario e rode este BAT.
echo Se sua distro tem outro nome, edite a linha set "DISTRO=..." no inicio deste arquivo.
pause
exit /b 1

:no_path
echo ERRO: nao foi possivel localizar a pasta do projeto dentro do WSL.
pause
exit /b 1

:failed
echo.
echo A compilacao, a validacao ou o teste de boot falhou. NAO use essa ISO para instalar.
echo Os logs foram copiados para %WINPATH%\build (BUILD-LOG.txt, VALIDATE-LOG.txt, QEMU-LOG.txt).
echo Se falhar no debootstrap, use o workflow do GitHub Actions (veja README.md).
pause
exit /b 1
