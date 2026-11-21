# NOVA GAMER OS — critérios de validação

## O que significa uma compilação aprovada

Uma ISO só deve ser considerada pronta para teste de instalação se todas as etapas obrigatórias do GitHub Actions terminarem sem falha:

1. `lb build` conclui e gera `NOVA-GAMER-OS-amd64.iso`.
2. `scripts/validate-iso.sh` confirma a estrutura híbrida, entradas BIOS/UEFI, arquivos do Debian Installer, sistema SquashFS e cabeçalho real de kernel Linux x86 (`HdrS` e boot flag `0xAA55`).
3. `scripts/qemu-boot-test.sh` inicia a mídia em BIOS e UEFI e aguarda o serviço de teste confirmar que o sistema Live e o LightDM foram iniciados.

O teste QEMU não aprova mais uma captura de tela colorida ou apenas o menu do GRUB. Se o kernel não iniciar, se o sistema Live não montar, se o LightDM não ficar ativo ou se UEFI/BIOS não concluir o boot, a etapa falha e o workflow fica vermelho. Os logs continuam sendo publicados para diagnóstico.

## Marcador serial de teste

O parâmetro `console=ttyS0,115200n8` permite que a VM receba as mensagens de inicialização. O serviço `nova-qemu-ready.service` escreve `NOVA_GAMER_OS_GRAPHICAL_READY` apenas quando o LightDM está ativo e o dispositivo serial existe. Em computadores físicos sem `/dev/ttyS0`, o serviço termina silenciosamente; ele não configura nem altera drivers do equipamento.

## Limites que continuam exigindo teste

- O teste em QEMU não substitui o teste no modelo exato do notebook.
- A instalação completa no disco virtual ainda precisa ser realizada manualmente em uma VM descartável antes de instalar no disco interno.
- Compatibilidade de Wi-Fi, áudio, touchpad, suspensão, brilho e gráficos depende do modelo e dos componentes do notebook ASUS.
- A imagem não é assinada para Secure Boot; mantenha Secure Boot desativado para iniciar esta versão.
- Faça backup e não selecione o disco interno enquanto ainda estiver apenas testando o Live.

## Evidências

O workflow publica a ISO, SHA-256, log da compilação, validação estrutural, console serial de BIOS/UEFI e `QEMU-LOG.txt`. Guarde esses arquivos junto da ISO testada.
