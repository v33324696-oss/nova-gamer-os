# NOVA GAMER OS — o que foi e o que NÃO foi testado

**Resumo: a ISO NÃO foi gerada e, portanto, nada da imagem foi testado.**

## Bloqueio
O ambiente de execução desta revisão não tem internet (DNS não resolve `deb.debian.org` nem `archive.ubuntu.com`) e não tem `live-build`, `debootstrap`, `xorriso`, `squashfs-tools` nem QEMU. Sem baixar pacotes Debian, não há como compilar. Tentei uma vez `curl` e `apt-get update` (ambos falharam por DNS) e parei, sem repetir tentativas.

## Verificado de fato (estático)
- Extração e leitura de todos os 17 arquivos do projeto original (35 entradas no ZIP).
- `bash -n` nos scripts `build-iso.sh`, `validate-iso.sh`, `qemu-boot-test.sh` e no hook: sintaxe válida.
- `.github/workflows/build-iso.yml` carrega como YAML válido.
- `ui/index.html` e `config/includes.chroot/usr/share/nova-ui/index.html` idênticos (cópia sincronizada).

## NÃO verificado
- Compilação `lb build` (a existência de cada pacote da lista no Debian 13 **não foi confirmada**; `gamemode`, `mangohud`, `debian-installer-launcher`, `firmware-iwlwifi`, `firmware-realtek`, `pipewire-audio`, `polkitd`, `pkexec` são os mais prováveis de exigir ajuste).
- Existência, tamanho e SHA-256 da ISO. Arquitetura amd64, boot BIOS/UEFI.
- Presença dos arquivos NOVA e do instalador dentro do squashfs/ISO.
- Boot em QEMU/VM e em hardware real; instalação no disco interno; drivers Intel; Wi-Fi.
- `BUILD-ISO-WINDOWS.bat` (nunca executado no Windows).
- O workflow do GitHub Actions nunca foi executado; pode precisar de ajustes na primeira rodada (por exemplo, espaço em disco, `lb config` em versões diferentes do live-build).

## O que o workflow validará quando rodar
`scripts/validate-iso.sh`: arquivo não vazio, `file`, `sha256sum`, entradas El Torito BIOS e UEFI, híbrida MBR/GPT, `/live/filesystem.squashfs`, `/install` (Debian Installer), arquivos NOVA e binários (chromium, sensors, intel_gpu_top, gamemoderun) dentro do squashfs, bits de execução.
`scripts/qemu-boot-test.sh`: boot BIOS e UEFI em QEMU com captura de tela. Isso mostra que o menu/desktop aparece; **não** prova que o instalador conclui nem que funciona em hardware físico.

## Limitações conhecidas
- Painel NOVA Control Center é demonstrativo (indicadores e botões não leem nem controlam o sistema); há faixa de aviso na tela.
- Sem overclock, sem MSI App Player, sem Wine/Waydroid; nenhuma compatibilidade com jogos Android foi testada.
- Secure Boot provavelmente precisa ficar desativado.
- Tamanho da ISO provavelmente acima de 1 GB (Chromium + XFCE + firmware).
- Repositórios não fixados em snapshot: builds em datas diferentes podem diferir.
