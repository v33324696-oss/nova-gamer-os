# NOVA GAMER OS — Intel Edition (starter project)

Perfil-alvo: Intel CPU, gráficos Intel integrados, 8 GB RAM.

Este repositório contém a configuração-fonte de uma ISO Debian Live personalizada, com entrada do Debian Installer para instalar o sistema no disco interno. Este repositório ainda NÃO contém uma ISO pronta: a imagem é compilada em Linux com internet (por exemplo, pelo workflow do GitHub Actions deste projeto).

## O que o projeto inclui
- Debian Live amd64 com desktop XFCE.
- Chromium como navegador.
- NetworkManager para Wi-Fi/Ethernet.
- Ferramentas de monitoramento Intel: `intel-gpu-tools`, `lm-sensors`, `thermald`.
- GameMode e MangoHud (pacotes do Debian 13; se algum sumir do repositório, o build falha e a lista deve ser ajustada).
- Script de perfil de desempenho conservador usando `powerprofilesctl` quando disponível.
- Atalhos e painel simples de status.
- Debian Installer incluído no menu de inicialização e iniciador para abrir o instalador a partir da sessão live.

## Overclock e MSI App Player

- O Game Mode oferece perfis de energia suportados e monitoramento; não altera multiplicador, tensão ou clocks manualmente.
- Overclock Intel depende do modelo exato, chipset, BIOS e refrigeração. A GPU integrada não tem controle universal de overclock no Linux. Não incluí ajustes genéricos que possam causar instabilidade ou superaquecimento.
- MSI App Player é um aplicativo Windows sem versão Linux oficial. Uma VM Windows exige licença e virtualização compatível; com 8 GB de RAM e GPU integrada, desempenho e compatibilidade não são garantidos.

## Limitações importantes
- **MSI App Player é um produto Windows e não tem versão Linux oficial.** Não está incluído e não há garantia de execução por Wine/virtualização. Para usá-lo, mantenha Windows em dual boot ou use outro dispositivo Windows compatível.
- Roblox e outros jogos com anti-cheat/serviços específicos podem não funcionar no Wine/Proton.
- Intel integrada usa memória compartilhada e o desempenho depende muito do modelo exato do processador e do suporte de drivers.
- O painel não faz overclock de tensão nem força clocks fora das especificações. Em Intel integrada, overclock geralmente não é suportado; ajustes indevidos podem causar instabilidade, superaquecimento ou danos.
- A meta de ISO de 1 GB é experimental, não garantida. Chromium, XFCE, firmware e ferramentas de jogo podem ultrapassar esse limite. Para reduzir tamanho, retire componentes opcionais; não remova drivers de rede ou firmware essenciais.
- A imagem não inclui jogos, firmware proprietário não redistribuível, Windows, MSI App Player ou chaves/licenças.


## NOVA Control Center (interface integrada)

- A interface web do projeto está instalada em `/usr/share/nova-ui/index.html`.
- O atalho **NOVA Control Center** aparece no menu de aplicativos e na área de trabalho do usuário live.
- O comando `/usr/local/bin/nova-ui` abre o painel em uma janela de aplicativo do Chromium (com fallback para o navegador padrão).
- O painel atual é uma camada visual integrada. Indicadores de CPU/RAM/GPU e controles de energia ainda são demonstrativos; eles não leem sensores nem alteram configurações reais nesta versão.
- Os botões de navegação e seleção de perfil são interações locais da interface, não comandos do sistema.

Para abrir manualmente: execute `nova-ui` em um terminal ou escolha **NOVA Control Center** no menu.

## Construir a ISO no Windows

1. No PowerShell como Administrador, execute `wsl --install -d Debian`.
2. Reinicie se solicitado, abra Debian pelo menu Iniciar e crie o usuário Linux.
3. Extraia este projeto para uma pasta local.
4. Dê duplo clique em `BUILD-ISO-WINDOWS.bat`. Ele instala as ferramentas no Debian WSL e inicia a compilação. O `sudo` pode pedir a senha do usuário Debian.
5. A ISO será salva em `build\NOVA-GAMER-OS-amd64.iso`, junto com `SHA256SUMS.txt`.

O BAT automatiza a construção depois que WSL/Debian está instalado e configurado. A primeira instalação pode exigir administrador e reinicialização.

## Construir a ISO manualmente
Use uma máquina Debian amd64 limpa, com internet e pelo menos 25 GB livres. Para passar pelos mesmos testes do GitHub Actions, instale também QEMU e OVMF.

```bash
sudo apt update
sudo apt install -y live-build debootstrap xorriso squashfs-tools qemu-system-x86 ovmf
cd NOVA-GAMER-OS
sudo chmod +x scripts/*.sh config/hooks/live/*.hook.chroot
sudo ./scripts/build-iso.sh
sudo ./scripts/validate-iso.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/VALIDATE-LOG.txt
sudo env BOOT_WAIT=240 ./scripts/qemu-boot-test.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/QEMU-LOG.txt
```

A ISO ficará em `build/NOVA-GAMER-OS-amd64.iso`; o hash em `build/SHA256SUMS.txt` e os logs de compilação, validação e boot na pasta `build/`. Só use a ISO para testar a instalação quando a validação e os dois testes de boot terminarem sem falhas.

Teste primeiro em uma VM. Para hardware físico, grave a ISO em um USB usando Rufus ou balenaEtcher. Faça backup antes de instalar qualquer sistema.

## Teclas e uso
- Inicie a sessão live e conecte-se à rede pelo ícone NetworkManager.
- Abra Chromium pelo menu Internet.
- Use o atalho **NOVA Game Mode** para ativar o perfil de desempenho suportado.
- Use **NOVA Status** para ver informações básicas de CPU/GPU/temperatura.

## Instalar no computador

A compilação habilita `--debian-installer live` e inclui `debian-installer-launcher`. A mídia deve oferecer o instalador Debian no menu de boot e um iniciador na sessão Live. A presença dos arquivos não prova, por si só, que a instalação terminou corretamente: primeiro conclua uma instalação em VM com disco virtual vazio e reinicie essa VM sem a ISO.

**Atenção:** instalar pode apagar os dados do disco escolhido. Faça backup antes, confirme cuidadosamente o disco de destino e não prossiga se não tiver certeza. Secure Boot deve ficar desativado nesta versão. Veja `docs/README-INSTALACAO.md` para a sequência segura.


## Construir a ISO pelo GitHub Actions (recomendado)

1. Crie um repositório no GitHub e envie o conteúdo da pasta `NOVA-GAMER-OS/` (a pasta `.github/` precisa ficar na raiz do repositório).
2. Abra a aba **Actions** > **Build NOVA GAMER OS ISO** > **Run workflow**.
3. O job compila dentro de um container `debian:trixie`, valida a estrutura e o cabeçalho do kernel (`scripts/validate-iso.sh`) e exige que o sistema Live chegue ao LightDM em QEMU nos modos BIOS e UEFI (`scripts/qemu-boot-test.sh`). Um teste de boot reprovado deixa o workflow vermelho; artefatos/logs são preservados para diagnóstico.
4. Baixe a ISO e `SHA256SUMS.txt` da mesma execução aprovada. Leia `docs/README-TESTES.md` e `docs/README-INSTALACAO.md`. O teste automatizado não substitui uma instalação completa em VM nem o teste no hardware específico.

## Mudanças nesta revisão
Veja `docs/CHANGELOG-CORRECOES.md`.
