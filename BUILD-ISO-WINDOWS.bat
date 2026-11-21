@echo off
setlocal EnableExtensions
title NOVA GAMER OS - Build ISO
echo ==========================================
echo        NOVA GAMER OS - INTEL EDITION
echo ==========================================
echo.
where wsl.exe >nul 2>nul
if errorlevel 1 (
  echo ERRO: WSL nao foi encontrado.
  echo Abra PowerShell como Administrador e execute:
  echo   wsl --install -d Debian
  echo Reinicie se solicitado, abra Debian uma vez e conclua a configuracao.
  pause
  exit /b 1
)
rem NOTA: "wsl -l -q" gera saida UTF-16 e o findstr nao a reconhece; testamos executando um comando.
wsl.exe -d Debian -- true >nul 2>nul
if errorlevel 1 (
  echo ERRO: Debian no WSL nao esta instalado ou nao inicia.
  echo Execute no PowerShell como Administrador:
  echo   wsl --install -d Debian
  echo Depois abra Debian pelo menu Iniciar, configure o usuario e rode este BAT.
  pause
  exit /b 1
)
set "WINPATH=%~dp0"
for %%I in ("%WINPATH%.") do set "WINPATH=%%~fI"
set "LINUXPATH="
for /f "usebackq delims=" %%P in (`wsl.exe -d Debian -- wslpath -a "%WINPATH%"`) do set "LINUXPATH=%%P"
if not defined LINUXPATH (
  echo ERRO: nao foi possivel localizar a pasta no WSL.
  pause
  exit /b 1
)
echo Instalando ferramentas e construindo a ISO.
echo O projeto sera copiado para o disco Linux do WSL (ext4), pois o live-build
echo nao funciona de forma confiavel em pastas do Windows (/mnt/c).
echo Sudo pode solicitar a senha do usuario Debian. E necessario internet e ~25 GB livres.
echo.
wsl.exe -d Debian -- bash -lc "set -euo pipefail; sudo apt-get update && sudo apt-get install -y live-build debootstrap xorriso squashfs-tools rsync qemu-system-x86 ovmf && rm -rf \"$HOME/nova-build\" && mkdir -p \"$HOME/nova-build\" && rsync -a --exclude build --exclude chroot --exclude binary --exclude cache '%LINUXPATH%/' \"$HOME/nova-build/\" && cd \"$HOME/nova-build\" && chmod +x scripts/*.sh config/hooks/live/*.hook.chroot && sudo ./scripts/build-iso.sh && sudo ./scripts/validate-iso.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/VALIDATE-LOG.txt && sudo env BOOT_WAIT=240 ./scripts/qemu-boot-test.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/QEMU-LOG.txt && mkdir -p '%LINUXPATH%/build' && cp -f build/NOVA-GAMER-OS-amd64.iso build/SHA256SUMS.txt build/BUILD-LOG.txt build/VALIDATE-LOG.txt build/QEMU-LOG.txt '%LINUXPATH%/build/'"
if errorlevel 1 (
  echo.
  echo A compilacao, validacao ou teste de boot falhou. Nao use essa ISO para instalar.
  echo Observacao: o Debian do WSL precisa ser recente o bastante para criar "trixie".
  echo Se falhar na etapa do debootstrap, use o workflow do GitHub Actions (veja README.md).
  pause
  exit /b 1
)
echo.
echo ISO pronta em:
echo %WINPATH%build\NOVA-GAMER-OS-amd64.iso
pause
endlocal
