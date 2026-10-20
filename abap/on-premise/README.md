# Cenário On-Premise — SAP S/4HANA 2025 FPS01

Objetos para implantar o backend no **SAP S/4HANA 2025 FPS01** (ABAP Platform 2025, com SAP Gateway e
SAP Fiori front-end server embarcados). Vale também para o SAP S/4HANA Cloud Private Edition 2025.

Esta pasta guarda **apenas as diferenças**. O restante do código — tabelas, CDS, behavior definitions,
behavior pools, service definitions e bindings, classes utilitárias e testes — é importado de
[`../abap-environment/`](../abap-environment) **sem alteração**, pois o S/4HANA 2025 executa o modelo
ABAP Cloud (*ABAP for Cloud Development*, tier 1) no próprio sistema.

O roteiro completo (pré-requisitos, ordem de importação, Basis, segurança, Fiori launchpad, transporte,
limitações e diferenças em relação ao BTP) está na
[Especificação Técnica, seção 26](../../docs/Pedidos_de_Compras_-_Especificacao_Tecnica.md#26-implementação-no-cenário-on-premise-sap-s4hana-2025-fps01).
A arquitetura está em [`docs/assets/arquitetura-onpremise.png`](../../docs/assets/arquitetura-onpremise.png)
(página 7 de [`docs/diagramas/pedidos-de-compras.drawio`](../../docs/diagramas/pedidos-de-compras.drawio)).

## Objetos desta pasta

| Objeto | Pacote | Versão de linguagem | O que muda em relação ao BTP |
| --- | --- | --- | --- |
| [`ZIF_PC_CONSTANTS`](ZAVBS_PC_COMMON/Source%20Code%20Library/ZIF_PC_CONSTANTS.intf.abap) | `ZAVBS_PC_COMMON` | ABAP for Cloud Development | `c_modo_trial = abap_false`: o `AUTHORITY-CHECK` de `ZCL_PC_AUTH` passa a valer. **Substitui** o arquivo de `abap-environment`. |
| [`ZCL_PC_VIACEP`](ZAVBS_PC_COMMON_T2/Source%20Code%20Library/ZCL_PC_VIACEP/ZCL_PC_VIACEP.clas.abap) | `ZAVBS_PC_COMMON_T2` (novo) | **Standard ABAP** + contrato de liberação **C1** | `CL_HTTP_CLIENT=>CREATE_BY_DESTINATION` com a destination `Z_VIACEP` (SM59) no lugar de `cl_http_destination_provider=>create_by_url`. Mesma interface pública (superconjunto). **Substitui** a classe de `abap-environment`. |
| [`ZPC_TESTE_VIACEP`](ZAVBS_PC_COMMON_T2/Source%20Code%20Library/ZPC_TESTE_VIACEP/ZPC_TESTE_VIACEP.prog.abap) | `ZAVBS_PC_COMMON_T2` (novo) | Standard ABAP | Report para testar SM59/STRUST/proxy em cada sistema antes de usar a app. |

O pacote `ZAVBS_PC_COMMON_T2` é um **subpacote de `ZAVBS_PC_COMMON`** com a versão de linguagem
*Standard ABAP* (tier 2 do modelo de extensibilidade de três camadas). Ele existe só para isolar a API
clássica `CL_HTTP_CLIENT`: o BO Cliente continua em ABAP Cloud e chama a classe liberada.

## Objetos de `abap-environment` que não são importados

| Objeto | Motivo | Substituto On-Premise |
| --- | --- | --- |
| `ZAVBS_PC_COMMON/Source Code Library/ZIF_PC_CONSTANTS.intf.abap` | Modo trial ligado | `on-premise/ZAVBS_PC_COMMON/.../ZIF_PC_CONSTANTS.intf.abap` |
| `ZAVBS_PC_COMMON/Source Code Library/ZCL_PC_VIACEP/` | `create_by_url` não disponível/permitido no sistema On-Premise testado | `on-premise/ZAVBS_PC_COMMON_T2/.../ZCL_PC_VIACEP.clas.abap` |
| `*/Identity and Access Management/*.sia6.xml` e `*.txt` | IAM Apps não existem no On-Premise | `SU24` (valores propostos) + roles `PFCG` |
| `ZAVBS_PC_REEMBOLSOS/Cloud Communication Management/*_G4BA.abap` | Serviço de entrada gerado pela publicação no BTP | Gerado ao publicar o binding (`/IWFND/V4_ADMIN`) |
| `ZAVBS_PC_REEMBOLSOS/Authorizations/*.sush.xml` | Valores propostos gerados no BTP | Manter em `SU24` para o grupo de serviços |
| `ZAVBS_PC_COMMON/Authorizations/*.susob.xml` (classe `CPAE`) | Classe de objetos do BTP | Recriar `ZPC_ADMIN` e `ZPC_PEDIDO` em `SU21` na classe `ZPC` (mesmas atividades: 01, 02, 03, 06 e 16) |
| `Number Range Management/ZPC_NR.abap` | Editor do BTP | Criar `ZPC_NR` na `SNRO` (domínio `ZPC_NR_NUMC10`, buffer em memória com 10 números) |

## Roteiro resumido

1. Conferir o release (`System → Status` ou tabela `CVERS`): S/4HANA 2025 FPS01, ABAP Platform 2025.
2. Criar o pacote `ZAVBS_PEDIDOS_COMPRAS` e os subpacotes com a versão de linguagem
   *ABAP for Cloud Development*, numa camada de transporte do landscape (`DEV → QAS → PRD`).
   Criar `ZAVBS_PC_COMMON_T2` com *Standard ABAP*.
3. Criar os objetos manuais (Message Class `ZPC_MSG`, domínio `ZPC_NR_NUMC10`, `SNRO ZPC_NR`,
   `SU21 ZPC_ADMIN/ZPC_PEDIDO`) e importar `abap-environment/` na ordem do
   [README principal](../../README.md#ordem-de-criação-e-ativação), trocando os dois objetos desta pasta.
4. Liberar `ZCL_PC_VIACEP` com contrato **C1** (*Use in Cloud Development*) antes de ativar
   `ZBP_R_PC_CLIENTE`.
5. Basis: destination `Z_VIACEP` na `SM59`, certificados no `STRUST`, regra de proxy/firewall
   ([tutorial](../../docs/tutorial_migracao_viacep_btp_para_onpremise.md)); testar com `ZPC_TESTE_VIACEP`.
6. Publicar os service bindings (ADT ou `/IWFND/V4_ADMIN`), manter `SU24`, criar as roles
   `Z_PC_ADMIN`/`Z_PC_COMUM` na `PFCG` ([tutorial](../../docs/tutorial_autorizacao_btp_para_onpremise.md)).
7. Executar `ZCL_PC_SETUP` (F9) em cada sistema (intervalos de numeração e CodeLists; dados de
   demonstração só em DEV/QAS).
8. Front-end: `npm run deploy` apontando para o sistema On-Premise e conteúdo do Fiori launchpad
   (catálogos, espaços e páginas) nas roles.
