# Pedidos de Compras — Especificação Técnica

**SAP RAP · SAP BTP, ABAP environment e SAP S/4HANA On-Premise · SAP Fiori Elements**

| Item | Valor |
| --- | --- |
| Documento | Especificação técnica — requisitos de construção da solução |
| Versão | 3.2 (21/10/2026) |
| Ambientes-alvo | SAP BTP, ABAP environment (ABAP Cloud) e SAP S/4HANA On-Premise 2025 ou superior (Standard ABAP) |
| Diagramas | `docs/pedidos-de-compras.drawio` (uma página por diagrama), exportados em `assets/` |

## Sumário

1. [Objetivo](#1-objetivo)
2. [Escopo](#2-escopo)
3. [Ambientes de implementação e arquitetura](#3-ambientes-de-implementação-e-arquitetura)
4. [Padrão de nomenclatura](#4-padrão-de-nomenclatura)
5. [Perfis de usuário e permissões](#5-perfis-de-usuário-e-permissões)
6. [Autenticação e autorização](#6-autenticação-e-autorização)
7. [Modelo de dados](#7-modelo-de-dados)
8. [Business Objects RAP](#8-business-objects-rap)
9. [Comunicação entre as aplicações](#9-comunicação-entre-as-aplicações)
10. [Regras de negócio](#10-regras-de-negócio)
11. [Fluxo de status do pedido](#11-fluxo-de-status-do-pedido)
12. [Reserva, baixa, liberação e concorrência de estoque](#12-reserva-baixa-liberação-e-concorrência-de-estoque)
13. [Reembolso de pedidos](#13-reembolso-de-pedidos)
14. [Pagamento simulado com cartão](#14-pagamento-simulado-com-cartão)
15. [Cálculos do pedido](#15-cálculos-do-pedido)
16. [Endereço e integração com o ViaCEP](#16-endereço-e-integração-com-o-viacep)
17. [Importação em massa por planilha](#17-importação-em-massa-por-planilha)
18. [Interface do usuário — SAP Fiori Elements](#18-interface-do-usuário--sap-fiori-elements)
19. [Camada analítica](#19-camada-analítica)
20. [Actions, validations e determinations](#20-actions-validations-e-determinations)
21. [Mensagens de erro e sucesso](#21-mensagens-de-erro-e-sucesso)
22. [Critérios de aceite](#22-critérios-de-aceite)
23. [Estrutura de pacotes](#23-estrutura-de-pacotes)
24. [Implantação e operação](#24-implantação-e-operação)
25. [Testes automatizados](#25-testes-automatizados)
26. [Considerações de segurança](#26-considerações-de-segurança)
27. [Restrições técnicas](#27-restrições-técnicas)

---

## 1. Objetivo

Construir uma solução educacional de pedidos de compras com o SAP RAP (ABAP RESTful Application Programming
Model) e o SAP Fiori Elements, organizada em quatro aplicações desacopladas — Gestão de Clientes, Gestão de
Estoque, Pedidos de Compras e Gestão de Reembolsos — e quatro aplicações de análise somente leitura.

A solução deve contemplar o cadastro de clientes, endereços e itens de estoque, a criação de pedidos em draft,
o registro do pedido com reserva de estoque, o pagamento simulado, a aprovação com baixa de estoque, o
cancelamento (com solicitação e decisão de reembolso quando o pagamento já foi aprovado), a liberação de
reserva e snapshots históricos imutáveis.

O mesmo código RAP deve ser implantável em dois ambientes: no **SAP BTP, ABAP environment** (ABAP Cloud) e
num **SAP S/4HANA On-Premise** (pacotes Standard ABAP). Nos dois ambientes a solução usa CDS View Entities,
Behavior Definitions, Behavior Implementations, Service Definitions e Service Bindings OData V4; só a
configuração da plataforma (segurança, conectividade, launchpad e transporte) muda de um para o outro.

## 2. Escopo

### 2.1 Incluído no escopo

- Aplicação Gestão de Clientes: cadastro, consulta, edição, ativação, inativação e exclusão controlada.
- Múltiplos endereços por cliente, com apenas um endereço principal.
- Validação de CEP e preenchimento automático do endereço pelo serviço público ViaCEP.
- Aplicação Gestão de Estoque: cadastro, consulta, edição, exclusão e inativação controladas de itens.
- Controle de estoque com quantidade total, reservada e disponível.
- Aplicação Pedidos de Compras, que consome clientes e itens por views reutilizáveis, value helps e associações.
- Pedidos em draft, sem reserva de estoque enquanto forem rascunho.
- Registro do pedido ao salvar o rascunho, com validação, cálculo do total, fixação de preço e reserva de
  estoque — sem action de confirmação.
- Edição dos itens do pedido `ABERTO` com ajuste da reserva pela diferença; o cliente não pode ser trocado.
- Object Page dinâmica do pedido, com seções exibidas conforme o status e dados vindos dos snapshots nos
  pedidos encerrados.
- Pagamento simulado com cartão de crédito ou débito, sem persistência de dados sensíveis, com nova
  tentativa em caso de recusa.
- Aprovação do pedido com baixa de estoque, geração de snapshots e imutabilidade do histórico.
- Cancelamento com motivo obrigatório; com pagamento aprovado, abertura de uma solicitação de reembolso.
- Aplicação Gestão de Reembolsos, com as actions Aprovar reembolso e Rejeitar reembolso.
- Importação em massa de clientes, itens e pedidos por planilha (`.xlsx` ou `.csv`).
- Serviços, bindings, catálogos e tiles separados por aplicação.
- Controle de acesso por perfil (comum e administrador) nos dois ambientes.
- Controle de concorrência nas operações de estoque.
- Camada analítica somente leitura com quatro aplicações SAPUI5 freestyle, uma por domínio, com 5 análises cada.
- Navegação entre aplicações pelo SAP Fiori launchpad.
- Testes ABAP Unit permanentes para as regras de negócio.

### 2.2 Fora do escopo

- Gestão de entrega, frete, transportadoras ou rastreamento.
- Integração real com gateway de pagamento.
- Armazenamento do número completo do cartão, CVV ou validade.
- Histórico completo de tentativas de pagamento.
- Auditoria avançada de alterações, logs técnicos e monitoramento produtivo.
- Testes de interface automatizados de ponta a ponta.
- Acesso externo (internet) às aplicações no ambiente On-Premise.
- Uso por clientes reais.

## 3. Ambientes de implementação e arquitetura

### 3.1 Ambientes-alvo

| Aspecto | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| Release | Release corrente do ABAP environment (Trial ou pago) | SAP S/4HANA 2025 (ABAP Platform 2025) ou superior; vale também para a Private Edition |
| Versão de linguagem dos pacotes | ABAP for Cloud Development | Standard ABAP |
| Código RAP | Igual nos dois ambientes | Igual nos dois ambientes |
| Ferramenta de desenvolvimento | ADT no Eclipse ou no VS Code (extensão ABAP Development Tools, conexão HTTP) | ADT no Eclipse ou no VS Code (conexão RFC, a partir do S/4HANA 2025) e SAP GUI |
| Identidade | SAP ID service ou Identity Authentication | Usuários `SU01`, SSO por SAML 2.0 ou Kerberos |
| Autorização | IAM Apps, Business Catalogs e Business Roles | `SU21`, `SU24` e roles `PFCG` |
| Conectividade com o ViaCEP | Destination por URL ou Communication Arrangement | Destination HTTP `SM59` com certificados no `STRUST` |
| Publicação OData | Service Binding publicado no ADT | Service Binding publicado no ADT ou em `/IWFND/V4_ADMIN` |
| Launchpad | SAP Build Work Zone ou launchpad do ABAP environment | SAP Fiori launchpad embarcado |
| Transporte | Software component (gCTS) | Ordens Workbench e Customizing (`STMS`, DEV → QAS → PRD) |
| Operação | Gerenciada pela SAP | Responsabilidade da empresa (ou da SAP na Private Edition) |

Os fontes devem ser escritos no subconjunto ABAP Cloud (APIs liberadas, `strict ( 2 )`), para que ativem nos
dois ambientes. A única classe com implementação diferente por ambiente é a de integração com o ViaCEP
(seção 16), que deve manter a mesma interface pública nas duas versões.

### 3.2 Camadas tecnológicas

| Camada | Tecnologia | Requisito |
| --- | --- | --- |
| Persistência | Tabelas do ABAP Dictionary no SAP HANA | Tabelas ativas `ZTA_PC_*` e draft `ZTA_PC_*_D` para todas as entidades com draft |
| Modelo | CDS View Entities | Root/base `ZR_*`, projeções `ZC_*_APP`, value helps `ZC_*_VH`, cubos `ZI_*_CUBE` e consultas `ZC_*_ANALISE` |
| Comportamento | RAP managed com draft | Validations, determinations, actions, feature control, authorization control e EML |
| Serviços | OData V4 (Service Definition + Service Binding UI) | Um serviço por aplicação de gestão e um serviço analítico |
| Front-end | SAP Fiori Elements V4 e SAPUI5 freestyle | List Report + Object Page nas aplicações de gestão; `sap.viz` e `$apply` nas análises; SAPUI5 ≥ 1.136 |
| Portal | SAP Build Work Zone (BTP) ou SAP Fiori launchpad (On-Premise) | Um tile por aplicação, com navegação por semantic object |
| Integração | API pública ViaCEP (HTTPS) | Consulta de CEP no backend |

### 3.3 Arquitetura no SAP BTP, ABAP environment

<p align="center"><img src="../assets/arquitetura.png" alt="Arquitetura no SAP BTP, ABAP environment: usuários e Work Zone, apps (BSP), serviços OData V4, BOs RAP, camada analítica, SAP HANA e a API ViaCEP" width="100%"><br><sub>Figura 1 — Arquitetura no SAP BTP, ABAP environment</sub></p>

- As oito aplicações são publicadas como BSPs no ABAP repository e acessadas pelo SAP Build Work Zone.
- Cada aplicação de gestão chama o próprio serviço OData V4; as quatro análises usam o serviço analítico.
- Os BOs RAP se comunicam por EML na mesma LUW; o BO Cliente consulta a API ViaCEP.

### 3.4 Arquitetura no SAP S/4HANA On-Premise

<p align="center"><img src="../assets/arquitetura-onpremise.png" alt="Arquitetura On-Premise: SAP Web Dispatcher, SAP Fiori launchpad e SAP Gateway embarcados, BOs RAP em pacotes Standard ABAP, destination SM59 e STRUST, proxy, firewall e API ViaCEP" width="100%"><br><sub>Figura 2 — Arquitetura no SAP S/4HANA On-Premise</sub></p>

1. O usuário acessa o **SAP Web Dispatcher** (HTTPS), ponto único de entrada da intranet, com SSO.
2. O **SAP Fiori launchpad** embarcado exibe os tiles das roles do usuário e abre as aplicações (BSPs
   servidas por `/sap/bc/ui5_ui5`).
3. As aplicações chamam os serviços OData V4 do **SAP Gateway** embarcado; o acesso a cada grupo de
   serviços é verificado pelo objeto `S_START`.
4. Os serviços expõem os BOs RAP, que funcionam como no BTP; os dados ficam no SAP HANA do sistema.
5. A consulta de CEP usa uma destination HTTP (`SM59`) com a confiança TLS do `STRUST`, sai pelo proxy e
   atravessa o firewall até a API ViaCEP.
6. O desenvolvimento ocorre no ADT, no Eclipse ou no VS Code (e no SAP GUI para Basis), em DEV, e tudo segue
   por transporte para QAS e PRD.

### 3.5 Aplicações e serviços

| Aplicação | Tipo | Service Definition | Service Binding | Responsabilidade |
| --- | --- | --- | --- | --- |
| Gestão de Clientes | Fiori Elements (LR + OP) | `ZUI_PC_CLIENTES` | `ZUI_PC_CLIENTES_O4` | Clientes e endereços |
| Gestão de Estoque | Fiori Elements (LR + OP) | `ZUI_PC_ESTOQUE` | `ZUI_PC_ESTOQUE_O4` | Itens, SKU e quantidades |
| Pedidos de Compras | Fiori Elements (LR + OP) | `ZUI_PC_PEDIDOS_COMPRAS` | `ZUI_PC_PEDIDOS_COMPRAS_O4` | Ciclo de vida do pedido |
| Gestão de Reembolsos | Fiori Elements (LR + OP) | `ZUI_PC_REEMBOLSOS` | `ZUI_PC_REEMBOLSOS_O4` | Decisão das solicitações de reembolso |
| Análises (quatro apps) | SAPUI5 freestyle | `ZUI_PC_ANALITICO` | `ZUI_PC_ANALITICO_O4` | Pedidos, clientes, estoque e reembolsos (somente leitura) |

## 4. Padrão de nomenclatura

| Tipo de artefato | Padrão | Exemplo |
| --- | --- | --- |
| Pacotes | `<prefixo>_PC_*` (prefixo livre; sugestão: `ZPK`) | `ZPK_PC_COMMON`, `ZPK_PC_PEDIDOS` (neste repositório, `ZAVBS_PC_*`) |
| Tabelas ativas | `ZTA_PC_*` | `ZTA_PC_CLIENTE`, `ZTA_PC_ITEM_PED` |
| Tabelas draft | `ZTA_PC_*_D` | `ZTA_PC_CLIENTE_D`, `ZTA_PC_ITPED_D` |
| Root/base CDS view entity | `ZR_PC_*` | `ZR_PC_PEDIDO` |
| Projeção de consumo | `ZC_PC_*_APP` | `ZC_PC_PEDIDO_APP` |
| Value help | `ZC_PC_*_VH` | `ZC_PC_CLIENTE_VH` |
| Cubo / consulta analítica | `ZI_PC_*_CUBE` / `ZC_PC_*_ANALISE` | `ZI_PC_PEDIDO_CUBE` |
| Parâmetro de action (abstract entity) | `ZPC_A_*` | `ZPC_A_PAGAMENTO_INPUT` |
| Behavior pool | `ZBP_R_PC_*` | `ZBP_R_PC_PEDIDO` |
| Service Definition / Binding | `ZUI_PC_*` / `ZUI_PC_*_O4` | `ZUI_PC_ESTOQUE_O4` |
| Classes, interfaces, exceções e mensagens | `ZCL_PC_*` / `ZIF_PC_*` / `ZCX_PC_*` / `ZPC_MSG` | `ZCL_PC_AUTH`, `ZIF_PC_MSG`, `ZCX_PC_MSG` |
| Objetos de autorização | `ZPC_*` | `ZPC_ADMIN`, `ZPC_PEDIDO` |
| BTP: IAM App / Business Catalog / Business Role | `ZPC_IAM_*` / `ZPC_BC_*` / `ZPC_BR_*` | `ZPC_IAM_PEDIDOS`, `ZPC_BR_ADMIN` |
| On-Premise: classe de objetos / roles | `ZPC` / `Z_PC_*` | `Z_PC_ADMIN`, `Z_PC_COMUM` |
| On-Premise: destination HTTP | `Z_*` | `Z_VIACEP` |
| Aplicações (BSP) | `ZPC_*` / `ZPC_ANL_*` | `ZPC_PEDIDOS`, `ZPC_ANL_ESTOQUE` |

O prefixo dos pacotes é livre. `ZAVBS`, usado neste repositório, é uma escolha pessoal do autor (as iniciais do
seu nome completo) e é opcional. Cada projeto define os próprios prefixos; como sugestão genérica, adota-se
`ZPK` (`ZPK_PEDIDOS_COMPRAS`, `ZPK_PC_COMMON`, `ZPK_PC_CLIENTES` etc.). Os demais prefixos da tabela também
podem ser trocados, desde que permaneçam no namespace do cliente (`Z` ou `Y`), respeitem o tamanho máximo de
cada tipo de objeto e sejam aplicados de forma consistente em todos os artefatos que os referenciam.

Limites técnicos: nomes de tabela têm no máximo 16 caracteres (por isso `ZTA_PC_ITEM_PED`, `ZTA_PC_SNAP_CLI` e
as tabelas draft abreviadas); CDS e classes, 30 caracteres. No BTP, o ADT acrescenta o sufixo `_EXT` às IAM
Apps do tipo External App.

## 5. Perfis de usuário e permissões

### 5.1 Usuário comum

- Acessa a aplicação Pedidos de Compras e consulta clientes e itens por value helps.
- Cria pedidos em rascunho e altera os itens de pedidos `ABERTO`.
- Não cria, edita nem exclui clientes e itens de estoque.
- Não edita pedidos finalizados ou cancelados nem snapshots.
- Executar pagamento, aprovação, cancelamento e decisão de reembolso depende da atividade 16 (Executar),
  concedida conforme o processo da empresa.

### 5.2 Usuário administrador

- Acessa as quatro aplicações de gestão e as análises.
- Cria, edita, ativa, inativa e exclui clientes e itens, respeitando as regras de integridade.
- Executa todas as ações do pedido e do reembolso.
- Não edita pedidos encerrados nem snapshots e não consulta dados sensíveis de cartão.

### 5.3 Matriz de permissões

| Aplicação | Ação | Comum | Admin | Observação |
| --- | --- | --- | --- | --- |
| Clientes | Listar / visualizar | Sim | Sim | Comum por value help ou consulta |
| Clientes | Criar / editar / excluir / ativar / inativar | Não | Sim | CPF obrigatório, único e validado |
| Estoque | Listar / visualizar | Sim | Sim | Consulta de itens para o pedido |
| Estoque | Criar / editar / excluir / inativar | Não | Sim | SKU gerado automaticamente |
| Pedidos | Criar e editar itens | Sim | Sim | Edição apenas no status `ABERTO` |
| Pedidos | Efetuar Pagamento / Aprovar / Cancelar | Conforme role | Sim | Disponível por status (feature control) e perfil (atividade 16) |
| Reembolsos | Aprovar / Rejeitar | Conforme role | Sim | Somente solicitações `PENDENTE`; rejeitar exige motivo |
| Snapshots | Editar / excluir | Não | Não | Histórico imutável |
| Importação | Importar planilha | Pedidos | Todas | Atividade 01 do objeto do domínio |

## 6. Autenticação e autorização

A autenticação é delegada à plataforma. A autorização usa o mesmo código RAP nos dois ambientes e muda só a
configuração.

### 6.1 Objetos de autorização

| Objeto | Protege | Campo | Atividades |
| --- | --- | --- | --- |
| `ZPC_ADMIN` | Clientes e estoque | `ACTVT` | 01 Criar, 02 Alterar, 03 Exibir, 06 Excluir |
| `ZPC_PEDIDO` | Pedidos e reembolsos | `ACTVT` | 01 Criar, 02 Alterar, 03 Exibir, 06 Excluir, 16 Executar |

Toda verificação deve passar por uma classe central (`ZCL_PC_AUTH`) com um método por operação; os behavior
pools só consultam essa classe.

### 6.2 Configuração por ambiente

| Etapa | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| Objeto de autorização | ADT (classe `CPAE`) | `SU21` (classe própria `ZPC`) |
| Vínculo serviço × autorização | IAM App por serviço (`ZPC_IAM_CLIENTES`, `ZPC_IAM_ESTOQUE`, `ZPC_IAM_PEDIDOS`, `ZPC_IAM_REEMBOLSOS`) | Valores propostos na `SU24` por grupo de serviços |
| Agrupamento | Business Catalogs `ZPC_BC_*` | Roles `PFCG` com os serviços no menu (gera `S_START`) |
| Perfis | Business Roles `ZPC_BR_ADMIN` e `ZPC_BR_COMUM` | Roles `Z_PC_ADMIN` e `Z_PC_COMUM` |
| Atribuição ao usuário | *Maintain Business Users* | `SU01` / `PFCG` + comparação de usuários |
| Diagnóstico | *Display Authorization Trace* | `SU53`, `STAUTHTRACE`, `SUIM` |

| Role / Business Role | `ZPC_ADMIN` | `ZPC_PEDIDO` |
| --- | --- | --- |
| Administrador | 01, 02, 03, 06 | 01, 02, 03, 06, 16 |
| Comum | 03 | 01, 02, 03 (16 conforme o processo) |

### 6.3 Estratégia RAP

- Os quatro BOs devem declarar `authorization master ( global )`; o perfil é verificado em
  `get_global_authorizations`.
- Entidades filhas do pedido usam `authorization dependent by _Pedido`.
- A disponibilidade de Edit, Delete, inclusão de itens e actions por estado da instância deve usar feature
  control dinâmico (`features : instance`). Status não é critério de autorização.
- As actions internas de estoque e as chamadas pelo BO Reembolso usam `authorization : none` e não são
  expostas na projeção.
- A action de importação deve revalidar a autorização na implementação, porque grava em massa.
- Validações críticas devem permanecer no backend, independentemente das restrições visuais da UI.

### 6.4 Controle de leitura (opcional)

Por padrão, as CDS usam `@AccessControl.authorizationCheck: #NOT_REQUIRED`. Quando houver requisito de
restringir a leitura, devem ser criadas regras de acesso (DCL) com `aspect pfcg_auth` exigindo a atividade 03
nas views de consumo expostas (`ZC_*`), com a anotação trocada para `#CHECK`. As views `ZR_*` e os cubos
continuam sem regra, porque os behavior pools as leem internamente. A DCL funciona igual nos dois ambientes,
mas só pode ser ativada onde as roles puderem ser mantidas.

### 6.5 Modo de demonstração

Uma constante (`ZIF_PC_CONSTANTS=>c_modo_trial`) deve permitir liberar as verificações de perfil num sistema
compartilhado sem Business Roles configuráveis (BTP Trial). Em qualquer outro sistema — inclusive todo sistema
On-Premise — a constante deve ser `abap_false`, e nunca deve ser transportada para produção com `abap_true`.

## 7. Modelo de dados

Convenções: chaves UUID (`RAW 16`) com `numbering : managed`; valores monetários `CURR(15,2)` com referência a
um campo `CUKY`; booleanos como `abap_boolean`; campos administrativos `CreatedBy`, `CreatedAt`,
`LastChangedBy`, `LastChangedAt` e `LocalLastChangedAt` em todas as tabelas (`LocalLastChangedAt` = ETag da
entidade; `LastChangedAt` = total ETag do root). As tabelas devem usar tipos embutidos do ABAP, sem domínios
nem elementos de dados próprios.

### 7.1 Objetos persistentes

| Entidade | Tabela ativa | Tabela draft | Root/base view | Projeção |
| --- | --- | --- | --- | --- |
| Clientes | `ZTA_PC_CLIENTE` | `ZTA_PC_CLIENTE_D` | `ZR_PC_CLIENTE` | `ZC_PC_CLIENTE_APP` |
| Endereços | `ZTA_PC_ENDERECO` | `ZTA_PC_ENDEREC_D` | `ZR_PC_ENDERECO` | `ZC_PC_ENDERECO_APP` |
| Itens | `ZTA_PC_ITEM` | `ZTA_PC_ITEM_D` | `ZR_PC_ITEM` | `ZC_PC_ITEM_APP` |
| Pedidos | `ZTA_PC_PEDIDO` | `ZTA_PC_PEDIDO_D` | `ZR_PC_PEDIDO` | `ZC_PC_PEDIDO_APP` |
| Itens do pedido | `ZTA_PC_ITEM_PED` | `ZTA_PC_ITPED_D` | `ZR_PC_ITEM_PEDIDO` | `ZC_PC_ITEM_PEDIDO_APP` |
| Pagamentos | `ZTA_PC_PAGAMENTO` | `ZTA_PC_PAGTO_D` | `ZR_PC_PAGAMENTO` | `ZC_PC_PAGAMENTO_APP` |
| Snapshot do cliente | `ZTA_PC_SNAP_CLI` | `ZTA_PC_SNPCLI_D` (técnica) | `ZR_PC_PED_CLI_SNAP` | `ZC_PC_PED_CLI_SNAP_APP` |
| Snapshot dos itens | `ZTA_PC_SNAP_ITM` | `ZTA_PC_SNPITM_D` (técnica) | `ZR_PC_PED_ITEM_SNAP` | `ZC_PC_PED_ITEM_SNAP_APP` |
| Reembolsos | `ZTA_PC_REEMBOLSO` | Não se aplica (BO sem draft) | `ZR_PC_REEMBOLSO` | `ZC_PC_REEMBOLSO_APP` |
| CodeLists | `ZTA_PC_CODELIST` | Não se aplica | `ZR_PC_CODELIST` | `ZC_PC_*_VH` |

As CodeLists (gênero, categoria, status do estoque, status do pedido, status e método de pagamento, status do
reembolso) ficam numa única tabela com código, descrição e criticidade.

### 7.2 Clientes

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| ClienteUUID | RAW(16) | Sim | Chave (`numbering : managed`) |
| FotoCliente / FotoMimeType / FotoFileName | RAWSTRING / CHAR(50) / CHAR(255) | Não | JPEG, PNG ou WEBP |
| Cpf | CHAR(11) | Sim | Único, só números, dígitos verificadores validados; exibido formatado |
| Nome | CHAR(255) | Sim | Nome completo |
| Email | CHAR(100) | Sim | Formato válido |
| Telefone | CHAR(11) | Sim | DDD + número (10 ou 11 dígitos), só números |
| Genero | CHAR(30) | Não | CodeList |
| DataNascimento | DATS | Sim | Não pode ser futura |
| ClienteAtivo | abap_boolean | Sim | Novo cliente nasce ativo; inativo não faz pedidos |
| ScoreCliente | DEC(5,2) | Não | 0 a 100, somente leitura, sorteado na criação; exibido em % com criticidade |

### 7.3 Endereços

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| EnderecoUUID | RAW(16) | Sim | Chave |
| ClienteUUID | RAW(16) | Sim | Cliente proprietário |
| Cep | CHAR(8) | Sim | Só números, validado no ViaCEP; campo adicional da chave da tabela, somente leitura depois de gravado |
| Logradouro, Bairro | CHAR(150), CHAR(100) | Sim | Do ViaCEP e bloqueados; editáveis e obrigatórios só para CEP geral de município |
| Numero | CHAR(20) | Sim | Obrigatório |
| Complemento | CHAR(100) | Não | Informado pelo usuário |
| Cidade, Uf, Estado | CHAR(100), CHAR(2), CHAR(100) | Sim | Do ViaCEP |
| CepGeral | abap_boolean | Sim | Definido pelo backend |
| CepStatus | CHAR(1) | Sim | Resultado da consulta (válido, inválido, indisponível), avaliado na validação |
| EnderecoPrincipal | abap_boolean | Sim | Um por cliente; alterado só pela action; o primeiro endereço vira principal |

### 7.4 Itens de estoque

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| ItemUUID | RAW(16) | Sim | Chave |
| FotoItem / FotoMimeType / FotoFileName | RAWSTRING / CHAR(50) / CHAR(255) | Não | JPEG, PNG ou WEBP |
| Sku | CHAR(21) | Sim | `SKU-<3 letras da categoria>-<10 dígitos>`, gerado no Save; regenerado se a categoria mudar |
| Nome | CHAR(120) | Sim | Único entre os itens |
| Descricao | CHAR(500) | Não | Inclui informações como peso e dimensões |
| Categoria | CHAR(30) | Sim | CodeList |
| QtdeEstoque | INT4 | Sim | ≥ 0 e ≥ QtdeReservada |
| QtdeReservada | INT4 | Sim | Somente leitura; alterada só pelas actions internas |
| QtdeDisponivel | INT4 | Sim | QtdeEstoque − QtdeReservada, **persistida** (filtrável e ordenável) |
| StatusEstoque | CHAR(30) | Sim | `SEM_ESTOQUE`, `ACABANDO` ou `EM_ESTOQUE` |
| PrecoUnitario / Currency | CURR(15,2) / CUKY | Sim | Moeda padrão BRL |
| ItemAtivo | abap_boolean | Sim | Só itens ativos entram em novos pedidos |

### 7.5 Pedidos

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| PedidoUUID | RAW(16) | Sim | Chave |
| NumeroPedido | CHAR(10) | Sim | Sequencial gerado na primeira ativação |
| ClienteUUID | RAW(16) | Sim | Obrigatório na criação; somente leitura depois |
| EnderecoUUID / EnderecoPrincipalCompleto | RAW(16) / CHAR(500) | Sim | Endereço principal do cliente, derivado automaticamente |
| StatusPedido | CHAR(40) | Sim | `ABERTO`, `AGUARDANDO_APROVACAO`, `PROCESSANDO_REEMBOLSO`, `CANCELADO`, `FINALIZADO` |
| StatusPagamento | CHAR(30) | Sim | Réplica do pagamento (`PENDENTE`, `APROVADO`, `RECUSADO`, `DEVOLVIDO`) para lista e filtros |
| Observacao | CHAR(500) | Não | — |
| ValorTotal / Currency | CURR(15,2) / CUKY | Sim | Calculado no backend |
| DataFinalizacao | TIMESTAMPL | Não | Preenchida na aprovação |
| MotivoCancelamento / DataCancelamento / CanceladoPor | CHAR(500) / TIMESTAMPL / usuário | Não | Preenchidos no cancelamento |
| ReferenciaImportacao | CHAR(40) | Não | Somente leitura; chave de idempotência da importação |
| PedidoEncerrado, PedidoAtivoSemHistorico, PedidoNaoFinalizado, PedidoNaoCancelado | XFELD | Sim | Indicadores persistidos de status, usados para ocultar seções da Object Page |

### 7.6 Itens do pedido

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| ItemPedidoUUID / PedidoUUID / ItemUUID | RAW(16) | Sim | Chave, pedido e item de estoque |
| QtdeItemPedido | INT4 | Sim | Maior que zero |
| PrecoUnitarioSnapshot / Currency | CURR(15,2) / CUKY | Sim | Copiado do item no draft; fixado no registro |
| ValorTotal | CURR(15,2) | Sim | QtdeItemPedido × PrecoUnitarioSnapshot |
| Observacao | CHAR(500) | Não | — |

### 7.7 Pagamentos

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| PagamentoUUID / PedidoUUID | RAW(16) | Sim | Chave e pedido |
| MetodoPagamento | CHAR(20) | Sim | `CARTAO_CREDITO` ou `CARTAO_DEBITO` |
| StatusPagamento | CHAR(30) | Sim | `PENDENTE`, `APROVADO`, `RECUSADO` ou `DEVOLVIDO` |
| BandeiraCartao / Ultimos4DigitosCartao / CartaoMascarado | CHAR(30) / CHAR(4) / CHAR(30) | Não | Únicos dados do cartão gravados |
| CodigoAutorizacao / MensagemPagamento / DataPagamento | CHAR(50) / CHAR(255) / TIMESTAMPL | Não | Resultado da última tentativa |

O pagamento é filho de composição `[0..1]` do pedido, criado e atualizado somente pela action de pagamento.

### 7.8 Snapshots

| Snapshot | Tabela | Campos | Regra |
| --- | --- | --- | --- |
| Cliente | `ZTA_PC_SNAP_CLI` | CPF, nome, e-mail, telefone, gênero, nascimento, ativo, score, endereço e motivo (`FINALIZACAO`/`CANCELAMENTO`) | Criado uma única vez no encerramento |
| Itens | `ZTA_PC_SNAP_ITM` | SKU, nome, descrição, categoria, quantidade, preço e total | Criado uma única vez no encerramento |

Como são filhos de um BO com draft, os snapshots exigem tabelas draft, que devem permanecer vazias: só são
criados por `internal create` sobre a instância ativa e não têm update nem delete.

### 7.9 Reembolsos

| Campo | Tipo | Obrigatório | Regras |
| --- | --- | --- | --- |
| ReembolsoUUID | RAW(16) | Sim | Chave |
| PedidoUUID / NumeroPedido / ClienteUUID | RAW(16) / CHAR(10) / RAW(16) | Sim | Dados do pedido, imutáveis; nome e CPF do cliente vêm por associação |
| StatusReembolso | CHAR(20) | Sim | `PENDENTE`, `APROVADO` ou `REJEITADO` |
| StatusPedidoAnterior | CHAR(40) | Sim | Restaurado se o reembolso for rejeitado |
| ValorReembolso / Currency | CURR(15,2) / CUKY | Sim | Total do pedido na solicitação |
| MotivoSolicitacao / DataSolicitacao / SolicitadoPor | CHAR(500) / TIMESTAMPL / usuário | Sim | Dados do cancelamento |
| MotivoDecisao / DataDecisao / DecididoPor | CHAR(500) / TIMESTAMPL / usuário | Não | Motivo obrigatório ao rejeitar |

## 8. Business Objects RAP

### 8.1 Matriz dos Business Objects

| Aspecto | BO Cliente | BO Estoque | BO Pedido | BO Reembolso |
| --- | --- | --- | --- | --- |
| Entidade raiz | `ZR_PC_CLIENTE` | `ZR_PC_ITEM` | `ZR_PC_PEDIDO` | `ZR_PC_REEMBOLSO` |
| Entidades filhas | `ZR_PC_ENDERECO` | — | `ZR_PC_ITEM_PEDIDO`, `ZR_PC_PAGAMENTO`, `ZR_PC_PED_CLI_SNAP`, `ZR_PC_PED_ITEM_SNAP` | — |
| Implementação | managed, `strict ( 2 )` | managed, `strict ( 2 )` | managed, `strict ( 2 )` | managed, `strict ( 2 )` |
| Draft | Sim (cliente e endereço) | Sim | Sim (criação e edição dos itens do pedido `ABERTO`) | Não |
| Behavior pool | `ZBP_R_PC_CLIENTE` | `ZBP_R_PC_ITEM` | `ZBP_R_PC_PEDIDO` | `ZBP_R_PC_REEMBOLSO` |
| Projeção | `ZC_PC_CLIENTE_APP`, `ZC_PC_ENDERECO_APP` | `ZC_PC_ITEM_APP` | `ZC_PC_PEDIDO_APP` e projeções filhas | `ZC_PC_REEMBOLSO_APP` |
| Serviço | `ZUI_PC_CLIENTES` | `ZUI_PC_ESTOQUE` | `ZUI_PC_PEDIDOS_COMPRAS` | `ZUI_PC_REEMBOLSOS` |
| Operações | create, update, delete com precheck | create, update, delete com precheck | create, update (só itens em `ABERTO`), delete desabilitado | create só por EML do BO Pedido, internal update, sem delete |
| Numeração | UUID managed | UUID managed; SKU no Save (intervalo 02) | UUID managed; número na ativação (intervalo 01) | UUID managed |
| Bloqueio e ETag | lock master, total etag | lock master, total etag | lock master, total etag | lock master, etag |
| Autorização | global (`ZPC_ADMIN`) | global (`ZPC_ADMIN`) | global (`ZPC_PEDIDO`); filhas dependentes | global (`ZPC_PEDIDO`) |
| Actions públicas | `DefinirEnderecoPrincipal`; `ImportarPlanilha` (estática) | `ImportarPlanilha` (estática) | `SimularPagamento`, `AprovarPedido`, `CancelarPedido`; `ImportarPlanilha` (estática) | `AprovarReembolso`, `RejeitarReembolso` |
| Actions internas | — | `ReservarEstoque`, `LiberarReserva`, `BaixarEstoque` | `RecalcularTotal`, `CancelarPorReembolso`, `RetomarPedido` | — |
| Determinations | `DefinirValoresIniciais`, `NormalizarDados`; endereço: `PreencherEnderecoViaCep`, `DefinirPrincipalInicial` | `DefinirValoresIniciais`, `RecalcularStatusEstoque`, `GerarSku` | `DefinirStatusInicial`, `AtualizarEndereco`, `GerarNumeroPedido`, `CalcularTotalPedido`, `AtualizarFlagsStatus`, `ReservarEstoqueRegistro`; item: `CalcularValorItem` | — |
| Validations | `ValidarCpf`, `ValidarDadosObrigatorios`, `ValidarEmail`, `ValidarTelefone`, `ValidarDataNascimento`, `ValidarGenero`, `ValidarFoto`; endereço: `ValidarNumero`, `ValidarCep`, `ValidarCepUnico` | `ValidarItem`, `ValidarQuantidades`, `ValidarInativacaoItem`, `ValidarSkuUnico`, `ValidarFoto` | `ValidarCliente`, `ValidarRegistro`; item: `ValidarItemPedido` | Motivo obrigatório verificado na action de rejeição |
| Feature control | Exclusão bloqueada com pedido vinculado; CEP somente leitura depois de gravado; Logradouro/Bairro editáveis só para CEP geral | Exclusão bloqueada com pedido ou reserva | Edit só em `ABERTO`; actions por status; precheck da inclusão de item sem estoque | Actions só com status `PENDENTE` |
| Side effects | CEP recarrega os campos do endereço | Quantidade recarrega disponível e status | Cliente recarrega o endereço; item e quantidade recarregam totais; actions recarregam pagamento e snapshots | — |
| Draft actions | Activate, Discard, Edit, Resume, Prepare | Activate optimized, Discard, Edit, Resume, Prepare (com `GerarSku`) | Edit com feature control, Activate com implementação adicional, Discard, Resume, Prepare | — |

### 8.2 Matriz das entidades filhas do pedido

| Entidade | Cardinalidade | Operações | Bloqueio / autorização | Criação |
| --- | --- | --- | --- | --- |
| `ZR_PC_ITEM_PEDIDO` | `[0..*]` | create (com precheck), update, delete — só no draft | lock e authorization dependentes de `_Pedido` | Pelo usuário, *inline* no rascunho |
| `ZR_PC_PAGAMENTO` | `[0..1]` | internal update | lock e authorization dependentes de `_Pedido` | `internal create` pela action de pagamento |
| `ZR_PC_PED_CLI_SNAP` | `[0..1]` | nenhuma modificação | lock e authorization dependentes de `_Pedido` | `internal create` no encerramento |
| `ZR_PC_PED_ITEM_SNAP` | `[0..*]` | nenhuma modificação | lock e authorization dependentes de `_Pedido` | `internal create` no encerramento |

## 9. Comunicação entre as aplicações

As aplicações são desacopladas na UI e no serviço, mas compartilham o mesmo modelo de domínio ABAP.

### 9.1 Views reutilizáveis e value helps

| Origem | View reutilizável | Consumidor | Uso |
| --- | --- | --- | --- |
| Clientes | `ZC_PC_CLIENTE_VH` | Pedidos | Seleção de cliente ativo |
| Endereços | `ZC_PC_ENDERECO_VH` | Pedidos | Endereço principal do cliente |
| Estoque | `ZC_PC_ITEM_VH` | Pedidos | Itens ativos, preço e disponibilidade |
| Endereços | `ZC_PC_CEP_VH` | Clientes | CEPs já cadastrados |

### 9.2 Comunicação por EML

- O BO Pedido não atualiza o estoque pela UI do Estoque: reserva, baixa e liberação são actions internas do BO
  Item executadas por EML, na mesma LUW, com o item bloqueado (lock master) e o saldo relido sob o lock.
- Em falha parcial de reserva, as reservas já feitas na mesma chamada devem ser compensadas e nenhuma alteração
  do pedido gravada.
- O BO Pedido cria a solicitação no BO Reembolso por EML; o BO Reembolso executa as actions internas
  `CancelarPorReembolso` e `RetomarPedido` do BO Pedido. Tudo na mesma LUW.
- Toda chamada EML deve avaliar `FAILED` e `REPORTED` e propagar as mensagens.

### 9.3 Navegação entre aplicações

A navegação é de consulta, por semantic object, e não cria acoplamento funcional.

| Origem | Campos | Semantic object | Destino |
| --- | --- | --- | --- |
| Pedido e snapshot do cliente | Cliente, CPF | `ZPCCliente` | Gestão de Clientes |
| Item do pedido e snapshot dos itens | Item, SKU | `ZPCItemEstoque` | Gestão de Estoque |
| Reembolso | Pedido (link direto à Object Page) | `ZPCPedidoCompra` | Pedidos de Compras |
| Reembolso | Cliente, CPF | `ZPCCliente` | Gestão de Clientes |
| Análises | Botão *Abrir gestão* | `ZPC*-manage` | Aplicação de gestão do domínio |

A aplicação de destino deve abrir direto a Object Page ao receber a chave técnica ou semântica (`Cpf`, `Sku`,
`NumeroPedido`); o CPF do pedido (`CpfCliente`) é mapeado para `Cpf` com `@Consumption.semanticObjectMapping`.

## 10. Regras de negócio

### 10.1 Clientes

- Cadastro e edição com draft; CPF obrigatório, único, salvo só com números.
- Cliente pode ter vários endereços, apenas um principal.
- Cliente inativo não pode ser usado em novos pedidos.
- Cliente com pedido vinculado não pode ser excluído.
- Ativação e inativação por edição do campo ClienteAtivo, só para administradores.
- Fotos apenas em JPEG, PNG ou WEBP, validando MIME, extensão e assinatura binária.

### 10.2 Endereços

- O ViaCEP é obrigatório para validar o CEP; se estiver indisponível, o cadastro e a alteração são bloqueados.
- Campos retornados pelo ViaCEP não são editáveis, exceto Logradouro e Bairro para CEP geral de município.
- O número é obrigatório.
- Um CEP só pode aparecer uma vez por cliente; clientes diferentes podem compartilhar o mesmo CEP.
- Ao marcar um endereço como principal, os demais do cliente são desmarcados.

### 10.3 Itens e estoque

- Cadastro e edição com draft; SKU obrigatório, único e gerado no backend.
- QtdeDisponivel = QtdeEstoque − QtdeReservada, recalculada a cada movimentação.
- Item inativo não entra em novos pedidos; a inativação é bloqueada com estoque disponível ou pedido ativo.

| StatusEstoque | Regra |
| --- | --- |
| `SEM_ESTOQUE` | QtdeDisponivel = 0 |
| `ACABANDO` | QtdeDisponivel entre 1 e 10 |
| `EM_ESTOQUE` | QtdeDisponivel ≥ 11 |

### 10.4 Pedidos

- Pedido em draft não reserva estoque; a reserva ocorre ao salvar o rascunho, quando o pedido passa a `ABERTO`.
- O pedido exige cliente ativo, endereço principal e ao menos um item ativo com quantidade maior que zero.
- Item sem estoque disponível não pode ser incluído no rascunho (precheck).
- Em `ABERTO`, só os itens podem ser alterados, e a reserva é ajustada pela diferença; nos demais status o
  pedido não é editado nem excluído.
- O número do pedido é gerado na primeira ativação.
- Pedido `FINALIZADO` ou `CANCELADO` é imutável e não pode ser reaberto; após movimentação de estoque ou
  pagamento, o pedido é cancelado, nunca excluído.

## 11. Fluxo de status do pedido

O fluxo principal é `ABERTO` → `AGUARDANDO_APROVACAO` (pagamento aprovado) → `FINALIZADO`. Pagamento recusado
mantém o pedido em `ABERTO`. O cancelamento é permitido em `ABERTO` e `AGUARDANDO_APROVACAO`; com pagamento
aprovado, passa por `PROCESSANDO_REEMBOLSO`.

<p align="center"><img src="../assets/fluxo-pedido.png" alt="Fluxograma do pedido: rascunho, precheck de estoque, Salvar com reserva, pagamento, aprovação com baixa de estoque ou cancelamento com liberação da reserva ou abertura de reembolso" width="100%"><br><sub>Figura 3 — Fluxo do pedido de compra</sub></p>

| Origem | Destino | Permitido | Condição |
| --- | --- | --- | --- |
| (início) | `ABERTO` | Sim | Salvar o rascunho: registra, numera e reserva o estoque |
| `ABERTO` | `ABERTO` | Sim | Editar itens (ajusta a reserva) ou pagamento recusado |
| `ABERTO` | `AGUARDANDO_APROVACAO` | Sim | Pagamento aprovado |
| `AGUARDANDO_APROVACAO` | `FINALIZADO` | Sim | Aprovar pedido: baixa o estoque e gera snapshots |
| `ABERTO` | `CANCELADO` | Sim | Cancelar com motivo: libera a reserva e gera snapshots |
| `AGUARDANDO_APROVACAO` | `PROCESSANDO_REEMBOLSO` | Sim | Cancelar com pagamento aprovado: cria a solicitação de reembolso |
| `PROCESSANDO_REEMBOLSO` | `CANCELADO` | Sim | Reembolso aprovado; pagamento `DEVOLVIDO` |
| `PROCESSANDO_REEMBOLSO` | Status anterior | Sim | Reembolso rejeitado (motivo obrigatório) |
| `ABERTO` | `FINALIZADO` | Não | Aprovar exige pagamento aprovado |
| `CANCELADO` / `FINALIZADO` | Qualquer | Não | Pedido encerrado é imutável |

<p align="center"><img src="../assets/telas/pedidos/lista.png" alt="Lista de pedidos com número, cliente, status do pedido e do pagamento e total" width="80%"><br><sub>Figura 4 — Lista de pedidos</sub></p>

<p align="center"><img src="../assets/telas/pedidos/rascunho.png" alt="Pedido em rascunho com dois itens criados inline" width="80%"><br><sub>Figura 5 — Pedido em rascunho com itens inline</sub></p>

## 12. Reserva, baixa, liberação e concorrência de estoque

### 12.1 Registro do pedido e reserva (Save do rascunho)

1. Validar cliente ativo e endereço principal.
2. Validar itens ativos, quantidades maiores que zero e ao menos um item.
3. Pré-validar a disponibilidade no Prepare; a validação definitiva ocorre sob lock no BO Item.
4. Ativar o rascunho: o pedido passa a `ABERTO` e recebe o número.
5. Fixar o preço unitário dos itens e calcular o total do pedido.
6. Incrementar QtdeReservada dos itens e recalcular o status de estoque.
7. Em qualquer falha, reprovar o Save sem gravar alterações.

### 12.2 Edição dos itens do pedido `ABERTO`

- Editar cria um rascunho com os itens atuais; o cliente é somente leitura.
- Ao salvar, a reserva é recalculada pela diferença entre o que o pedido já reservou e os itens do rascunho:
  reserva só o acréscimo e libera só o excedente.
- A remoção de item deve liberar a sua reserva na implementação adicional de `Activate`, porque remover não
  dispara determination.
- Quantidade acima do disponível (considerando o que o próprio pedido já reservou) bloqueia o Save.

### 12.3 Aprovação

1. Validar status `AGUARDANDO_APROVACAO` e pagamento aprovado.
2. Reduzir QtdeEstoque e QtdeReservada pela quantidade do pedido e recalcular o status de estoque.
3. Gerar os snapshots do cliente e dos itens, preencher DataFinalizacao e mudar o status para `FINALIZADO`.

### 12.4 Cancelamento

1. Validar se o status permite cancelamento e exigir o motivo.
2. Com pagamento aprovado, abrir a solicitação de reembolso (seção 13) e encerrar aqui.
3. Sem pagamento aprovado: liberar a reserva, gerar os snapshots (se ainda não existirem), preencher motivo,
   data e usuário e mudar o status para `CANCELADO`.

### 12.5 Controle de concorrência

- Operações sobre QtdeEstoque e QtdeReservada devem ocorrer em transação, com o item bloqueado e relido no
  banco; valores de estoque vindos da UI não são confiáveis.
- Entre dois registros simultâneos para o mesmo item, só o primeiro com disponibilidade prossegue; o segundo
  recebe erro de estoque insuficiente ou de concorrência.
- Item em edição na aplicação de Estoque (draft) impede o registro do pedido.
- Registro, aprovação, cancelamento e decisão de reembolso não podem gerar dupla reserva, dupla baixa ou
  dupla liberação.

## 13. Reembolso de pedidos

<p align="center"><img src="../assets/fluxo-reembolso.png" alt="Fluxograma do reembolso: cancelar pedido com pagamento aprovado, solicitação PENDENTE, pedido em PROCESSANDO_REEMBOLSO, aprovar ou rejeitar" width="100%"><br><sub>Figura 6 — Fluxo de reembolso</sub></p>

- **Solicitação**: cancelar um pedido com pagamento aprovado cria o reembolso `PENDENTE` (com o status anterior
  e o motivo) e move o pedido para `PROCESSANDO_REEMBOLSO`, mantendo a reserva.
- **Aprovar**: libera a reserva, gera os snapshots, cancela o pedido, muda o pagamento para `DEVOLVIDO` e grava
  o reembolso como `APROVADO`, na mesma LUW.
- **Rejeitar**: exige o motivo da decisão, devolve o pedido ao status anterior, limpa o motivo de cancelamento
  e grava o reembolso como `REJEITADO`.
- A decisão de um reembolso que não está `PENDENTE` deve ser bloqueada.

<p align="center"><img src="../assets/telas/pedidos/cancelamento.png" alt="Diálogo Cancelar pedido com o motivo" width="80%"><br><sub>Figura 7 — Cancelamento de pedido pago (motivo obrigatório)</sub></p>

<p align="center"><img src="../assets/telas/reembolsos/pendente.png" alt="Solicitação de reembolso pendente na aplicação Gestão de Reembolsos" width="80%"><br><sub>Figura 8 — Solicitação de reembolso pendente</sub></p>

<p align="center"><img src="../assets/telas/reembolsos/aprovacao.png" alt="Diálogo Aprovar reembolso com o motivo da decisão" width="80%"><br><sub>Figura 9 — Decisão do reembolso</sub></p>

<p align="center"><img src="../assets/telas/pedidos/cancelado.png" alt="Pedido cancelado pelo reembolso aprovado, com pagamento devolvido e snapshot do cliente" width="80%"><br><sub>Figura 10 — Pedido cancelado pelo reembolso aprovado</sub></p>

## 14. Pagamento simulado com cartão

- Os dados do cartão são coletados apenas no diálogo da action e usados só em memória.
- Nunca persistir número completo, CVV nem validade; gravar apenas método, status, bandeira, últimos 4 dígitos,
  cartão mascarado, código de autorização, mensagem e data.
- Cartões iniciados por 4 simulam VISA e por 5 simulam Mastercard; CVV `000` simula recusa.
- Dados em formato inválido (número com 13 a 19 dígitos, validade MM/AA não expirada, CVV com 3 ou 4 dígitos)
  geram erro `CARTAO_DADOS_INVALIDOS`, que não é recusa.
- Pagamento aprovado leva o pedido a `AGUARDANDO_APROVACAO`; recusado mantém `ABERTO` e permite nova tentativa.
- Apenas a última tentativa é mantida.
- Em cenário real, a captura deve usar componente dedicado ou tokenização do provedor de pagamento, porque os
  parâmetros de action aparecem sem máscara no Fiori Elements.

<p align="center"><img src="../assets/telas/pedidos/pagamento.png" alt="Diálogo da action Efetuar Pagamento" width="80%"><br><sub>Figura 11 — Diálogo Efetuar Pagamento</sub></p>

<p align="center"><img src="../assets/telas/pedidos/itens-pagamento.png" alt="Itens, pagamento aprovado com cartão mascarado e finalização" width="80%"><br><sub>Figura 12 — Pagamento aprovado com cartão mascarado</sub></p>

## 15. Cálculos do pedido

- Total do item = QtdeItemPedido × PrecoUnitarioSnapshot; total do pedido = soma dos totais dos itens.
- QtdeItemPedido > 0; PrecoUnitarioSnapshot ≥ 0; QtdeEstoque ≥ 0; 0 ≤ QtdeReservada ≤ QtdeEstoque.
- O total é provisório no draft e definitivo no registro; todos os cálculos definitivos ocorrem no backend.

## 16. Endereço e integração com o ViaCEP

<p align="center"><img src="../assets/fluxo-endereco-viacep.png" alt="Fluxograma do endereço: informar o CEP, reaproveitar CEP cadastrado ou consultar o ViaCEP, side effects, Salvar e validações" width="100%"><br><sub>Figura 13 — Endereço e consulta de CEP</sub></p>

### 16.1 Requisitos funcionais

- A consulta é feita no backend; na UI, o CEP é um campo padrão do Fiori Elements, com máscara `99999-999` e
  value help dos CEPs já cadastrados.
- Ao informar o CEP, uma determination reaproveita os dados de um CEP já cadastrado e só chama o ViaCEP para
  CEPs desconhecidos; side effects recarregam os campos do endereço.
- A chamada HTTP não deve ocorrer na fase de save: a determination grava o resultado da consulta e a
  validation apenas o avalia.
- Um CEP novo passa a ser sugerido pelo value help depois de gravado.
- O CEP é campo adicional da chave da tabela de endereços e fica somente leitura depois de gravado.

### 16.2 Requisitos da classe de integração

- Higienizar e validar o CEP, manter cache por sessão (até 100 entradas), distinguir CEP inválido de serviço
  indisponível, reconhecer CEP geral de município e fechar o cliente HTTP também em caso de erro.
- Extrair os campos do JSON sem APIs não liberadas.
- Manter a mesma interface pública nas duas implementações, para que o behavior pool não mude.

### 16.3 Conectividade por ambiente

| Aspecto | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| API HTTP | `CL_HTTP_DESTINATION_PROVIDER` + `CL_WEB_HTTP_CLIENT_MANAGER` | `CL_HTTP_CLIENT` (Standard ABAP) |
| Destino | URL no código (Trial) ou Communication Scenario + Arrangement (produção) | Destination HTTP tipo G `Z_VIACEP` na `SM59`: host `viacep.com.br`, porta 443, SSL ativo, sem logon |
| Confiança TLS | Gerenciada pela SAP | PSE *SSL Client (Anonymous)* no `STRUST` com a cadeia da autoridade certificadora do ViaCEP |
| Rede | Gerenciada pela SAP | Proxy e regra de firewall para `viacep.com.br:443` |
| Teste | Determination pela própria aplicação | Report de teste da destination e *Connection Test* da `SM59` |
| Manutenção | — | Destination, certificados e rede mantidos em cada sistema pela equipe de Basis |

<p align="center"><img src="../assets/telas/clientes/endereco-viacep.png" alt="Endereço do CEP 01310-100 preenchido pelo ViaCEP" width="80%"><br><sub>Figura 14 — Endereço preenchido pelo ViaCEP</sub></p>

## 17. Importação em massa por planilha

<p align="center"><img src="../assets/fluxo-importacao.png" alt="Fluxograma da importação: escolher o arquivo, action ImportarPlanilha, leitura, normalização, validação de todas as linhas e criação por EML" width="100%"><br><sub>Figura 15 — Importação em massa por planilha</sub></p>

| Aplicação | Linha da planilha | Colunas (obrigatórias em **negrito**) |
| --- | --- | --- |
| Clientes | Um cliente com o endereço principal | **CPF**, **Nome**, **E-mail**, **Telefone**, Gênero, **Data de nascimento**, **CEP**, **Número**, Complemento |
| Estoque | Um item | **Nome**, Descrição, **Categoria**, **Quantidade em estoque**, **Preço unitário**, Moeda |
| Pedidos | Um item de um pedido | **Pedido** (referência), **CPF**, **SKU**, **Quantidade**, Observação |

- A importação deve ser uma action estática com parâmetro `deep` (arquivo como `@Semantics.largeObject`),
  exposta como botão na lista das três aplicações.
- Formatos `.xlsx` (primeira aba) e `.csv` (separador e codificação detectados); máximo de 500 linhas.
- Cabeçalho na primeira linha não vazia, com nomes comparados sem acentos, maiúsculas, espaços ou pontuação.
- **Tudo ou nada**: todas as linhas são validadas antes de gravar; com qualquer erro, nada é gravado e o
  usuário recebe a lista de erros por linha.
- As instâncias são criadas por EML, então valem as mesmas determinations e validations da tela.
- Pedidos importados nascem `ABERTO`, com estoque reservado; a referência do pedido é a chave de
  idempotência: a mesma referência para o mesmo cliente é recusada enquanto houver pedido não cancelado com ela.
- A importação só cria registros, não atualiza.

## 18. Interface do usuário — SAP Fiori Elements

As quatro aplicações de gestão usam List Report + Object Page (OData V4), geradas com o SAP Fiori tools. A UI
deve ser orientada a anotações: colunas, filtros, seções, ações e criticidade vêm das metadata extensions do
backend; as aplicações guardam só o `manifest.json` (rotas, tabelas e tile) e a configuração das ferramentas.

<p align="center"><img src="../assets/telas/launchpad/inicio.png" alt="Launchpad com os oito tiles: quatro de gestão e quatro de análise" width="80%"><br><sub>Figura 16 — Launchpad com as oito aplicações</sub></p>

### 18.1 Listas e filtros

| Aplicação | Campos na lista | Filtros |
| --- | --- | --- |
| Gestão de Clientes | CPF, Nome, E-mail, Telefone, Ativo, Cidade, UF, Data de cadastro | Nome, CPF, E-mail, Ativo, Cidade, UF |
| Gestão de Estoque | SKU, Nome, Categoria, Qtde em estoque, reservada e disponível, Status, Preço, Ativo | SKU, Nome, Categoria, Status, Ativo, Qtde disponível |
| Pedidos de Compras | Número, CPF, Cliente, Status do pedido, Status do pagamento, Total, Data do pedido, Data de finalização | Cliente, CPF, Status, Pagamento, Data, Valor total |
| Gestão de Reembolsos | Pedido, Cliente, Status, Valor, Motivo da solicitação, Solicitado em, Motivo da decisão | Pedido, Cliente, Status |

### 18.2 Ações por aplicação

| Object Page | Ações | Regras |
| --- | --- | --- |
| Cliente | Editar, Excluir, Definir endereço principal, Importar planilha | Escrita só para administrador |
| Estoque | Editar, Excluir, Importar planilha | Escrita só para administrador |
| Pedido | Efetuar Pagamento, Aprovar pedido, Cancelar pedido (agrupadas no menu "Ações"), Importar planilha | Por status e perfil, só na instância ativa; sem Excluir; Editar só em `ABERTO` |
| Reembolso | Aprovar reembolso, Rejeitar reembolso | Só solicitações `PENDENTE`; sem criar, editar ou excluir |

### 18.3 Apresentação

- Campos de cliente, endereço e item mostram o texto descritivo, sem o UUID técnico.
- Códigos de CodeList aparecem só como texto, com criticidade nos status.
- Score do cliente em %, como *Process Indicator*: vermelho até 40, amarelo de 40 a 70, verde a partir de 70.
- Fotos de cliente e item na Object Page; cliente sem foto mostra um avatar.
- Itens do pedido são criados *inline* na tabela do rascunho.

### 18.4 Object Page dinâmica do pedido

- Seções na ordem: Dados do Cliente, Dados do Pedido (com os campos administrativos), Itens, Pagamento e
  Finalização ou Cancelamento.
- Finalização e Cancelamento aparecem só nos status correspondentes, ocultas por expressão de anotação
  (`hidden`) sobre indicadores persistidos do pedido.
- Em `FINALIZADO` ou `CANCELADO`, cliente e itens vêm dos snapshots; nos demais status, das tabelas principais.
- Pagamento e snapshot do cliente (composições `[0..1]`) são exibidos como formulário.

<p align="center"><img src="../assets/telas/pedidos/finalizado.png" alt="Pedido finalizado com o snapshot do cliente" width="80%"><br><sub>Figura 17 — Object Page do pedido finalizado</sub></p>

### 18.5 Telas das demais aplicações

<p align="center"><img src="../assets/telas/clientes/lista.png" alt="Lista de clientes" width="80%"><br><sub>Figura 18 — Gestão de Clientes: lista</sub></p>

<p align="center"><img src="../assets/telas/clientes/cliente.png" alt="Object Page do cliente com score e endereços" width="80%"><br><sub>Figura 19 — Gestão de Clientes: Object Page</sub></p>

<p align="center"><img src="../assets/telas/estoque/lista.png" alt="Lista de itens de estoque" width="80%"><br><sub>Figura 20 — Gestão de Estoque: lista</sub></p>

<p align="center"><img src="../assets/telas/estoque/item.png" alt="Object Page do item com SKU gerado no Save" width="80%"><br><sub>Figura 21 — Gestão de Estoque: Object Page</sub></p>

<p align="center"><img src="../assets/telas/reembolsos/lista.png" alt="Lista de reembolsos" width="80%"><br><sub>Figura 22 — Gestão de Reembolsos: lista</sub></p>

## 19. Camada analítica

<p align="center"><img src="../assets/fluxo-analises.png" alt="Fluxograma dos apps de análise: catálogo do domínio, $apply com filter, groupby e aggregate, agregação no servidor, painel e detalhe" width="100%"><br><sub>Figura 23 — Apps de análise</sub></p>

- Camada somente leitura e independente das aplicações de gestão: um cubo (`ZI_PC_*_CUBE`) e uma consulta
  (`ZC_PC_*_ANALISE`) por domínio, com `@Aggregation.default` nas medidas e
  `@OData.applySupportedForAggregation: #FULL`, publicados no serviço `ZUI_PC_ANALITICO`.
- Quatro aplicações SAPUI5 freestyle, uma por domínio, com 5 análises cada: painel com filtros, indicadores e
  gráficos, e uma página de detalhe por análise (troca do tipo de gráfico e tabela de valores).
- As consultas usam `$apply` (filter, groupby, aggregate) com agregação no servidor; os filtros valem para os
  indicadores e todos os gráficos.

| Aplicação | Entity set | Tile | Filtros | Análises |
| --- | --- | --- | --- | --- |
| Análise de Pedidos de Compras | `PedidoAnalise` | `ZPCAnalisePedido-display` | Status, pagamento, UF, mês | Valor por status, pedidos por mês, valor por UF, por pagamento, ticket médio |
| Análise de Clientes | `ClienteAnalise` | `ZPCAnaliseCliente-display` | Gênero, ativo, UF, faixa de score, nome | Por gênero, por UF, por faixa de score, cadastros por mês, score por UF |
| Análise de Itens do Estoque | `ItemAnalise` | `ZPCAnaliseItemEstoque-display` | Categoria, situação, nome, SKU | Disponível por categoria, itens por situação, valor por categoria, mais reservados, itens por categoria |
| Análise de Pedidos de Reembolsos | `ReembolsoAnalise` | `ZPCAnaliseReembolso-display` | Status, UF, mês | Valor e quantidade por status, valor por mês, valor por UF, por motivo |

<p align="center"><img src="../assets/telas/analises/pedidos.png" alt="Painel da Análise de Pedidos de Compras" width="80%"><br><sub>Figura 24 — Painel da Análise de Pedidos de Compras</sub></p>

<p align="center"><img src="../assets/telas/analises/detalhe.png" alt="Detalhe da análise Valor dos reembolsos por status" width="80%"><br><sub>Figura 25 — Página de detalhe de uma análise</sub></p>

## 20. Actions, validations e determinations

| Domínio | Artefato RAP | Requisito |
| --- | --- | --- |
| Clientes | Validations de CPF, dados, e-mail, telefone, nascimento, gênero e foto | Bloqueiam o Save com a mensagem correspondente |
| Clientes | Feature control + precheck do delete | Bloqueia exclusão de cliente com pedido (ativo ou em draft) |
| Endereços | Action `DefinirEnderecoPrincipal` | Define o principal e desmarca os demais |
| Endereços | Determination `PreencherEnderecoViaCep` | Preenche o endereço a partir do CEP |
| Endereços | Validations `ValidarCep`, `ValidarCepUnico`, `ValidarNumero` | CEP válido e único por cliente; número obrigatório |
| Endereços | Feature control do campo Cep | Obrigatório no cadastro, somente leitura depois de gravado |
| Estoque | Determination `GerarSku` (on save, também no Prepare) | SKU único com o prefixo da categoria |
| Estoque | Determination `RecalcularStatusEstoque` | Disponível e status conforme a quantidade |
| Estoque | Validations `ValidarItem`, `ValidarQuantidades`, `ValidarInativacaoItem`, `ValidarSkuUnico`, `ValidarFoto` | Dados, quantidades, inativação, unicidade e foto |
| Estoque | Actions internas `ReservarEstoque`, `LiberarReserva`, `BaixarEstoque` | Movimentam o estoque sob lock; só o BO Pedido as chama |
| Pedidos | Validation `ValidarRegistro` + determination `ReservarEstoqueRegistro` | Registro com reserva pela diferença |
| Pedidos | Draft action `Activate` com implementação adicional | Libera a reserva de itens removidos |
| Pedidos | Determinations `DefinirStatusInicial`, `GerarNumeroPedido`, `AtualizarEndereco`, `CalcularTotalPedido`, `CalcularValorItem`, `AtualizarFlagsStatus` | Status inicial, número, endereço, totais e indicadores de status |
| Pedidos | Validations `ValidarCliente`, `ValidarItemPedido` | Cliente ativo; item ativo com quantidade maior que zero |
| Pedidos | Precheck da inclusão de item | Bloqueia item sem estoque disponível |
| Pedidos | Action `SimularPagamento` (Efetuar Pagamento) | Pagamento fictício sem dados sensíveis |
| Pedidos | Action `AprovarPedido` | Baixa o estoque, gera snapshots e finaliza |
| Pedidos | Action `CancelarPedido` | Cancela ou abre a solicitação de reembolso |
| Pedidos | Actions internas `CancelarPorReembolso`, `RetomarPedido`, `RecalcularTotal` | Chamadas pelo BO Reembolso ou pelo próprio BO |
| Reembolsos | Actions `AprovarReembolso`, `RejeitarReembolso` | Decidem a solicitação `PENDENTE` na mesma LUW |
| Todos | Action estática `ImportarPlanilha` | Importação em massa (seção 17) |

## 21. Mensagens de erro e sucesso

As mensagens devem ficar numa Message Class (`ZPC_MSG`, textos com até 73 caracteres) e ser expostas por uma
classe de exceção que implemente `IF_ABAP_BEHV_MESSAGE` (`ZCX_PC_MSG`). As chaves de cada mensagem ficam numa
interface própria (`ZIF_PC_MSG`, constantes com até 30 caracteres), implementada pela classe de exceção, junto
com os atributos das variáveis `&1` a `&4` e os métodos de atalho; só o construtor fica na classe.

| Código | Mensagem |
| --- | --- |
| CLIENTE_CPF_INVALIDO | CPF inválido. Verifique o número informado. |
| CLIENTE_CPF_DUPLICADO | Já existe um cliente cadastrado com este CPF. |
| CLIENTE_INATIVO | Cliente inativo não pode realizar pedido. |
| CLIENTE_COM_PEDIDO | Cliente não pode ser excluído pois possui pedido vinculado. |
| CLIENTE_SEM_ENDERECO_PRINCIPAL | Cliente selecionado não possui endereço principal válido. |
| CEP_INDISPONIVEL | Não foi possível validar o CEP agora. Tente novamente em instantes. |
| CEP_INVALIDO | CEP inválido ou não encontrado. Verifique o número informado. |
| CEP_DUPLICADO_CLIENTE | Já existe um endereço cadastrado com este CEP para este cliente. |
| ENDERECO_NUMERO_OBRIGATORIO | Número do endereço é obrigatório. |
| FOTO_FORMATO_INVALIDO | Formato de imagem inválido. Utilize JPEG, PNG ou WEBP. |
| CAMPO_OBRIGATORIO | Campo &1 é obrigatório. |
| EMAIL_INVALIDO | E-mail em formato inválido. |
| TELEFONE_INVALIDO | Telefone deve conter 10 ou 11 dígitos (DDD + número). |
| DATA_NASCIMENTO_FUTURA | Data de nascimento não pode ser futura. |
| ITEM_SKU_DUPLICADO | Já existe item cadastrado com este SKU. |
| ITEM_SEM_ESTOQUE | Item &1 está sem estoque disponível e não pode ser adicionado ao pedido. |
| ITEM_ESTOQUE_INSUFICIENTE | Estoque insuficiente para o item &1 (disponível: &2). |
| ITEM_ESTOQUE_CONCORRENTE | Estoque do item &1 alterado por outra operação. Atualize e tente de novo. |
| ITEM_INATIVO | Item &1 inativo não pode ser usado em novo pedido. |
| ITEM_INATIVACAO_BLOQUEADA | Item possui estoque disponível ou pedido ativo. Inativação bloqueada. |
| ITEM_EXCLUSAO_BLOQUEADA | Item não pode ser excluído pois está vinculado a pedido ou reserva. |
| ITEM_QTDE_INVALIDA | Quantidade do item deve ser maior que zero. |
| ITEM_PRECO_INVALIDO | Preço unitário deve ser maior ou igual a zero. |
| ITEM_QTDE_ESTOQUE_INVALIDA | Qtde em estoque não pode ser negativa nem menor que a reservada (&1). |
| ITEM_RESERVA_INCONSISTENTE | Reserva do item &1 inconsistente com o pedido. |
| PEDIDO_SEM_ITENS | Pedido deve possuir ao menos um item. |
| PEDIDO_STATUS_INVALIDO | Transição de status não permitida (status atual: &1). |
| PEDIDO_EDICAO_BLOQUEADA | Pedido só pode ser editado ou excluído no status ABERTO. |
| PEDIDO_PAGAMENTO_PENDENTE | Pagamento pendente. O pedido não pode ser finalizado. |
| PEDIDO_FINALIZADO_IMUTAVEL | Pedido finalizado não pode ser alterado. |
| PEDIDO_CANCELADO_IMUTAVEL | Pedido cancelado não pode ser alterado. |
| PEDIDO_MOTIVO_CANCEL_OBRIG | Informe o motivo do cancelamento. |
| PEDIDO_CONFIRMADO | Pedido &1 registrado. Estoque reservado. |
| PEDIDO_FINALIZADO | Pedido &1 finalizado com sucesso. |
| PEDIDO_CANCELADO | Pedido &1 cancelado. |
| PEDIDO_REEMBOLSO_SOLICITADO | Pedido &1 enviado para processamento de reembolso. |
| PAGAMENTO_APROVADO | Pagamento aprovado com sucesso. |
| PAGAMENTO_RECUSADO | Pagamento recusado. O pedido permanecerá aguardando pagamento. |
| CARTAO_DADOS_INVALIDOS | Dados do cartão inválidos: &1. |
| SNAPSHOT_EXISTENTE | Snapshot do pedido já foi gerado e não pode ser recriado. |
| REEMBOLSO_MOTIVO_DECISAO_OBRIG | Informe o motivo da decisão sobre o reembolso. |
| REEMBOLSO_APROVADO | Reembolso do pedido &1 aprovado. Pedido cancelado. |
| REEMBOLSO_REJEITADO | Reembolso do pedido &1 rejeitado. Pedido retomado. |
| REEMBOLSO_STATUS_INVALIDO | Solicitação de reembolso não está mais pendente. |
| NUMERACAO_ERRO | Erro ao obter numeração (&1). Verifique o intervalo de numeração. |
| SEM_AUTORIZACAO | Usuário sem autorização para esta operação. |
| VALOR_INVALIDO | Valor inválido para o campo &1. |
| TEXTO_LIVRE | &1&2&3&4 (mensagens longas da importação, divididas em variáveis de 50 caracteres) |

## 22. Critérios de aceite

### 22.1 Clientes

- Dado um administrador, quando cadastrar cliente com CPF válido e único, então o CPF é salvo só com números e
  exibido formatado.
- Dado um usuário comum, quando tentar criar, editar ou excluir cliente, então a operação é bloqueada.
- Dado um cliente com pedido, quando o administrador tentar excluí-lo, então a exclusão é bloqueada.
- Dado um cliente inativo, quando for usado num novo pedido, então o registro do pedido é bloqueado.
- Dado um endereço gravado, quando o usuário tentar alterar o CEP, então o campo está somente leitura.
- Dado um CEP já usado pelo mesmo cliente, quando outro endereço for salvo com ele, então o Save é bloqueado.

### 22.2 Estoque

- Dado um item salvo com categoria, então o SKU é gerado no Save com as 3 primeiras letras da categoria.
- Dado QtdeEstoque = 10 e QtdeReservada = 3, então QtdeDisponivel = 7.
- Dado QtdeDisponivel = 0, 1 a 10 ou ≥ 11, então o status é `SEM_ESTOQUE`, `ACABANDO` ou `EM_ESTOQUE`.
- Dados dois registros de pedido simultâneos para o mesmo item, então o segundo é bloqueado se o primeiro
  consumir a disponibilidade.

### 22.3 Pedidos

- Dado um rascunho, então nenhuma reserva é feita.
- Dado um rascunho válido, quando salvo, então o pedido fica `ABERTO` e o estoque é reservado.
- Dado um rascunho sem itens, sem endereço principal ou sem estoque suficiente, quando salvo, então o registro é
  bloqueado sem reserva gravada.
- Dado um pedido `ABERTO`, quando itens forem alterados, incluídos ou removidos, então a reserva reflete só a
  diferença.
- Dado um pagamento aprovado, então o pedido vai a `AGUARDANDO_APROVACAO`; recusado, permanece `ABERTO`.
- Dado um pedido `AGUARDANDO_APROVACAO`, quando aprovado, então o estoque é baixado, os snapshots gerados e o
  status muda para `FINALIZADO`.
- Dado um pedido sem pagamento aprovado, quando cancelado com motivo, então a reserva é liberada e o status
  muda para `CANCELADO`.
- Dado um pedido com pagamento aprovado, quando cancelado, então é criada uma solicitação `PENDENTE` e o status
  muda para `PROCESSANDO_REEMBOLSO`, mantendo a reserva.
- Dado um pedido encerrado, quando aberto, então cliente e itens vêm dos snapshots e nenhuma edição é possível.

### 22.4 Reembolsos

- Dada uma solicitação `PENDENTE`, quando aprovada, então o pedido é cancelado, a reserva liberada e o
  pagamento fica `DEVOLVIDO`.
- Dada uma solicitação `PENDENTE`, quando rejeitada sem motivo, então a ação é bloqueada; com motivo, o pedido
  retoma o status anterior.
- Dada uma solicitação já decidida, então Aprovar e Rejeitar não ficam disponíveis.

### 22.5 Importação

- Dada uma planilha com um erro em qualquer linha, então nada é gravado e o erro é listado com o número da linha.
- Dada a mesma planilha de pedidos importada duas vezes, então a segunda importação é recusada.

### 22.6 Ambientes e aplicações

- Dado o mesmo código-fonte, então ele ativa sem erros no SAP BTP, ABAP environment (pacotes ABAP for Cloud
  Development) e no SAP S/4HANA On-Premise (pacotes Standard ABAP), mudando só a classe de integração com o ViaCEP.
- Dado um administrador, quando acessar o launchpad, então vê os tiles das oito aplicações.
- Dado um usuário comum, quando acessar o launchpad, então vê Pedidos de Compras e as aplicações liberadas na
  sua role.
- Dado um usuário sem acesso ao serviço no On-Premise, então o serviço responde 403 (falta `S_START`).
- Dado um link de cliente ou item no pedido, quando clicado, então a aplicação de destino abre a Object Page.

## 23. Estrutura de pacotes

| Pacote | Conteúdo |
| --- | --- |
| `ZAVBS_PEDIDOS_COMPRAS` | Pacote principal (estrutura) |
| `ZAVBS_PC_COMMON` | Constantes, exceção e Message Class; classes utilitárias, de autorização, numeração, integração com o ViaCEP, leitura de planilha, importação, setup e reset; CodeLists; objeto de numeração e objetos de autorização; abstract entities de upload; serviço analítico |
| `ZAVBS_PC_CLIENTES` | Tabelas, CDS, BDEF, behavior pool e serviço do BO Cliente; value helps de cliente, endereço, CEP e gênero; classe de virtual elements; cubo e consulta de clientes |
| `ZAVBS_PC_ESTOQUE` | Tabelas, CDS, BDEF, behavior pool e serviço do BO Estoque; value helps de item, categoria e status; abstract entity de quantidade; cubo e consulta de estoque |
| `ZAVBS_PC_PEDIDOS` | Tabelas, CDS, BDEF, behavior pool e serviço do BO Pedido; abstract entities de cancelamento e retomada; value helps de status; cubo e consulta de pedidos |
| `ZAVBS_PC_PEDIDOS_PAGAMENTOS` | Entidade de pagamento, value helps de pagamento, abstract entity de pagamento e classe do pagamento simulado |
| `ZAVBS_PC_PEDIDOS_SNAPSHOTS` | Entidades e tabelas dos snapshots de cliente e itens |
| `ZAVBS_PC_REEMBOLSOS` | Tabela, CDS, BDEF, behavior pool e serviço do BO Reembolso; value help de status; abstract entity da decisão; cubo e consulta de reembolsos |

Versão de linguagem: ABAP for Cloud Development no SAP BTP, ABAP environment; Standard ABAP no On-Premise, com
camada de transporte. As aplicações de front-end (BSPs) ficam no pacote do domínio correspondente.

Os nomes acima usam o prefixo `ZAVBS` deste repositório, que é opcional (seção 4). Em outro projeto, a mesma
estrutura pode ser criada com o prefixo genérico sugerido: `ZPK_PEDIDOS_COMPRAS`, `ZPK_PC_COMMON`,
`ZPK_PC_CLIENTES`, `ZPK_PC_ESTOQUE`, `ZPK_PC_PEDIDOS` (com `ZPK_PC_PEDIDOS_PAGAMENTOS` e
`ZPK_PC_PEDIDOS_SNAPSHOTS`) e `ZPK_PC_REEMBOLSOS`. O código ABAP não referencia o nome dos pacotes; só o
descritor de deploy de cada aplicação (`ui5-deploy.yaml`) informa o pacote de destino da BSP.

## 24. Implantação e operação

### 24.1 Sequência de ativação

Tabelas ativas → CDS base e CodeLists → abstract entities e value helps → tabelas draft → projeções e metadata
extensions → behavior definitions → behavior pools → classes de apoio → cubos e consultas → service definitions
e bindings. O BO Reembolso e sua BDEF precisam estar ativos antes da behavior pool do Pedido, que cria
reembolsos por EML. Todas as tabelas e CDS devem ser ativadas antes dos behavior pools, por causa das
dependências cruzadas.

### 24.2 Objetos criados manualmente

| Objeto | SAP BTP, ABAP environment | SAP S/4HANA On-Premise | Requisito |
| --- | --- | --- | --- |
| Message Class `ZPC_MSG` | ADT | ADT ou `SE91` | Mensagens da seção 21 |
| Domínio `ZPC_NR_NUMC10` | ADT | ADT ou `SE11` | NUMC 10, *Number Length Domain* |
| Objeto de numeração `ZPC_NR` | Editor do ADT | `SNRO` | Buffer em memória com mais de zero números; intervalos 01 (pedido) e 02 (SKU) |
| Objetos `ZPC_ADMIN`, `ZPC_PEDIDO` | ADT (classe `CPAE`) | `SU21` (classe `ZPC`) | Atividades da seção 6.1 |
| Índices secundários | ADT | ADT ou `SE11` | CPF e SKU únicos; `ITEM_UUID` e `CLIENTE_UUID` para desempenho |
| Segurança | IAM Apps, Business Catalogs, Business Roles | `SU24`, roles `PFCG` | Seção 6.2 |
| Conectividade ViaCEP | Communication Arrangement (produção) | `SM59`, `STRUST`, proxy | Seção 16.3 |

O buffer do objeto de numeração é obrigatório: sem ele, a obtenção de número faz atualização síncrona, proibida
numa transação RAP.

### 24.3 Publicação e front-end

- Publicar os cinco service bindings (ADT; no On-Premise também `/IWFND/V4_ADMIN`, como grupos de serviços).
- Publicar as oito aplicações no ABAP repository como BSPs (`ZPC_CLIENTES`, `ZPC_ESTOQUE`, `ZPC_PEDIDOS`,
  `ZPC_REEMBOLSOS`, `ZPC_ANL_PEDIDOS`, `ZPC_ANL_CLIENTE`, `ZPC_ANL_ESTOQUE`, `ZPC_ANL_REEMB`). No BTP o deploy
  gera também a IAM App da aplicação; no On-Premise exige ordem de transporte.
- Launchpad — BTP: tiles no SAP Build Work Zone ou catálogos e espaços do ABAP environment. On-Premise: catálogo
  técnico em `/UI2/FLPAM` (tile + target mapping por aplicação, com os intents dos manifests), catálogos de
  negócio, espaço e página em `/UI2/FLPCM_CUST`, incluídos nas roles.
- O sistema deve oferecer SAPUI5 1.136 ou superior.

### 24.4 Carga inicial

- Uma classe de setup deve criar os intervalos de numeração, carregar as CodeLists e, opcionalmente, dados de
  demonstração.
- No On-Premise, o setup com dados de demonstração só roda em DEV e QAS; em PRD, os intervalos são criados na
  `SNRO` e as CodeLists são transportadas.
- A classe de reset dos dados só pode executar com o modo de demonstração ligado.

### 24.5 Transporte (On-Premise)

| Objeto | Transporte |
| --- | --- |
| Fontes ABAP, tabelas, CDS, BDEF, serviços, BSPs, `SU21`, `SU24` | Ordem Workbench |
| Roles `PFCG` e conteúdo do launchpad | Workbench ou Customizing |
| Publicação dos grupos de serviços | Customizing ou manual em cada sistema |
| `SM59`, `STRUST`, proxy e firewall | Manual em cada sistema |
| Usuários e atribuição de roles | Não transportados |

## 25. Testes automatizados

- As classes de teste ABAP Unit devem ser permanentes, versionadas junto com o código e ajustadas a cada mudança
  das funcionalidades que cobrem.
- Devem cobrir: validações de CPF, telefone, e-mail e imagem; status de estoque; registro do pedido com reserva;
  edição de itens com reserva incremental; pagamento aprovado e recusado; aprovação e cancelamento; reembolso
  aprovado e rejeitado; geração de SKU; persistência de endereços; pagamento simulado; leitura de planilhas e
  as três importações, inclusive a reimportação.
- Os testes de integração devem semear os próprios dados e usar test doubles (`cl_cds_test_environment`,
  `cl_osql_test_environment`) quando precisarem de `COMMIT ENTITIES`.
- Os testes de autorização devem usar `CL_AUNIT_AUTHORITY_CHECK`, sem depender das roles de quem executa.
- No front-end: testes OPA5 gerados pelo SAP Fiori tools nas aplicações Fiori Elements e QUnit nas análises.
- Os mesmos testes devem passar nos dois ambientes; no On-Premise, o ATC deve rodar sem erros antes da
  liberação das ordens.

## 26. Considerações de segurança

- Controle de acesso por authorization control RAP, configurado por ambiente (seção 6).
- Validações e cálculos críticos sempre no backend; a aplicação não confia em valores da UI.
- Dados sensíveis de cartão nunca persistidos nem exibidos.
- Pedido encerrado e snapshots são imutáveis; preferir inativação a exclusão.
- Operações de estoque transacionais e com bloqueio.
- Uploads de imagem e planilha validados (tipo, extensão e conteúdo; planilhas com até 500 linhas).
- Modo de demonstração desligado fora do BTP Trial.
- No On-Premise: validação TLS sempre ativa, confiança em autoridades certificadoras (não no certificado final),
  destination em vez de URL fixa e nenhum dado de infraestrutura exposto ao usuário.

## 27. Restrições técnicas

- **Release mínimo**: a solução usa `strict ( 2 )`, `Activate` com implementação adicional, `hidden` com
  expressão de anotação em facets, action estática com parâmetro `deep` e `@Semantics.largeObject`; no
  On-Premise, o release de referência é o SAP S/4HANA 2025.
- **SAPUI5**: as aplicações exigem SAPUI5 1.136 ou superior (descriptor v2).
- **Ocultar seções** da Object Page exige indicadores persistidos, porque `hidden` aceita só expressão sobre
  campo da própria entidade.
- **CEP na chave da tabela**: como o CEP é chave da tabela mas não da entidade, ele não pode ser alterado depois
  de gravado; mudar a chave de uma tabela implantada exige recriá-la.
- **Imagem no List Report**: as fotos são exibidas na Object Page.
- **Leitor de XLSX**: a biblioteca XCO não lê arquivos salvos pelo LibreOffice nem textos *inline*; nesses casos
  a importação deve orientar o uso de `.csv`. Arquivos `.xls` não são aceitos.
- **Limites de nomes**: tabelas com até 16 caracteres; CDS, classes e constantes de mensagem com até 30;
  textos de mensagem com até 73; variáveis de mensagem com até 50.
- **Conectividade On-Premise**: a integração com o ViaCEP usa API clássica (`CL_HTTP_CLIENT`), permitida em
  Standard ABAP e revisada a cada upgrade; para ABAP Cloud, usa-se a versão com destination provider.
