# Correções aplicadas (revisão de auditoria)

Baseado em `NOVA-GAMER-OS-Installable-Source-v4-FIXED.zip` (cópia original preservada pelo usuário; nada foi apagado).
Nenhuma destas correções foi executada em uma compilação real: ver `README-TESTES.md`.

| # | Problema encontrado | Correção |
|---|---|---|
| 1 | `.gitignore` ignorava `config/` inteiro: num repositório Git, todo o projeto (pacotes, UI, atalhos) ficaria de fora e a ISO sairia "genérica". | Passou a ignorar apenas os arquivos gerados pelo live-build (`config/binary`, `bootstrap`, `chroot`, `common`, `source`) e saídas de build. |
| 2 | `nova-game-mode`, `nova-status` e `build-iso.sh` sem bit de execução no ZIP; ZIPs também perdem permissões. | Permissões ajustadas e hook `config/hooks/live/0100-nova-permissions.hook.chroot` que reaplica `chmod` dentro da imagem (inclui os `.desktop` da área de trabalho). |
| 3 | `policykit-1` (pacote de transição) e `pkexec` não declarado. | Trocado por `polkitd` + `pkexec`. |
| 4 | `firmware-linux`, `firmware-linux-nonfree`: arrastam firmware de outros fabricantes (ex.: AMD), contra o requisito "somente Intel". | Substituídos por `firmware-misc-nonfree` (inclui i915), `firmware-iwlwifi` (Wi-Fi Intel) e `firmware-realtek` (Ethernet comum), além de `intel-microcode`. |
| 5 | Faltava pilha de áudio completa e Vulkan/Mesa. | Adicionados `pipewire-audio`, `pavucontrol`, `mesa-vulkan-drivers`, `libgl1-mesa-dri`; `lightdm-gtk-greeter` e `locales` explícitos. |
| 6 | `nova-game-mode` chamava `pkexec powerprofilesctl set ...` (desnecessário, pede senha de root). | Chamada direta a `powerprofilesctl` (autorizada pelo polkit para sessão local ativa). |
| 7 | `lb clean --purge` antes do `lb config`. | Substituído por `lb clean --all` (não toca em `config/`). |
| 8 | `build-iso.sh` não gravava log nem nome/volume da ISO; hash em `.iso.sha256`. | Log em `build/BUILD-LOG.txt`, volume `NOVA_GAMER_OS`, hash em `build/SHA256SUMS.txt`, parâmetros de idioma `pt_BR` / teclado `br`. |
| 9 | `BUILD-ISO-WINDOWS.bat`: `wsl -l -q | findstr` falha (saída UTF-16) e compilava em `/mnt/c`, onde o live-build costuma falhar. | Teste por execução (`wsl -d Debian -- true`) e compilação em `~/nova-build` (ext4), copiando a ISO de volta. **Não testado no Windows.** |
| 10 | UI mostrava indicadores e botões (perfil, Modo jogo, Wi-Fi) que parecem reais, mas são só visuais. | Faixa permanente "PAINEL DEMONSTRATIVO" na interface. Nenhum controle de overclock foi criado. |
| 11 | Sem automação para build em Linux limpo. | Workflow `.github/workflows/build-iso.yml`, `scripts/validate-iso.sh`, `scripts/qemu-boot-test.sh`. |

## Pontos que NÃO foram alterados de propósito
- Instalador: mantido `--debian-installer live` + `debian-installer-launcher`. O instalador do Debian Live em trixie também pode ser Calamares; se o launcher não funcionar no teste, a alternativa é trocar por `calamares` + `calamares-settings-debian`.
- Repositórios não estão fixados em snapshot (versões variam conforme o dia do build).
- `scripts/try-exe-with-wine.sh` fica no repositório, mas não é incluído na imagem; Wine não é instalado.
