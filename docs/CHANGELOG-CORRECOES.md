# Correções de confiabilidade — revisão 2026-11-21

| Área | Antes | Agora |
|---|---|---|
| Teste QEMU | Aprovava qualquer captura com pixels; o menu GRUB podia ser confundido com o Linux iniciado. | Exige um marcador serial enviado por serviço systemd somente depois que o LightDM está ativo. BIOS e UEFI são obrigatórios. |
| GitHub Actions | `continue-on-error: true` permitia que QEMU falhasse e o workflow terminasse verde. | O teste QEMU é obrigatório; falha torna a execução vermelha, com artefatos de diagnóstico preservados. |
| Validação do kernel | Conferia apenas a existência de `/live/vmlinuz`. | Extrai o kernel e verifica `HdrS` e o boot flag `0xAA55` do protocolo x86. |
| Limpeza da compilação | Ignorava falha em `lb clean --all`. | A limpeza precisa concluir; a ISO só pode ser copiada se for nova nesta execução. |
| Diagnóstico serial | Não havia critério para distinguir GRUB de sessão gráfica iniciada. | Adiciona console serial e `nova-qemu-ready.service`, inofensivo em máquinas sem `/dev/ttyS0`. |
| Instalação | Documentação deixava implícito que a presença do instalador equivalia a instalação testada. | Documentação separa boot Live, presença do instalador e teste completo da instalação em VM. |

## Limitações honestas

Esta revisão melhora o processo de build e impede aprovação falsa do teste QEMU. Não significa que uma nova ISO já tenha sido compilada nesta sessão, nem que a instalação completa ou cada componente de um notebook ASUS tenha sido validado. A nova ISO precisa ser gerada pelo GitHub Actions e passar nas novas etapas obrigatórias; depois, a instalação deve ser concluída em VM antes de tocar no disco interno.

Secure Boot permanece não suportado nesta imagem: precisa ser desativado no firmware.
