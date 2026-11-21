# NOVA GAMER OS — gravar, testar e instalar

> **Importante:** não instale no disco interno apenas porque o arquivo ISO foi criado. Primeiro exija que o GitHub Actions termine verde incluindo `VALIDATE-LOG.txt` e `QEMU-LOG.txt`. Depois teste a instalação em uma máquina virtual com disco virtual vazio.

## 1. Conferir a ISO

1. Baixe o artefato `NOVA-GAMER-OS` da execução aprovada do GitHub Actions e extraia o ZIP.
2. Confirme o SHA-256 comparando a ISO com `SHA256SUMS.txt`.
3. Não use uma ISO de uma execução anterior nem misture ISO e checksum de execuções diferentes.

No PowerShell:

```powershell
Get-FileHash .\NOVA-GAMER-OS-amd64.iso -Algorithm SHA256
```

O valor precisa ser idêntico ao da linha correspondente em `SHA256SUMS.txt`.

## 2. Criar o pendrive

- Use um pendrive de 8 GB ou mais. O conteúdo dele será apagado.
- No Rufus, selecione a ISO e o pendrive correto. Use GPT para UEFI; use MBR apenas para computadores que realmente iniciam em Legacy/BIOS. Quando o Rufus perguntar, use o modo recomendado para a imagem (normalmente DD para imagem híbrida).
- Confira duas vezes o dispositivo escolhido antes de iniciar a gravação.

## 3. Testar no notebook sem instalar

1. Desligue o notebook e abra o menu de boot (a tecla depende do modelo ASUS; em muitos modelos é Esc para menu e F2 para BIOS).
2. Escolha a entrada do pendrive que começa com `UEFI`.
3. Desative Secure Boot na BIOS/UEFI, salve e tente iniciar novamente. Esta versão não inclui uma cadeia de boot assinada para Secure Boot.
4. No menu da NOVA, escolha **Live** (não escolha Install/Graphical Install ainda).
5. Aguarde o desktop. Teste teclado, touchpad, vídeo, áudio e Wi-Fi. Se aparecer `invalid magic number`, `you need to load the kernel first`, tela preta ou reinicialização, pare: não inicie o instalador.

## 4. Testar a instalação em uma VM

Antes de instalar no computador real, inicialize a mesma ISO em QEMU/VirtualBox/VMware com um disco virtual vazio. Escolha o instalador Debian do menu ou o iniciador **Debian Installer** dentro da sessão Live e conclua a instalação no disco virtual. Reinicie a VM sem a ISO e confirme que o sistema instalado inicia.

A verificação automatizada do repositório testa o boot do sistema Live e a presença dos arquivos do Debian Installer. Ela não finge que uma instalação completa ocorreu. A instalação real ainda precisa ser verificada neste teste manual em VM.

## 5. Instalar no disco interno (somente depois dos testes)

O instalador pode apagar ou reparticionar o disco selecionado. Faça backup de seus arquivos e confirme o nome, o tamanho e o modelo do disco de destino. Se houver qualquer dúvida sobre qual disco será formatado, cancele.

Não selecione o disco que contém seu Windows caso queira preservá-lo. Não há garantia automática de dual boot nesta configuração.

## 6. Limitações

- Secure Boot deve ficar desativado nesta versão.
- Compatibilidade de rede sem fio, áudio, touchpad, vídeo, suspensão e brilho depende do modelo do notebook.
- O painel NOVA Control Center ainda é demonstrativo; não faz overclock nem controla clocks/voltagens.
- MSI App Player é software Windows e não está incluído.
