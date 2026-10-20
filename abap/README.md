# Backend ABAP / RAP

O backend existe em dois cenários de implementação. O código RAP é o mesmo nos dois; o que muda é a
plataforma, a conectividade e a segurança.

| Pasta | Cenário | Conteúdo |
| --- | --- | --- |
| [`abap-environment/`](abap-environment) | **SAP BTP, ABAP environment** (cenário principal, Trial, software component `ZLOCAL`) | Todos os objetos do projeto: pacotes `ZAVBS_PC_COMMON`, `ZAVBS_PC_CLIENTES`, `ZAVBS_PC_ESTOQUE`, `ZAVBS_PC_PEDIDOS` e `ZAVBS_PC_REEMBOLSOS`, inclusive IAM Apps e objetos de comunicação do BTP. |
| [`on-premise/`](on-premise) | **SAP S/4HANA 2025 FPS01** (ABAP Platform 2025, On-Premise ou Private Edition) | Somente os objetos que **substituem** ou **acrescentam** algo ao cenário principal. Os demais são importados de `abap-environment/` sem alteração. |

```text
abap/
├── abap-environment/                SAP BTP, ABAP environment (fonte completa)
│   ├── ZAVBS_PC_COMMON
│   ├── ZAVBS_PC_CLIENTES
│   ├── ZAVBS_PC_ESTOQUE
│   ├── ZAVBS_PC_PEDIDOS
│   └── ZAVBS_PC_REEMBOLSOS
└── on-premise/                      SAP S/4HANA 2025 FPS01 (diferenças)
    ├── ZAVBS_PC_COMMON              ZIF_PC_CONSTANTS com c_modo_trial = abap_false
    └── ZAVBS_PC_COMMON_T2           tier 2 (Standard ABAP): ZCL_PC_VIACEP com CL_HTTP_CLIENT + SM59
```

A convenção de arquivos (um arquivo por objeto ADT) está no [README principal](../README.md#convenção-de-arquivos).
O passo a passo do cenário On-Premise, com as limitações e as diferenças em relação ao BTP, está na
[Especificação Técnica, seção 26](../docs/Pedidos_de_Compras_-_Especificacao_Tecnica.md#26-implementação-no-cenário-on-premise-sap-s4hana-2025-fps01)
e no [`on-premise/README.md`](on-premise/README.md).
