# NOVA GAMER OS — como gravar a ISO e instalar

> **Estado atual:** a ISO ainda **não foi gerada**. Primeiro compile-a (ver `README.md` do projeto, seção "GitHub Actions"). Estes passos valem depois que você tiver `NOVA-GAMER-OS-amd64.iso`.

## 0. Antes de tudo
- Confira o hash: `sha256sum NOVA-GAMER-OS-amd64.iso` (Linux) ou `Get-FileHash .\NOVA-GAMER-OS-amd64.iso -Algorithm SHA256` (PowerShell) e compare com `SHA256SUMS.txt`.
- Use um pendrive de **8 GB ou mais**. **Tudo nele será apagado.**
- Faça backup dos dados do computador. Teste primeiro no modo Live, sem instalar.

## 1. Gravar no pendrive
**Rufus (Windows)**
1. Abra o Rufus, escolha o pendrive em *Dispositivo* (confira a letra e o tamanho).
2. *SELECIONAR* → escolha a ISO.
3. Se perguntar, escolha o modo **Imagem DD** (ou "ISO" se o Rufus recomendar). Esquema de partição: **GPT** para UEFI ou **MBR** para BIOS/Legacy.
4. *INICIAR* e aguarde.

**balenaEtcher (Windows/Mac/Linux)**: *Flash from file* → ISO → *Select target* (pendrive) → *Flash!*

## 2. Iniciar pelo pendrive
1. Com o PC desligado, ligue e pressione a tecla do menu de boot (comuns: F12, F10, F9, Esc ou F8, conforme o fabricante).
2. Escolha o pendrive. Se aparecerem duas entradas, a com "UEFI" serve para boot UEFI.
3. No menu do NOVA GAMER OS, escolha o modo **Live** para testar.
4. Se não iniciar: desative *Secure Boot* na BIOS (a imagem não é assinada para Secure Boot) e tente de novo.

## 3. Instalar no disco interno
O projeto usa o **Debian Installer** (entrada "Install"/"Graphical Install" no menu de boot) e o atalho `debian-installer-launcher` dentro da sessão Live.
- **Atenção:** o instalador pode apagar o disco escolhido. Confira o disco de destino com cuidado.
- O modo Live **não** é uma instalação permanente: alterações se perdem ao reiniciar.
- Se o instalador não aparecer ou não funcionar (isso ainda não foi testado), o modo Live continua utilizável, mas **não há alternativa de instalação validada**; relate o erro e a imagem pode ser ajustada (por ex., trocar para Calamares).

## 4. Limitações
- Sem MSI App Player (é Windows), sem Wine, sem Waydroid; nenhuma compatibilidade com Free Fire ou emuladores foi testada ou prometida.
- O painel NOVA Control Center é demonstrativo; não faz overclock e não altera clocks/voltagens.
