# Pedidos de Compras — Especificação Técnica

**SAP RAP · ABAP Cloud e On-Premise · SAP Fiori Elements** — versão **2.4** (Markdown)

| Item | Valor |
| --- | --- |
| Cenário principal | SAP BTP, ABAP environment (ABAP Cloud; Trial, software component `ZLOCAL`) — código em [`abap/`](../abap) |
| Cenário alternativo | SAP S/4HANA 2025 FPS01 On-Premise (ABAP Platform 2025, pacotes *Standard ABAP*) — mesmo código; diferenças em [`abap/README.md`](../abap/README.md) e na [seção 26](#26-implementação-no-cenário-on-premise-sap-s4hana-2025-fps01) |
| Diagramas | [`diagramas/pedidos-de-compras.drawio`](../diagramas/README.md): um arquivo, uma página por diagrama (arquitetura, fluxos e arquitetura On-Premise) |
| Versão anterior | [`Pedidos_de_Compras_-_Especificacao_Tecnica_v2.docx`](Pedidos_de_Compras_-_Especificacao_Tecnica_v2.docx) (v2.2, Word) |

<p align="center">
  <a href="../assets/arquitetura.png"><img src="../assets/arquitetura.png" alt="Arquitetura no SAP BTP, ABAP environment: usuários, ferramentas de desenvolvimento, apps (BSP), serviços OData V4, BOs RAP, camada analítica, SAP HANA e a API ViaCEP" width="80%"></a>
</p>

## Sumário

1. [Objetivo](#1-objetivo)
2. [Escopo do Projeto](#2-escopo-do-projeto)
3. [Tecnologias e Arquitetura](#3-tecnologias-e-arquitetura)
4. [Padrão de Nomenclatura RAP](#4-padrão-de-nomenclatura-rap)
5. [Perfis de Usuário e Permissões](#5-perfis-de-usuário-e-permissões)
6. [Autenticação e Autorização](#6-autenticação-e-autorização)
7. [Modelo de Dados](#7-modelo-de-dados)
8. [Business Objects RAP](#8-business-objects-rap)
9. [Comunicação entre as Aplicações](#9-comunicação-entre-as-aplicações)
10. [Regras de Negócio](#10-regras-de-negócio)
11. [Fluxo de Status do Pedido](#11-fluxo-de-status-do-pedido)
12. [Reserva, Baixa, Liberação e Concorrência de Estoque](#12-reserva-baixa-liberação-e-concorrência-de-estoque)
13. [Pagamento Simulado com Cartão](#13-pagamento-simulado-com-cartão)
14. [Cálculos do Pedido](#14-cálculos-do-pedido)
15. [Interface do Usuário — SAP Fiori Elements](#15-interface-do-usuário--sap-fiori-elements)
16. [Actions, Validations e Determinations RAP](#16-actions-validations-e-determinations-rap)
17. [Mensagens de Erro e Sucesso](#17-mensagens-de-erro-e-sucesso)
18. [Critérios de Aceite](#18-critérios-de-aceite)
19. [Estrutura Recomendada do Projeto RAP](#19-estrutura-recomendada-do-projeto-rap)
20. [Deploy e Operação](#20-deploy-e-operação)
21. [Considerações de Segurança](#21-considerações-de-segurança)
22. [Conclusão](#22-conclusão)
23. [Histórico de Revisões e Correções Técnicas](#23-histórico-de-revisões-e-correções-técnicas)
24. [Camada Analítica](#24-camada-analítica)
25. [Testes Automatizados](#25-testes-automatizados)
26. [Implementação no cenário On-Premise (SAP S/4HANA 2025 FPS01)](#26-implementação-no-cenário-on-premise-sap-s4hana-2025-fps01)

---

# 1. Objetivo

Construir uma solução educacional de pedidos de compras utilizando o SAP RAP (ABAP RESTful Application Programming Model) e o SAP Fiori Elements, implementável tanto no SAP BTP, ABAP environment (ABAP Cloud) quanto num SAP S/4HANA On-Premise, organizada em quatro aplicações desacopladas: Gestão de Clientes, Gestão de Estoque, Pedidos de Compras e Gestão de Reembolsos.

A solução deverá preservar o escopo funcional da especificação original, contemplando cadastro de clientes, endereços, itens de estoque, criação de pedidos em draft, registro do pedido com reserva de estoque, pagamento simulado, aprovação/finalização, cancelamento (com solicitação e decisão de reembolso quando o pagamento já foi aprovado), liberação de reserva, baixa de estoque e snapshots históricos imutáveis.

O projeto foi desenvolvido primeiro no SAP BTP ABAP Environment Trial e pode ser reproduzido num SAP S/4HANA On-Premise com o mesmo código (seção 26). Nos dois ambientes ele utiliza CDS View Entities, Behavior Definitions, Behavior Implementations, Service Definitions e Service Bindings OData V4 UI; a configuração de acesso usa IAM Apps, Business Catalogs e Business Roles no BTP e objetos SU21, valores SU24 e roles PFCG no On-Premise.

Fora do objetivo principal permanecem gestão logística, envio, frete real, rastreamento de entrega, integração real com gateway de pagamento, auditoria produtiva avançada e uso por clientes reais.

Esta é a versão 2.3 da especificação: a revisão técnica 2.0 para ABAP Cloud (strict mode 2), alinhada ao código-fonte, acrescida das alterações das seções 23 a 26 (v2.1: Reembolso como aplicação própria, registro do pedido com reserva automática de estoque, SKU gerado no Save; v2.2: novo modelo de status do pedido, edição dos itens do pedido aberto com reserva incremental, Object Page dinâmica, camada analítica e suíte permanente de testes; v2.3: documento em Markdown, camada analítica com os quatro apps freestyle e o cenário de implementação On-Premise no SAP S/4HANA 2025 FPS01; v2.4: projeto orientado aos dois ambientes, com pacotes Standard ABAP no On-Premise).

# 2. Escopo do Projeto

## 2.1 Incluído no Escopo

- Aplicação independente para Gestão de Clientes, com cadastro, consulta, edição, ativação, inativação e exclusão controlada.
- Cadastro de múltiplos endereços por cliente, com controle para manter apenas um endereço principal.
- Validação de CEP e preenchimento automático de endereço via serviço ViaCEP, quando disponível no ambiente de execução.
- Aplicação independente para Gestão de Estoque, com cadastro, consulta, edição, exclusão controlada e inativação controlada de itens.
- Controle de estoque com quantidade total, quantidade reservada e quantidade disponível calculada.
- Aplicação independente para Pedidos de Compras, consumindo dados de clientes e itens por views reutilizáveis, value helps e associações.
- Criação de pedidos em draft, sem reserva de estoque enquanto for rascunho.
- Edição dos itens do pedido ABERTO (Editar + Salvar): incluir, remover ou alterar a quantidade de um item ajusta a reserva de estoque pela diferença; o cliente do pedido não pode ser trocado.
- Object Page do pedido dinâmica: seções Dados do Cliente, Dados do Pedido, Itens, Pagamento e Finalização/Cancelamento, exibidas conforme o status; cliente e itens vêm dos snapshots quando o pedido está FINALIZADO ou CANCELADO.
- Registro do pedido ao salvar o rascunho (Save), com validação, cálculo de total, fixação de preço e reserva automática de estoque dos itens — não há action de confirmação.
- Pagamento simulado com cartão de crédito ou débito (action Efetuar Pagamento), sem persistência de dados sensíveis.
- Nova tentativa de pagamento em caso de recusa, mantendo apenas a última tentativa segura.
- Aprovação do pedido (action Aprovar pedido) com baixa de estoque, geração de snapshots, finalização e imutabilidade do histórico.
- Cancelamento de pedido com motivo obrigatório, liberação de reserva e geração de snapshots; quando o pagamento já foi aprovado, o cancelamento abre uma solicitação de reembolso (status PROCESSANDO_REEMBOLSO) que é decidida na aplicação Gestão de Reembolsos.
- Aplicação independente de Gestão de Reembolsos (List Report próprio) com as actions Aprovar reembolso (cancela o pedido) e Rejeitar reembolso (o pedido retoma o status anterior; motivo obrigatório).
- Separação de serviços, bindings, catálogos e tiles para as quatro aplicações Fiori Elements.
- Controle de acesso por perfil comum e administrador via authorization control RAP, configurado com IAM Apps e Business Roles (BTP) ou roles PFCG (On-Premise).
- Controle de concorrência nas operações críticas de estoque.
- Camada analítica somente leitura: cubos ZI_PC_\*_CUBE, consultas ZC_PC_\*_ANALISE, serviço ZUI_PC_ANALITICO e quatro aplicações SAPUI5 freestyle de análise (Pedidos de Compras, Clientes, Itens do Estoque e Pedidos de Reembolsos), com 5 análises cada.

## 2.2 Fora do Escopo

- Gestão de entrega, frete real, transportadoras ou rastreamento.
- Integração real com gateway de pagamento.
- Armazenamento de número completo de cartão, CVV ou validade completa.
- Auditoria avançada de alterações.
- Logs técnicos avançados e monitoramento produtivo.
- Testes de interface automatizados de ponta a ponta (os testes ABAP Unit de backend são permanentes e fazem parte do escopo; ver seção 25).
- Histórico completo de tentativas de pagamento.
- Uso por clientes reais.

# 3. Tecnologias e Arquitetura

| Camada | Tecnologia/Serviço | Observações |
|:---|:---|:---|
| Backend | SAP RAP (ABAP Cloud no BTP; Standard ABAP no On-Premise) | Business Objects RAP, Behavior Definitions, Behavior Implementations, validations, determinations, actions e EML. |
| Ambiente | SAP BTP ABAP Environment Trial ou SAP S/4HANA On-Premise | Mesmo código RAP nos dois ambientes; as diferenças estão na seção 26 e em abap/README.md. |
| Persistência | SAP HANA / ABAP Dictionary Tables | Tabelas ativas ZTA_\* e tabelas draft ZTA_\*_D para todas as entidades de BOs com draft (nomes de tabela com no máximo 16 caracteres). |
| Serviço OData | OData V4 via Service Definition/Service Binding | Exposição das projections transacionais para Fiori Elements. |
| Frontend | SAP Fiori Elements | Quatro aplicações List Report/Object Page independentes. |
| Segurança | Authorization Control RAP + IAM/Business Roles (BTP) ou SU21/SU24/PFCG (On-Premise) | Serviço/catálogo por aplicação, perfil via global authorization e disponibilidade por status via feature control. |
| Portal | SAP Build Work Zone (BTP) ou SAP Fiori launchpad embarcado (On-Premise) | Exposição das quatro aplicações como tiles independentes. |

## 3.1 Arquitetura Desacoplada em Quatro Aplicações

A solução será composta por quatro aplicações Fiori Elements independentes, publicadas por quatro serviços OData V4 UI distintos. As aplicações compartilham o mesmo domínio persistente e se comunicam por CDS reutilizáveis, value helps, associações e lógica transacional RAP no backend.

| Aplicação | Service Definition | Service Binding | Responsabilidade |
|:---|:---|:---|:---|
| Gestão de Clientes | ZUI_PC_CLIENTES | ZUI_PC_CLIENTES_O4 | Manutenção de clientes e endereços. |
| Gestão de Estoque | ZUI_PC_ESTOQUE | ZUI_PC_ESTOQUE_O4 | Manutenção de itens, estoque, SKU e status de disponibilidade. |
| Pedidos de Compras | ZUI_PC_PEDIDOS_COMPRAS | ZUI_PC_PEDIDOS_COMPRAS_O4 | Ciclo de vida do pedido: rascunho, registro com reserva de estoque, pagamento simulado, baixa, cancelamento (com abertura de reembolso) e snapshots. |
| Gestão de Reembolsos | ZUI_PC_REEMBOLSOS | ZUI_PC_REEMBOLSOS_O4 | Aprovação e rejeição das solicitações de reembolso de pedidos cancelados com pagamento aprovado. |

## 3.2 Mapeamento CAP para RAP

| Elemento no CAP | Equivalente em SAP RAP | Observação |
|:---|:---|:---|
| schema.cds | Tabelas ZTA_\* / ZTA_\*_D + Root CDS ZR_\* | Modelo persistente e transacional migrado para ABAP Dictionary e CDS View Entities. |
| services.cds | Projection Views ZC_\* + Service Definitions | Cada aplicação possui seu próprio serviço OData V4 UI. |
| handlers.js | Behavior Implementation Classes ZBP_R_\* | Regras de negócio implementadas em ABAP (RAP, EML). |
| actions CAP | RAP Actions | Actions declaradas no Behavior Definition e implementadas na behavior pool. |
| before/on handlers | Validations, determinations e action methods | Validações, cálculos e transições no ciclo transacional RAP. |
| @restrict / XSUAA | Authorization Control RAP + IAM Apps, Business Catalogs e Business Roles (BTP) ou roles PFCG (On-Premise) | Permissões segregadas por aplicação e perfil. |

# 4. Padrão de Nomenclatura RAP

A nomenclatura adotada seguirá boas práticas de separação por camadas, evitando nomenclaturas associadas ao projeto CAP e deixando explícito o papel técnico de cada artefato RAP.

| Tipo de Artefato | Padrão | Exemplo |
|:---|:---|:---|
| Tabelas ativas | ZTA_PC_\* | ZTA_PC_CLIENTE, ZTA_PC_PEDIDO, ZTA_PC_ITEM_PED |
| Tabelas draft | ZTA_PC_\*_D | ZTA_PC_CLIENTE_D, ZTA_PC_PEDIDO_D, ZTA_PC_ITPED_D |
| Root/Base CDS View Entity | ZR_PC_\* | ZR_PC_CLIENTE, ZR_PC_PEDIDO, ZR_PC_ITEM |
| Projection/Consumption CDS View Entity | ZC_PC_\* | ZC_PC_CLIENTE_APP, ZC_PC_PEDIDO_APP |
| Value Helps | ZC_PC_\*_VH | ZC_PC_CLIENTE_VH, ZC_PC_ITEM_VH |
| Behavior Pool | ZBP_R_PC_\* | ZBP_R_PC_CLIENTE, ZBP_R_PC_PEDIDO |
| Service Definition UI | ZUI_PC_\* | ZUI_PC_CLIENTES, ZUI_PC_ESTOQUE |
| Service Binding OData V4 | ZUI_PC_\*_O4 | ZUI_PC_PEDIDOS_COMPRAS_O4 |
| IAM App | ZPC_IAM_\* | ZPC_IAM_CLIENTES, ZPC_IAM_PEDIDOS |
| Business Catalog | ZPC_BC_\* | ZPC_BC_ESTOQUE |
| Business Role | ZPC_BR_\* | ZPC_BR_ADMIN, ZPC_BR_COMUM |
| Parâmetro de action (abstract entity) | ZPC_A_\* | ZPC_A_PAGAMENTO_INPUT, ZPC_A_CANCELAMENTO_INPUT |
| Classes utilitárias / mensagens | ZCL_PC_\* / ZCX_PC_\* / ZPC_MSG | ZCL_PC_UTIL, ZCL_PC_VIACEP, ZCX_PC_MSG |
| CodeLists | ZTA_PC_CODELIST + ZC_PC_\*_VH | ZC_PC_STATUSPED_VH |

Limites técnicos: tabelas do ABAP Dictionary têm no máximo 16 caracteres (por isso ZTA_PC_ITEM_PED, ZTA_PC_SNAP_CLI e ZTA_PC_SNAP_ITM); CDS e classes, 30 caracteres. Ao criar uma IAM App do tipo External App o ADT acrescenta o sufixo _EXT (ex.: ZPC_IAM_PEDIDOS_EXT).

# 5. Perfis de Usuário e Permissões

## 5.1 Usuário Comum

- Acessa principalmente a aplicação Pedidos de Compras.
- Consulta clientes e itens por value helps ou listas de referência somente leitura.
- Cria pedidos em rascunho (draft); depois do registro (Save) só os itens do pedido ABERTO podem ser alterados (Editar + Salvar); o pedido não é excluído, apenas cancelado.
- Executa Efetuar Pagamento (SimularPagamento), Aprovar pedido (AprovarPedido) e Cancelar pedido (CancelarPedido) quando autorizado pelo status.
- Aprova ou rejeita solicitações de reembolso na aplicação Gestão de Reembolsos (mesma autorização de execução ZPC_PEDIDO).
- Não cria, edita, exclui, ativa ou inativa clientes.
- Não cria, edita, exclui ou inativa itens de estoque.
- Não edita pedidos finalizados ou cancelados.
- Não edita snapshots.

## 5.2 Usuário Administrador

- Acessa as quatro aplicações: Clientes, Gestão de Estoque, Pedidos de Compras e Gestão de Reembolsos.
- Cria, edita, ativa, inativa e exclui clientes, respeitando regras de integridade.
- Cria, edita, inativa e exclui itens de estoque, respeitando regras de integridade.
- Executa todas as ações permitidas ao usuário comum.
- Não edita pedidos finalizados ou cancelados.
- Não edita snapshots.
- Não persiste nem consulta dados sensíveis de cartão.

## 5.3 Matriz de Permissões

| Aplicação | Ação | Comum | Admin | Observação |
|:---|:---|:---|:---|:---|
| Clientes | Listar/visualizar | Sim | Sim | Usuário comum apenas por consulta/value help quando necessário. |
| Clientes | Criar/editar/excluir | Não | Sim | CPF obrigatório, único e validado. |
| Clientes | Ativar/Inativar | Não | Sim | Via edição controlada do campo ClienteAtivo. |
| Estoque | Listar/visualizar | Sim | Sim | Usuário comum pode consultar itens para pedido. |
| Estoque | Criar/editar/excluir | Não | Sim | SKU gerado automaticamente e único. |
| Estoque | Inativar | Não | Sim | Bloqueado se houver estoque disponível ou pedido ativo vinculado. |
| Pedidos | Criar (rascunho) | Sim | Sim | Rascunho; ao salvar o pedido é registrado (ABERTO); enquanto ABERTO só os itens podem ser editados. |
| Pedidos | Efetuar Pagamento/Aprovar pedido/Cancelar | Sim | Sim | Disponível conforme status (feature control) e perfil (global authorization). |
| Reembolsos | Aprovar/Rejeitar | Sim | Sim | Somente solicitações PENDENTES (feature control) e perfil (global authorization); rejeitar exige motivo. |
| Snapshots | Editar/excluir | Não | Não | Histórico imutável. |

# 6. Autenticação e Autorização

A autenticação é delegada à plataforma: SAP ID service ou Identity Authentication no SAP BTP, ABAP environment; usuários SU01 com SSO (SAML 2.0 ou Kerberos) no On-Premise. A autorização usa o mesmo código RAP nos dois ambientes — métodos de authorization control e, quando aplicável, Access Control em CDS — e muda só a configuração: IAM Apps, Business Catalogs e Business Roles no BTP; objetos SU21, valores propostos SU24 e roles PFCG no On-Premise (seção 26 e abap/README.md, seção 6).

## 6.1 Objetos de IAM Recomendados

| Tipo | Clientes | Estoque | Pedidos |
|:---|:---|:---|:---|
| IAM App | ZPC_IAM_CLIENTES | ZPC_IAM_ESTOQUE | ZPC_IAM_PEDIDOS |
| Business Catalog | ZPC_BC_CLIENTES | ZPC_BC_ESTOQUE | ZPC_BC_PEDIDOS |
| Business Role Admin | ZPC_BR_ADMIN | ZPC_BR_ADMIN | ZPC_BR_ADMIN |
| Business Role Comum | Somente leitura quando exposto | Somente leitura quando exposto | ZPC_BR_COMUM |

Gestão de Reembolsos: IAM App ZPC_IAM_REEMBOLSOS e Business Catalog ZPC_BC_REEMBOLSOS, incluídos nas Business Roles ZPC_BR_ADMIN e ZPC_BR_COMUM (a criar no ADT junto com o Service Binding ZUI_PC_REEMBOLSOS_O4).

Objetos de autorização (campo ACTVT) atribuídos às IAM Apps: ZPC_ADMIN (manutenção de clientes e estoque) e ZPC_PEDIDO (criação de pedidos, execução das actions e decisão de reembolso). A verificação é centralizada na classe ZCL_PC_AUTH.

No SAP BTP ABAP Environment Trial (sistema compartilhado) normalmente não há acesso de administrador para manter Business Roles. Nesse caso a constante ZIF_PC_CONSTANTS=>C_MODO_TRIAL = abap_true libera as verificações de perfil e os testes são feitos pelo preview dos Service Bindings. Em um sistema real a constante deve ser abap_false.

No On-Premise, os mesmos objetos ZPC_ADMIN e ZPC_PEDIDO são criados em SU21 (classe ZPC), vinculados aos serviços em SU24 e atribuídos pelas roles PFCG Z_PC_ADMIN e Z_PC_COMUM, sempre com C_MODO_TRIAL = abap_false; o acesso a cada serviço OData V4 é verificado pelo objeto S_START.

## 6.2 Estratégia RAP

- Utilizar authorization master ( global ) nos quatro BOs: o perfil (administrador ou comum) é verificado em get_global_authorizations por meio de ZCL_PC_AUTH.
- Controlar a disponibilidade de Edit, delete, inclusão de itens e actions conforme o estado da instância (rascunho ou ativa, status do pedido, status do reembolso) com feature control dinâmico (features : instance / get_instance_features). Status não é critério de autorização.
- As CDS usam @AccessControl.authorizationCheck: #NOT_REQUIRED, pois não há restrição de leitura por instância no escopo. Caso seja necessária, criar Access Controls (DCL) com aspect pfcg_auth e só então usar #CHECK (sem DCL, #CHECK não restringe nada).
- Expor tiles diferentes no Fiori Launchpad/Work Zone conforme o catálogo associado ao usuário.
- Garantir que validações críticas permaneçam no backend, independentemente de restrições visuais da UI.
- As actions internas de estoque (ReservarEstoque, LiberarReserva, BaixarEstoque) e as actions internas do pedido chamadas pelo BO Reembolso (CancelarPorReembolso, RetomarPedido) usam authorization : none e não são expostas na projection; o usuário só movimenta estoque por meio das ações do pedido e da decisão de reembolso.

# 7. Modelo de Dados

A modelagem será implementada por tabelas ABAP Dictionary, CDS View Entities, composições RAP, Behavior Definitions managed with draft e projections específicas por aplicação.

Convenções de tipo: chaves SYSUUID_X16 (RAW 16) com numbering : managed; valores monetários CURR(15,2) sempre com referência a um campo CUKY (Currency); booleanos com o elemento de dados ABAP_BOOLEAN; campos administrativos CreatedBy, CreatedAt, LastChangedBy, LastChangedAt e LocalLastChangedAt em todas as tabelas (LocalLastChangedAt = ETag da entidade; LastChangedAt = total ETag do root).

## 7.1 Objetos Persistentes Recomendados

| Entidade funcional | Tabela ativa | Tabela draft | Root/Base View | Projection App |
|:---|:---|:---|:---|:---|
| Clientes | ZTA_PC_CLIENTE | ZTA_PC_CLIENTE_D | ZR_PC_CLIENTE | ZC_PC_CLIENTE_APP |
| Endereços | ZTA_PC_ENDERECO | ZTA_PC_ENDEREC_D | ZR_PC_ENDERECO | ZC_PC_ENDERECO_APP |
| Itens | ZTA_PC_ITEM | ZTA_PC_ITEM_D | ZR_PC_ITEM | ZC_PC_ITEM_APP |
| Pedidos | ZTA_PC_PEDIDO | ZTA_PC_PEDIDO_D | ZR_PC_PEDIDO | ZC_PC_PEDIDO_APP |
| ItensPedido | ZTA_PC_ITEM_PED | ZTA_PC_ITPED_D | ZR_PC_ITEM_PEDIDO | ZC_PC_ITEM_PEDIDO_APP |
| Pagamentos | ZTA_PC_PAGAMENTO | ZTA_PC_PAGTO_D | ZR_PC_PAGAMENTO | ZC_PC_PAGAMENTO_APP |
| PedidosClienteSnapshots | ZTA_PC_SNAP_CLI | ZTA_PC_SNPCLI_D (técnica) | ZR_PC_PED_CLI_SNAP | ZC_PC_PED_CLI_SNAP_APP |
| PedidosItensSnapshots | ZTA_PC_SNAP_ITM | ZTA_PC_SNPITM_D (técnica) | ZR_PC_PED_ITEM_SNAP | ZC_PC_PED_ITEM_SNAP_APP |
| Reembolsos | ZTA_PC_REEMBOLSO | Não aplicável (BO sem draft) | ZR_PC_REEMBOLSO | ZC_PC_REEMBOLSO_APP |
| CodeLists | ZTA_PC_CODELIST | Não aplicável | ZR_PC_CODELIST | ZC_PC_\*_VH |

## 7.2 Clientes

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| ClienteUUID | SYSUUID_X16 | Sim | Chave primária (numbering : managed). |
| FotoCliente | RAWSTRING | Não | Imagem do cliente. Aceitar apenas JPEG, PNG ou WEBP. |
| FotoMimeType | CHAR(50) | Não | MIME type da imagem. |
| FotoFileName | CHAR(255) | Não | Nome original do arquivo. |
| Cpf | CHAR(11) | Sim | CPF único, salvo apenas com números, validado (dígitos verificadores) e exibido formatado (virtual element CpfFormatado). |
| Nome | CHAR(255) | Sim | Nome completo. |
| Email | CHAR(100) | Sim | E-mail com formato válido. |
| Telefone | CHAR(11) | Sim | DDD + número (10 ou 11 dígitos), salvo apenas com números. |
| Genero | CHAR(30) | Não | Código de gênero via CodeList/value help. |
| DataNascimento | DATS | Sim | Não pode ser data futura. |
| ClienteAtivo | ABAP_BOOLEAN | Sim | Define se o cliente pode realizar pedidos. Novo cliente nasce ativo. |
| ScoreCliente | DEC(5,2) | Não | Score de 0 a 100, somente leitura (sorteado na criação). Exibido em % como barra de progresso com cor dinâmica: até 40 vermelho, de 40 a 70 amarelo e a partir de 70 verde (unidade % via virtual element ScoreUnidade). |
| Campos administrativos | created/changed fields | Sim | Campos managed: CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt. |

## 7.3 Endereços

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| EnderecoUUID | SYSUUID_X16 | Sim | Chave primária. |
| ClienteUUID | SYSUUID_X16 | Sim | Cliente proprietário do endereço. |
| Cep | CHAR(8) | Sim | CEP salvo apenas com números e validado via ViaCEP. Faz parte da chave primária da tabela ZTA_PC_ENDERECO: depois que o endereço é gravado o campo fica somente leitura (para trocar o CEP, excluir o endereço e cadastrar outro). |
| Logradouro | CHAR(150) | Sim | Preenchido via ViaCEP e bloqueado para edição. Para CEP geral de município (ViaCEP sem logradouro) torna-se editável e obrigatório. |
| Numero | CHAR(20) | Sim | Número obrigatório. Endereço sem número não é permitido. |
| Complemento | CHAR(100) | Não | Complemento informado pelo usuário. |
| Bairro | CHAR(100) | Sim | Preenchido via ViaCEP; editável e obrigatório apenas para CEP geral. |
| Cidade | CHAR(100) | Sim | Preenchido via ViaCEP. |
| Uf | CHAR(2) | Sim | Preenchido via ViaCEP. |
| Estado | CHAR(100) | Sim | Preenchido via ViaCEP. |
| CepGeral | ABAP_BOOLEAN | Sim | Indica CEP geral de município. Definido pelo backend (somente leitura). |
| EnderecoPrincipal | ABAP_BOOLEAN | Sim | Apenas um endereço principal por cliente. Alterado somente pela action DefinirEnderecoPrincipal; o primeiro endereço do cliente vira principal. |

## 7.4 Itens de Estoque

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| ItemUUID | SYSUUID_X16 | Sim | Chave primária. |
| FotoItem | RAWSTRING | Não | Imagem JPEG/PNG/WEBP do item. |
| FotoMimeType | CHAR(50) | Não | MIME type da imagem. |
| FotoFileName | CHAR(255) | Não | Nome original do arquivo. |
| Sku | CHAR(21) | Sim | Código único gerado no backend no Save do rascunho (determination GerarSku on save, também executada no Prepare): SKU-\<3 primeiras letras da categoria em maiúsculas, completadas com X se faltarem>-\<10 dígitos> (ex.: SKU-INF-0000000001), sequencial do intervalo 02 do objeto de numeração ZPC_NR. Se a categoria mudar antes de um novo Save, o SKU é regenerado com o novo prefixo. |
| Nome | CHAR(120) | Sim | Nome do item. |
| Descricao | CHAR(500) | Não | Descrição do item. |
| Categoria | CHAR(30) | Sim | Categoria via CodeList/value help. |
| QtdeEstoque | INT4 | Sim | Quantidade física total em estoque. |
| QtdeReservada | INT4 | Sim | Quantidade reservada em pedidos registrados e ainda não finalizados/cancelados. Somente leitura (alterada apenas pelas actions internas de estoque). |
| QtdeDisponivel | INT4 (persistido, somente leitura) | Sim | QtdeEstoque - QtdeReservada, recalculada no backend a cada alteração. Persistida para permitir filtro e ordenação na lista (elementos virtuais não são filtráveis). |
| StatusEstoque | CHAR(30) | Sim | SEM_ESTOQUE, ACABANDO ou EM_ESTOQUE. |
| Currency | CUKY | Sim | Moeda padrão BRL. |
| PrecoUnitario | CURR(15,2) | Sim | Preço atual do item (referência Currency). |
| ItemAtivo | ABAP_BOOLEAN | Sim | Somente itens ativos podem ser usados em novos pedidos. |

## 7.5 Pedidos

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| PedidoUUID | SYSUUID_X16 | Sim | Chave primária. |
| NumeroPedido | CHAR(10) | Sim | Número sequencial gerado na ativação (intervalo 01 de ZPC_NR); é o "ID" exibido na lista. |
| ClienteUUID | SYSUUID_X16 | Sim | Cliente selecionado para o pedido. |
| EnderecoUUID | SYSUUID_X16 | Sim | Endereço principal do cliente, derivado automaticamente (somente leitura). |
| EnderecoPrincipalCompleto | CHAR(500) | Sim | Endereço completo usado no pedido. |
| StatusPedido | CHAR(40) | Sim | ABERTO, AGUARDANDO_APROVACAO, PROCESSANDO_REEMBOLSO, CANCELADO ou FINALIZADO. |
| StatusPagamento | CHAR(30) | Sim | Réplica do status do pagamento (PENDENTE, APROVADO, RECUSADO, DEVOLVIDO) para lista e filtros. |
| Observacao | CHAR(500) | Não | Observações do pedido. |
| Currency | CUKY | Sim | Moeda padrão BRL. |
| ValorTotal | CURR(15,2) | Sim | Total persistido do pedido, calculado no backend. |
| DataFinalizacao | TIMESTAMPL | Não | Data/hora da finalização. |
| MotivoCancelamento | CHAR(500) | Não | Motivo obrigatório no cancelamento. |
| DataCancelamento | TIMESTAMPL | Não | Data/hora do cancelamento. |
| CanceladoPor | ABP_LASTCHANGE_USER | Não | Usuário responsável pelo cancelamento. |
| CreatedAt | ABP_CREATION_TSTMPL | Sim | Data/hora de criação; usada como "Data do pedido" na lista. |
| PedidoEncerrado | XFELD | Sim | Indicador mantido por AtualizarFlagsStatus: verdadeiro em FINALIZADO e CANCELADO (cliente e itens vêm dos snapshots). |
| PedidoAtivoSemHistorico | XFELD | Sim | Indicador: verdadeiro nos status que não encerram o pedido (cliente e itens vêm das tabelas principais). |
| PedidoNaoFinalizado | XFELD | Sim | Indicador usado em hidden: #(PedidoNaoFinalizado) para ocultar a seção Finalização quando o pedido não está FINALIZADO. |
| PedidoNaoCancelado | XFELD | Sim | Indicador usado em hidden: #(PedidoNaoCancelado) para ocultar a seção Cancelamento quando o pedido não está CANCELADO. |

## 7.6 ItensPedido

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| ItemPedidoUUID | SYSUUID_X16 | Sim | Chave primária. |
| PedidoUUID | SYSUUID_X16 | Sim | Pedido proprietário. |
| ItemUUID | SYSUUID_X16 | Sim | Item original selecionado. |
| QtdeItemPedido | INT4 | Sim | Quantidade solicitada. Deve ser maior que zero. |
| PrecoUnitarioSnapshot | CURR(15,2) | Sim | Preço provisório copiado do item durante o draft; fixado definitivamente no registro do pedido (Save). |
| Currency | CUKY | Sim | Moeda padrão BRL. |
| ValorTotal | CURR(15,2) (persistido) | Sim | QtdeItemPedido \* PrecoUnitarioSnapshot. |
| Observacao | CHAR(500) | Não | Observações do item no pedido. |

## 7.7 Pagamentos

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| PagamentoUUID | SYSUUID_X16 | Sim | Chave primária. |
| PedidoUUID | SYSUUID_X16 | Sim | Pedido associado. |
| MetodoPagamento | CHAR(20) | Sim | CARTAO_CREDITO ou CARTAO_DEBITO. |
| StatusPagamento | CHAR(30) | Sim | PENDENTE, APROVADO, RECUSADO ou DEVOLVIDO (quando o reembolso do pedido é aprovado). |
| BandeiraCartao | CHAR(30) | Não | Bandeira simulada/detectada. |
| Ultimos4DigitosCartao | CHAR(4) | Não | Apenas os quatro últimos dígitos. |
| CartaoMascarado | CHAR(30) | Não | Representação segura do cartão. |
| CodigoAutorizacao | CHAR(50) | Não | Código fictício/seguro da autorização. |
| MensagemPagamento | CHAR(255) | Não | Mensagem segura do resultado. |
| DataPagamento | TIMESTAMPL | Não | Data/hora da última tentativa. |

Pagamento é filho de composição [0..1] do pedido, criado e atualizado somente pela action SimularPagamento (internal create / internal update). Número completo, validade e CVV nunca são gravados.

## 7.8 Snapshots

Snapshots são criados no encerramento do pedido (finalização ou cancelamento), uma única vez, e exibidos somente para leitura na aplicação Pedidos de Compras. Como são filhos de composição de um BO com draft, o RAP exige tabelas draft (ZTA_PC_SNPCLI_D e ZTA_PC_SNPITM_D): elas são apenas técnicas e permanecem vazias, pois os snapshots só são criados por internal create sobre a instância ativa e não possuem update nem delete.

| Snapshot | Tabela | Campos principais | Regra |
|:---|:---|:---|:---|
| PedidosClienteSnapshots | ZTA_PC_SNAP_CLI | CPF, nome, e-mail, telefone, gênero, data de nascimento, ativo, score, endereço (campos e completo) e motivo (FINALIZACAO/CANCELAMENTO). | Congela dados do cliente/endereço no encerramento. |
| PedidosItensSnapshots | ZTA_PC_SNAP_ITM | SKU, nome, descrição, categoria, quantidade, preço e total. | Congela dados dos itens no encerramento. |

## 7.9 Reembolsos

Solicitação de reembolso criada quando um pedido com pagamento aprovado é cancelado (EML do BO Pedido para o BO Reembolso) e decidida na aplicação Gestão de Reembolsos. O Reembolso é root de um BO próprio, sem draft; não é filho do Pedido.

| Campo | Tipo RAP/ABAP sugerido | Obrigatório | Descrição/Regras |
|:---|:---|:---|:---|
| ReembolsoUUID | SYSUUID_X16 | Sim | Chave primária (numbering : managed). |
| PedidoUUID | SYSUUID_X16 | Sim | Pedido a que a solicitação se refere (imutável). |
| NumeroPedido | CHAR(10) | Sim | Número do pedido, copiado para a lista de reembolsos. |
| ClienteUUID | SYSUUID_X16 | Sim | Cliente do pedido (exibido como nome na lista). |
| StatusReembolso | CHAR(20) | Sim | PENDENTE, APROVADO ou REJEITADO (CodeList STATUS_REEMBOLSO). |
| StatusPedidoAnterior | CHAR(40) | Sim | Status do pedido antes da solicitação; restaurado se o reembolso for rejeitado. |
| Currency / ValorReembolso | CUKY / CURR(15,2) | Sim | Valor total do pedido no momento da solicitação. |
| MotivoSolicitacao | CHAR(500) | Sim | Motivo do cancelamento informado pelo usuário. |
| DataSolicitacao / SolicitadoPor | TIMESTAMPL / usuário | Sim | Quando e por quem o cancelamento foi solicitado. |
| MotivoDecisao | CHAR(500) | Não | Obrigatório ao rejeitar; opcional ao aprovar. |
| DataDecisao / DecididoPor | TIMESTAMPL / usuário | Não | Preenchidos pela decisão (Aprovar ou Rejeitar). |
| Campos administrativos | created/changed fields | Sim | Campos managed: CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt (ETag). |

# 8. Business Objects RAP

## 8.1 BO Cliente

- Root: ZR_PC_CLIENTE.
- Child: ZR_PC_ENDERECO.
- Behavior Pool: ZBP_R_PC_CLIENTE.
- Projection App: ZC_PC_CLIENTE_APP e ZC_PC_ENDERECO_APP.
- Serviço: ZUI_PC_CLIENTES.
- Draft habilitado para cliente e endereço.
- Action pública: DefinirEnderecoPrincipal.
- Validações: CPF (dígitos e unicidade), dados obrigatórios, e-mail, telefone, gênero, foto, data de nascimento, número obrigatório e CEP. O CEP de endereço já gravado é somente leitura (field ( features : instance ) Cep), porque faz parte da chave primária da tabela; sem isso a alteração gerava RAISE_SHORTDUMP (UPDATE com sy-subrc 4).
- Determinations: DefinirValoresIniciais, NormalizarDados, PreencherEnderecoViaCep e DefinirPrincipalInicial.
- Exclusão com pedido vinculado bloqueada por delete ( features : instance, precheck ) — validations não podem ser disparadas por delete.

## 8.2 BO Estoque

- Root: ZR_PC_ITEM.
- Behavior Pool: ZBP_R_PC_ITEM.
- Projection App: ZC_PC_ITEM_APP.
- Serviço: ZUI_PC_ESTOQUE.
- Draft habilitado para manutenção do item.
- Determinations: DefinirValoresIniciais, RecalcularStatusEstoque (on modify) e GerarSku (on save, executada também no Prepare do rascunho: o SKU nasce no Save e usa as 3 primeiras letras da categoria).
- Validações: ValidarItem, ValidarQuantidades, ValidarInativacaoItem, ValidarSkuUnico e ValidarFoto; exclusão controlada por delete ( features : instance, precheck ).
- Actions internas ReservarEstoque, LiberarReserva e BaixarEstoque (parâmetro ZPC_A_QTDE_INPUT, authorization : none), não expostas na projection e executadas apenas pelo BO Pedido via EML.

## 8.3 BO Pedido

- Root: ZR_PC_PEDIDO.
- Children: ZR_PC_ITEM_PEDIDO, ZR_PC_PAGAMENTO, ZR_PC_PED_CLI_SNAP e ZR_PC_PED_ITEM_SNAP.
- Behavior Pool: ZBP_R_PC_PEDIDO.
- Projection App: ZC_PC_PEDIDO_APP e projections filhas.
- Serviço: ZUI_PC_PEDIDOS_COMPRAS.
- Draft habilitado para a criação e para a edição dos itens do pedido ABERTO. Ao salvar (Prepare + Activate) o pedido é registrado como instância ativa em ABERTO e o estoque dos itens é reservado. Enquanto ABERTO só os itens podem ser alterados (ClienteUUID é obrigatório na criação e somente leitura na atualização) e a reserva é ajustada pela diferença (determination ReservarEstoqueRegistro on { create; update; } e implementação adicional de Activate, que cobre a remoção de itens). Nos demais status o pedido não é editado nem excluído. As actions do ciclo de vida são executadas apenas sobre a instância ativa.
- Actions públicas: SimularPagamento (rótulo Efetuar Pagamento; parâmetro ZPC_A_PAGAMENTO_INPUT), AprovarPedido (rótulo Aprovar pedido) e CancelarPedido (parâmetro ZPC_A_CANCELAMENTO_INPUT). Actions internas: RecalcularTotal e, chamadas pelo BO Reembolso via EML (authorization : none), CancelarPorReembolso e RetomarPedido (parâmetro ZPC_A_RETOMADA_INPUT).
- Object Page dinâmica: a determination AtualizarFlagsStatus (on modify { create; field StatusPedido; }) mantém as colunas persistidas PedidoEncerrado, PedidoAtivoSemHistorico, PedidoNaoFinalizado e PedidoNaoCancelado, usadas em @UI.facet com hidden: #(Campo) no DDLX ZC_PC_PEDIDO_APP (ver seção 15.4).
- Validações: ValidarCliente, ValidarItemPedido e ValidarRegistro (Save do rascunho: endereço principal do cliente, ao menos um item e disponibilidade de estoque); determination ReservarEstoqueRegistro (reserva ao registrar o pedido); regras de status, pagamento aprovado e cancelamento nas actions.
- Pagamento e snapshots são criados somente por internal create; não possuem create, update ou delete externos.

## 8.4 BO Reembolso

- Root: ZR_PC_REEMBOLSO (tabela ZTA_PC_REEMBOLSO), sem draft e sem filhos.
- Behavior Pool: ZBP_R_PC_REEMBOLSO. Projection App: ZC_PC_REEMBOLSO_APP (root, somente leitura). Serviço: ZUI_PC_REEMBOLSOS.
- create apenas interno (feito pelo BO Pedido via EML ao cancelar pedido com pagamento aprovado); internal update; sem delete.
- Actions públicas com feature control (somente solicitações PENDENTES): AprovarReembolso e RejeitarReembolso (parâmetro ZPC_A_REEMB_DECISAO_INPUT, motivo da decisão).
- AprovarReembolso executa CancelarPorReembolso no BO Pedido (libera a reserva, gera os snapshots e cancela o pedido) e grava APROVADO, motivo, data e usuário da decisão na mesma LUW.
- RejeitarReembolso (motivo obrigatório) executa RetomarPedido no BO Pedido (volta ao StatusPedidoAnterior) e grava REJEITADO.

# 9. Comunicação entre as Aplicações

As aplicações serão desacopladas no nível de UI e serviço, mas compartilharão o mesmo modelo de domínio ABAP. A aplicação Pedidos de Compras será a consumidora funcional de clientes e estoque.

## 9.1 Comunicação por CDS Reutilizáveis e Value Helps

| Origem | View Reutilizável | Consumidor | Uso |
|:---|:---|:---|:---|
| Clientes | ZC_PC_CLIENTE_VH | Pedidos de Compras | Seleção de cliente ativo. |
| Clientes/Endereços | ZC_PC_ENDERECO_VH | Pedidos de Compras | Seleção/validação do endereço principal do cliente. |
| Estoque | ZC_PC_ITEM_VH | Pedidos de Compras | Seleção de itens ativos e consulta de preço/disponibilidade. |

## 9.2 Comunicação por Backend RAP/EML

A aplicação Pedidos de Compras não atualiza estoque pela UI da aplicação de estoque. Reserva, baixa e liberação são executadas dentro do BO Pedido, na mesma LUW, por EML entre BOs: o BO Pedido executa as actions internas ReservarEstoque, LiberarReserva e BaixarEstoque do BO Item. O framework bloqueia o item (lock master) antes de cada action e o saldo é relido sob esse lock.

- O registro do pedido (determination ReservarEstoqueRegistro, ao ativar o rascunho) valida e incrementa QtdeReservada do item.
- AprovarPedido baixa QtdeEstoque e reduz QtdeReservada.
- CancelarPedido libera QtdeReservada quando houver reserva; com pagamento aprovado a reserva é mantida até a decisão do reembolso (AprovarReembolso libera; RejeitarReembolso mantém).
- Todas as operações críticas devem reler o item no banco antes de atualizar quantidades.
- Em falha parcial na reserva, as reservas já feitas na mesma chamada são liberadas (compensação) e o pedido recebe o erro; nenhuma alteração do pedido é gravada.
- O BO Reembolso (aplicação Gestão de Reembolsos) executa por EML as actions internas CancelarPorReembolso e RetomarPedido do BO Pedido; o BO Pedido cria a solicitação no BO Reembolso por EML ao cancelar um pedido com pagamento aprovado. Tudo na mesma LUW.
- A UI e os value helps não substituem validações definitivas no backend.

## 9.3 Navegação entre Aplicações

Opcionalmente, o Fiori Launchpad/Work Zone poderá disponibilizar navegação entre apps por intent-based navigation, como Pedido → Cliente, Pedido → Item, Cliente → Pedidos do Cliente e Estoque → Pedidos relacionados. Essa navegação será de consulta e não de acoplamento funcional obrigatório.

# 10. Regras de Negócio

## 10.1 Clientes

- Cadastro e edição de clientes serão feitos com draft.
- CPF é obrigatório, único, salvo apenas com números e exibido formatado quando aplicável.
- Cliente pode possuir múltiplos endereços.
- Apenas um endereço por cliente pode estar marcado como principal.
- Cliente inativo não pode ser usado em novos pedidos.
- Cliente não pode ser excluído se possuir qualquer pedido vinculado.
- Ativação e inativação ocorrerão por edição direta do campo ClienteAtivo, permitida apenas para administradores.
- Fotos devem aceitar apenas JPEG, PNG ou WEBP.

## 10.2 Endereços

- ViaCEP será utilizado para preenchimento automático e validação obrigatória de CEP.
- Se a API ViaCEP estiver indisponível, o cadastro/alteração deve ser bloqueado.
- Campos retornados pelo ViaCEP não podem ser editados manualmente. Exceção: CEP geral de município (sem logradouro/bairro no ViaCEP), em que Logradouro e Bairro passam a ser editáveis e obrigatórios.
- Número do endereço é obrigatório.
- Ao marcar um endereço como principal, os demais endereços do mesmo cliente devem ser desmarcados.

## 10.3 Itens e Estoque

- Cadastro e edição de item serão feitos com draft.
- SKU é obrigatório, único e gerado automaticamente no backend.
- QtdeDisponivel deve ser calculada como QtdeEstoque - QtdeReservada.
- Item inativo não pode ser usado em novos pedidos.
- Inativação de item deve validar estoque disponível e pedidos ativos vinculados.
- StatusEstoque deve ser recalculado após criação, edição, reserva, liberação, cancelamento ou baixa de estoque.
- Fotos devem aceitar apenas JPEG, PNG ou WEBP.

## 10.4 Pedidos

- Status inicial do pedido será ABERTO.
- Pedido em draft não gera reserva de estoque.
- A reserva de estoque ocorre no registro do pedido (Save do rascunho, quando o pedido passa a existir como ABERTO); não há action de confirmação. Enquanto o pedido está ABERTO, incluir, remover ou alterar itens ajusta a reserva pela diferença.
- Pedido deve possuir cliente ativo e endereço principal válido.
- Pedido deve possuir ao menos um item ativo com quantidade maior que zero.
- Pedido FINALIZADO não pode ser editado, excluído, cancelado ou reaberto.
- Pedido CANCELADO não pode ser editado, excluído diretamente ou reaberto.
- Após movimentação de estoque ou pagamento, o pedido deve ser cancelado, não excluído.
- Pedido ABERTO: somente os itens podem ser alterados (incluir, remover, mudar a quantidade) e o cliente não pode ser trocado. Pedidos AGUARDANDO_APROVACAO, PROCESSANDO_REEMBOLSO, FINALIZADO e CANCELADO não são editados nem excluídos.
- O número do pedido (NumeroPedido) é gerado na primeira ativação do draft.
- Cancelar um pedido com pagamento aprovado não o cancela diretamente: cria uma solicitação de reembolso PENDENTE e leva o pedido a PROCESSANDO_REEMBOLSO, mantendo a reserva de estoque até a decisão.
- Reembolso aprovado: libera a reserva, gera os snapshots e cancela o pedido. Reembolso rejeitado (motivo obrigatório): o pedido retoma o status anterior à solicitação.
- Item sem estoque disponível (QtdeDisponivel = 0) não pode ser adicionado ao rascunho do pedido (precheck de inclusão de item).

# 11. Fluxo de Status do Pedido

O fluxo principal é ABERTO (registro do pedido, com reserva de estoque) → AGUARDANDO_APROVACAO (pagamento aprovado) → FINALIZADO. Pagamento recusado mantém o pedido em ABERTO, com nova tentativa permitida. O cancelamento é permitido em ABERTO e AGUARDANDO_APROVACAO; com pagamento aprovado o cancelamento passa por PROCESSANDO_REEMBOLSO. Status do pagamento: PENDENTE, APROVADO, RECUSADO e DEVOLVIDO.

| Origem | Destino | Permitido? | Condição |
|:---|:---|:---|:---|
| (início) | ABERTO | Sim | Save do rascunho: registra o pedido, gera o número e reserva o estoque. |
| ABERTO | ABERTO | Sim | Editar itens (Editar + Salvar) ajusta a reserva pela diferença; pagamento recusado mantém o status e permite nova tentativa. |
| ABERTO | AGUARDANDO_APROVACAO | Sim | Efetuar Pagamento aprovado. |
| AGUARDANDO_APROVACAO | FINALIZADO | Sim | Aprovar pedido: baixa o estoque, gera snapshots e finaliza. |
| ABERTO | CANCELADO | Sim | Cancelamento com motivo; libera a reserva e gera snapshots. |
| AGUARDANDO_APROVACAO | PROCESSANDO_REEMBOLSO | Sim | CancelarPedido com pagamento aprovado: cria a solicitação de reembolso (PENDENTE); a reserva é mantida. |
| PROCESSANDO_REEMBOLSO | CANCELADO | Sim | Action AprovarReembolso: libera a reserva, gera os snapshots e muda o pagamento para DEVOLVIDO. |
| PROCESSANDO_REEMBOLSO | Status anterior (AGUARDANDO_APROVACAO) | Sim | Action RejeitarReembolso (motivo obrigatório): o pedido retoma o status anterior à solicitação. |
| ABERTO | AGUARDANDO_APROVACAO sem pagamento | Não | Aprovar pedido exige pagamento aprovado. |
| CANCELADO | ABERTO | Não | Pedido cancelado não pode ser reaberto. |
| FINALIZADO | CANCELADO/ABERTO | Não | Pedido finalizado é imutável. |

# 12. Reserva, Baixa, Liberação e Concorrência de Estoque

## 12.1 Registro do Pedido e Reserva (Save do rascunho)

1. Validar cliente ativo (ValidarCliente).
2. Validar que o cliente possui endereço principal (ValidarRegistro, no Prepare).
3. Validar itens ativos, quantidades maiores que zero e ao menos um item.
4. Reler estoque atual dentro da transação.
5. Validar disponibilidade atual (pré-validação no Prepare; a definitiva ocorre sob lock no BO Item).
6. Ativar o rascunho: o pedido passa a existir como instância ativa em ABERTO, com NumeroPedido.
7. Fixar PrecoUnitarioSnapshot nos itens do pedido.
8. Calcular e persistir ValorTotal no pedido.
9. Incrementar QtdeReservada dos itens (action ReservarEstoque do BO Item, sob lock) — determination ReservarEstoqueRegistro.
10. Recalcular StatusEstoque.
11. Em falha na reserva, o Save é reprovado (a validation ValidarRegistro devolve as mensagens) e nenhuma alteração é gravada.

## 12.2 Aprovação/Finalização

1. Validar que o pedido está em AGUARDANDO_APROVACAO.
2. Validar que o pagamento está aprovado.
3. Validar estoque reservado correspondente aos itens do pedido.
4. Reduzir QtdeEstoque pela quantidade do pedido (action BaixarEstoque do BO Item).
5. Reduzir QtdeReservada pela quantidade do pedido.
6. Recalcular StatusEstoque.
7. Gerar snapshots de cliente, endereço e itens.
8. Preencher DataFinalizacao.
9. Alterar StatusPedido para FINALIZADO.

## 12.3 Cancelamento

1. Validar se o status permite cancelamento.
2. Exigir MotivoCancelamento.
3. Se StatusPagamento = APROVADO: criar a solicitação de Reembolso (PENDENTE), mover o pedido para PROCESSANDO_REEMBOLSO e manter a reserva; os passos seguintes só são executados na aprovação do reembolso (seção 12.4).
4. Gerar snapshots caso ainda não existam (snapshot existente não é recriado).
5. Liberar reserva de estoque (pedido registrado — action LiberarReserva).
6. Recalcular StatusEstoque.
7. Preencher MotivoCancelamento, DataCancelamento e CanceladoPor.
8. Alterar StatusPedido para CANCELADO.

## 12.4 Reembolso

- Solicitação: CancelarPedido com StatusPagamento = APROVADO cria o Reembolso (PENDENTE, com StatusPedidoAnterior e motivo) e move o pedido para PROCESSANDO_REEMBOLSO.
- Na aplicação Gestão de Reembolsos, validar que a solicitação continua PENDENTE.
- Aprovar: executar CancelarPorReembolso no BO Pedido (liberar a reserva, gerar snapshots, preencher motivo/data/usuário de cancelamento, status CANCELADO) e gravar APROVADO.
- Rejeitar: exigir MotivoDecisao, executar RetomarPedido (o pedido volta ao StatusPedidoAnterior e o motivo de cancelamento é limpo) e gravar REJEITADO.
- A decisão de um reembolso não pendente é bloqueada (mensagem REEMBOLSO_STATUS_INVALIDO).

## 12.5 Status de Estoque

| Código | Regra | Descrição |
|:---|:---|:---|
| SEM_ESTOQUE | QtdeDisponivel = 0 | Não há unidades disponíveis para novos pedidos. |
| ACABANDO | QtdeDisponivel >= 1 e \<= 10 | Estoque baixo. |
| EM_ESTOQUE | QtdeDisponivel >= 11 | Estoque disponível em quantidade suficiente. |

## 12.6 Controle de Concorrência

- Operações que alterem QtdeEstoque e QtdeReservada devem ocorrer em transação.
- Antes de reservar, liberar ou baixar estoque, o item deve ser relido no banco dentro da mesma LUW.
- A aplicação não deve confiar em valores de estoque provenientes da UI.
- Quando dois registros de pedido simultâneos competirem pelo mesmo item, apenas o primeiro com disponibilidade suficiente deve prosseguir.
- A segunda transação deve receber erro de estoque insuficiente ou concorrência.
- O registro do pedido, AprovarPedido, CancelarPedido e a decisão de reembolso devem evitar dupla reserva, dupla baixa e dupla liberação.

## 12.7 Edição dos Itens do Pedido ABERTO

- Em pedido ABERTO a opção Editar cria um rascunho com os itens atuais; o cliente (ClienteUUID) é somente leitura.
- Ao salvar, a reserva é recalculada pela diferença entre o que o pedido já reservou (lido do banco, na entidade de itens do pedido) e os itens do rascunho: reserva só o acréscimo e libera só o excedente (actions ReservarEstoque e LiberarReserva do BO Item, sob lock).
- Remover um item não dispara determination: a implementação adicional de Activate (draft action Activate with additional implementation) libera a reserva do item removido.
- O estado aplicado é registrado (gt_reserva e gt_reserva_ped) antes de qualquer MODIFY, para evitar o dump "stack of on-modify determinations being too deep".
- Quantidade acima do disponível (considerando o que o próprio pedido já reservou) bloqueia o Save (ValidarRegistro); nunca se reserva além do estoque.
- Cancelar o pedido ABERTO libera toda a reserva restante.

# 13. Pagamento Simulado com Cartão

- Coletar dados do cartão apenas na tela/action de pagamento.
- Usar número, validade e CVV apenas em memória durante SimularPagamento (rótulo Efetuar Pagamento).
- Não persistir número completo do cartão.
- Não persistir CVV.
- Não persistir validade completa.
- Persistir apenas método, status, bandeira, últimos quatro dígitos, cartão mascarado, código de autorização, mensagem e data.
- Cartões iniciados com 4 podem simular VISA.
- Cartões iniciados com 5 podem simular MASTERCARD.
- CVV igual a 000 pode simular recusa.
- Dados em formato inválido (número com 13 a 19 dígitos, validade MM/AA não expirada, CVV com 3 ou 4 dígitos, método de pagamento válido) geram erro CARTAO_DADOS_INVALIDOS — não são recusa.
- Pagamento aprovado altera o status do pedido para AGUARDANDO_APROVACAO.
- Pagamento recusado mantém o pedido em ABERTO (StatusPagamento = RECUSADO) e permite nova tentativa.
- Quando o reembolso do pedido é aprovado, o pagamento passa a DEVOLVIDO (registro do pagamento e réplica no pedido).
- A entidade Pagamentos manterá apenas a última tentativa segura.
- Os parâmetros da action aparecem sem máscara no diálogo padrão do Fiori Elements; em cenário real a captura deve usar componente dedicado/tokenização do provedor de pagamento.

# 14. Cálculos do Pedido

- ValorTotal do item = QtdeItemPedido \* PrecoUnitarioSnapshot.
- ValorTotal do pedido = soma dos totais dos itens do pedido.
- QtdeItemPedido deve ser maior que zero.
- PrecoUnitarioSnapshot deve ser maior ou igual a zero.
- QtdeEstoque deve ser maior ou igual a zero.
- QtdeReservada deve ser maior ou igual a zero e menor ou igual a QtdeEstoque.
- QtdeDisponivel = QtdeEstoque - QtdeReservada.
- Todos os cálculos definitivos devem ocorrer no backend RAP.

# 15. Interface do Usuário — SAP Fiori Elements

A solução terá quatro aplicações independentes em Fiori Elements, usando List Report/Object Page. Cada aplicação será exposta por seu próprio Service Binding OData V4 UI.

## 15.1 Listas e Filtros

| Aplicação | Campos na Lista | Filtros Recomendados |
|:---|:---|:---|
| Gestão de Clientes | Foto, CPF, Nome, E-mail, Telefone, Ativo, Cidade, UF, Data de Cadastro | Nome, CPF, E-mail, Ativo, Cidade, UF |
| Gestão de Estoque | SKU, Nome, Categoria, Qtde Estoque, Qtde Reservada, Qtde Disponível, Status, Preço, Ativo | SKU, Nome, Categoria, Status, Ativo, Qtde Disponível |
| Pedidos de Compras | Número do pedido, CPF, Cliente, Status Pedido, Status Pagamento, Total, Data Pedido (CreatedAt), Data Finalização | Cliente, CPF, Status Pedido, Status Pagamento, Data, Valor Total |
| Gestão de Reembolsos | Pedido, Cliente, Status, Valor, Motivo da solicitação, Solicitado em, Motivo da decisão | Pedido, Cliente, Status do reembolso |

## 15.2 Ações por Aplicação

| Object Page | Ações | Regras |
|:---|:---|:---|
| Cliente | Editar, Excluir, Ativar/Inativar, Definir Endereço Principal | Ações de escrita somente para administrador. |
| Estoque | Editar, Excluir, Inativar | Ações de escrita somente para administrador; status recalculado internamente. |
| Pedido | Efetuar Pagamento (SimularPagamento), Aprovar pedido (AprovarPedido), Cancelar pedido (CancelarPedido) | Ações disponíveis por status (feature control) e perfil (global authorization), somente na instância ativa. O pedido ativo não oferece Excluir; Editar só no status ABERTO (apenas os itens). |
| Reembolso | Aprovar reembolso, Rejeitar reembolso | Somente solicitações PENDENTES (feature control) e perfil (global authorization). Sem criar, editar ou excluir na UI; rejeitar exige motivo. |

## 15.3 Side Effects no Pedido

- Ao alterar o cliente em um pedido editável, validar se o cliente está ativo.
- Atualizar o endereço do pedido com base no endereço principal do cliente.
- Atualizar EnderecoPrincipalCompleto.
- Não gerar snapshot temporário.
- Não limpar automaticamente os itens do pedido.
- Bloquear o Save (registro do pedido) se o cliente não possuir endereço principal válido.

## 15.4 Object Page Dinâmica do Pedido

- Ordem das seções: 1. Dados do Cliente, 2. Dados do Pedido (inclui os campos administrativos; não há mais seção "Dados administrativos"), 3. Itens, 4. Pagamento, 5. Finalização ou Cancelamento.
- As seções Finalização e Cancelamento aparecem apenas nos status FINALIZADO e CANCELADO, respectivamente (hidden: #(PedidoNaoFinalizado) e hidden: #(PedidoNaoCancelado) na @UI.facet).
- Não há seções "Histórico - cliente" e "Histórico - itens": Dados do Cliente e Itens têm a mesma estrutura em todos os status; a fonte dos dados é que muda.
- Pedido FINALIZADO ou CANCELADO: cliente e itens vêm das tabelas de snapshot (ZTA_PC_SNAP_CLI e ZTA_PC_SNAP_ITM), imutáveis.
- Pedido ABERTO, AGUARDANDO_APROVACAO ou PROCESSANDO_REEMBOLSO: cliente e itens vêm das tabelas principais (ativas).
- Os indicadores (PedidoEncerrado, PedidoAtivoSemHistorico, PedidoNaoFinalizado, PedidoNaoCancelado) são colunas persistidas, pois hidden: aceita apenas expressão de anotação sobre campo da própria entidade.

# 16. Actions, Validations e Determinations RAP

| Domínio | Artefato RAP | Descrição |
|:---|:---|:---|
| Clientes/Endereços | Action DefinirEnderecoPrincipal | Define endereço principal e desmarca os demais do cliente. |
| Clientes | Validation ValidarCpf | Valida formato, dígitos e unicidade do CPF. |
| Clientes | Feature control + precheck do delete | Bloqueia exclusão se houver pedido vinculado (ativo ou em draft). |
| Endereços | Validation ValidarCep | Valida CEP via ViaCEP e bloqueia se indisponível. |
| Endereços | Feature control do campo Cep (field ( features : instance ) Cep) | CEP obrigatório no cadastro e somente leitura depois que o endereço é gravado (faz parte da chave da tabela). |
| Endereços | Determination PreencherEnderecoViaCep | Preenche logradouro, bairro, cidade, UF e estado a partir do CEP. |
| Estoque | Determination GerarSku | Gera o SKU único no Save do rascunho (on save, também no Prepare), com as 3 primeiras letras da categoria; regenera se a categoria mudar. |
| Estoque | Determination RecalcularStatusEstoque | Recalcula status conforme disponibilidade. |
| Estoque | Validation ValidarInativacaoItem | Bloqueia inativação indevida. |
| Estoque | Actions internas ReservarEstoque / LiberarReserva / BaixarEstoque | Movimentam QtdeReservada/QtdeEstoque sob lock; chamadas somente pelo BO Pedido. |
| Pedidos | Determination ReservarEstoqueRegistro + Validation ValidarRegistro | No Save do rascunho: ValidarRegistro checa endereço principal, itens e disponibilidade; ao ativar (e ao salvar a edição de itens), a determination reserva só a diferença de estoque, fixa preços e total. |
| Pedidos | Action SimularPagamento (Efetuar Pagamento) | Processa pagamento fictício sem persistir dados sensíveis. |
| Pedidos | Action AprovarPedido (Aprovar pedido) | Valida pagamento, baixa estoque, gera snapshot e finaliza. |
| Pedidos | Action CancelarPedido | Cancela o pedido, libera a reserva, registra o motivo e gera snapshot; com pagamento aprovado abre a solicitação de reembolso (PROCESSANDO_REEMBOLSO). |
| Pedidos | Actions internas CancelarPorReembolso / RetomarPedido | Chamadas pelo BO Reembolso (authorization : none): cancelar com liberação de reserva e snapshots, ou retomar o status anterior. |
| Pedidos | Determination DefinirStatusInicial | Define ABERTO/PENDENTE/BRL na criação (on modify, já no draft). |
| Pedidos | Determination AtualizarFlagsStatus | Mantém os indicadores de status usados para ocultar as seções Finalização/Cancelamento e escolher a origem (snapshot ou tabelas principais). |
| Pedidos | Draft action Activate with additional implementation | Libera a reserva de itens removidos (remoção pura de item não dispara determination). |
| Pedidos | Determination CalcularTotalPedido + internal action RecalcularTotal | Calcula o total no backend (provisório no draft; definitivo no registro do pedido). |
| Pedidos | Determination AtualizarEndereco | Ao trocar o cliente, usa o endereço principal atual (side effect). |
| Pedidos | Determination GerarNumeroPedido | Gera o número do pedido na ativação. |
| Pedidos | Validations ValidarCliente / ValidarItemPedido | Cliente ativo; item informado, ativo e quantidade maior que zero. |
| Reembolsos | Actions AprovarReembolso / RejeitarReembolso | Decidem a solicitação PENDENTE (feature control) e executam as actions internas do BO Pedido via EML na mesma LUW; rejeitar exige motivo. |

## 16.1 Behavior Definition — Pedido (root, versão corrigida)

```abap
managed implementation in class zbp_r_pc_pedido unique;
strict ( 2 );
with draft;

define behavior for ZR_PC_PEDIDO alias Pedido
persistent table zta_pc_pedido
draft table zta_pc_pedido_d
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master ( global )
{
create;
update;
delete ( features : instance );

association _Itens { create ( features : instance, precheck ); with draft; }
association _Pagamento { internal create; with draft; }
association _ClienteSnapshot { internal create; with draft; }
association _ItensSnapshot { internal create; with draft; }

field ( numbering : managed, readonly ) PedidoUUID;
field ( readonly ) NumeroPedido, EnderecoUUID, EnderecoPrincipalCompleto,
StatusPedido, StatusPagamento,
Currency, ValorTotal, DataFinalizacao, MotivoCancelamento,
DataCancelamento, CanceladoPor,
CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt;
field ( readonly ) PedidoEncerrado, PedidoAtivoSemHistorico,
PedidoNaoFinalizado, PedidoNaoCancelado;
field ( mandatory : create ) ClienteUUID; // cliente escolhido na criação
field ( readonly : update ) ClienteUUID; // pedido ABERTO: só os itens mudam

action ( features : instance ) SimularPagamento // rótulo: Efetuar Pagamento
parameter ZPC_A_PAGAMENTO_INPUT result [1] $self;
action ( features : instance ) AprovarPedido result [1] $self; // rótulo: Aprovar pedido
action ( features : instance ) CancelarPedido
parameter ZPC_A_CANCELAMENTO_INPUT result [1] $self;

// chamadas somente pelo BO Reembolso, via EML
action ( authorization : none ) CancelarPorReembolso result [1] $self;
action ( authorization : none ) RetomarPedido
parameter ZPC_A_RETOMADA_INPUT result [1] $self;

internal action RecalcularTotal;

determination DefinirStatusInicial on modify { create; }
determination AtualizarEndereco on modify { field ClienteUUID; }
determination GerarNumeroPedido on modify { create; }
determination CalcularTotalPedido on save { create; update; }
determination AtualizarFlagsStatus on modify { create; field StatusPedido; }
determination ReservarEstoqueRegistro on modify { create; update; } // reserva a diferença

validation ValidarCliente on save { create; field ClienteUUID; }
validation ValidarRegistro on save { create; update; } // endereço, itens, disponibilidade

draft action ( features : instance ) Edit; // habilitada só em pedido ABERTO
draft action Activate with additional implementation; // libera reserva de itens removidos
draft action Discard;
draft action Resume;
draft determine action Prepare
{
validation ValidarCliente;
validation ItemPedido~ValidarItemPedido;
validation ValidarRegistro;
}

side effects
{
field ClienteUUID affects field EnderecoUUID, field EnderecoPrincipalCompleto;
action SimularPagamento affects entity _Pagamento;
action AprovarPedido affects entity _ClienteSnapshot, entity _ItensSnapshot;
action CancelarPedido affects entity _ClienteSnapshot, entity _ItensSnapshot;
}

mapping for zta_pc_pedido { PedidoUUID = pedido_uuid; ... } // ver código-fonte
}
```

As entidades filhas (ItemPedido, Pagamento, ClienteSnapshot, ItemSnapshot) usam lock dependent by _Pedido, authorization dependent by _Pedido e etag master LocalLastChangedAt. ItemPedido possui update/delete, a determination CalcularValorItem e a validation ValidarItemPedido; Pagamento possui apenas internal update; os snapshots não possuem operações de modificação. O Reembolso deixou de ser filho do Pedido e tem BO próprio (seção 16.2).

## 16.2 Behavior Definition — Reembolso (root próprio, sem draft)

```abap
managed implementation in class zbp_r_pc_reembolso unique;
strict ( 2 );

define behavior for ZR_PC_REEMBOLSO alias Reembolso
persistent table zta_pc_reembolso
etag master LocalLastChangedAt
lock master
authorization master ( global )
{
create; // somente via EML do BO Pedido (não exposto na projection)
internal update;

field ( numbering : managed, readonly ) ReembolsoUUID;
field ( readonly : update ) PedidoUUID, NumeroPedido, ClienteUUID, StatusReembolso,
StatusPedidoAnterior, Currency, ValorReembolso,
MotivoSolicitacao, DataSolicitacao, SolicitadoPor;
field ( readonly ) MotivoDecisao, DataDecisao, DecididoPor,
CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt;

action ( features : instance ) AprovarReembolso
parameter ZPC_A_REEMB_DECISAO_INPUT result [1] $self;
action ( features : instance ) RejeitarReembolso
parameter ZPC_A_REEMB_DECISAO_INPUT result [1] $self;

mapping for zta_pc_reembolso { ReembolsoUUID = reembolso_uuid; ... } // ver código-fonte
}

// ZC_PC_REEMBOLSO_APP (projection): use etag; use action AprovarReembolso; use action RejeitarReembolso;
```

# 17. Mensagens de Erro e Sucesso

| Código | Mensagem |
|:---|:---|
| CLIENTE_CPF_INVALIDO | CPF inválido. Verifique o número informado. |
| CLIENTE_CPF_DUPLICADO | Já existe um cliente cadastrado com este CPF. |
| CLIENTE_INATIVO | Cliente inativo não pode realizar pedido. |
| CLIENTE_COM_PEDIDO | Cliente não pode ser excluído pois possui pedido vinculado. |
| CLIENTE_SEM_ENDERECO_PRINCIPAL | Cliente selecionado não possui endereço principal válido. |
| CEP_INDISPONIVEL | Não foi possível validar o CEP agora. Tente novamente em instantes. |
| CEP_INVALIDO | CEP inválido ou não encontrado. Verifique o número informado. |
| ENDERECO_NUMERO_OBRIGATORIO | Número do endereço é obrigatório. |
| FOTO_FORMATO_INVALIDO | Formato de imagem inválido. Utilize JPEG, PNG ou WEBP. |
| ITEM_SKU_DUPLICADO | Já existe item cadastrado com este SKU. |
| ITEM_ESTOQUE_INSUFICIENTE | Estoque insuficiente para o item &1 (disponível: &2). |
| ITEM_ESTOQUE_CONCORRENTE | Estoque do item &1 alterado por outra operação. Atualize e tente de novo. |
| ITEM_INATIVO | Item &1 inativo não pode ser usado em novo pedido. |
| ITEM_INATIVACAO_BLOQUEADA | Item possui estoque disponível ou pedido ativo. Inativação bloqueada. |
| PEDIDO_STATUS_INVALIDO | Transição de status não permitida (status atual: &1). |
| PEDIDO_PAGAMENTO_PENDENTE | Pagamento pendente. O pedido não pode ser finalizado. |
| PEDIDO_FINALIZADO_IMUTAVEL | Pedido finalizado não pode ser alterado. |
| PEDIDO_CANCELADO_IMUTAVEL | Pedido cancelado não pode ser alterado. |
| PEDIDO_MOTIVO_CANCEL_OBRIG | Informe o motivo do cancelamento. |
| PAGAMENTO_APROVADO | Pagamento aprovado com sucesso. |
| PAGAMENTO_RECUSADO | Pagamento recusado. O pedido permanecerá aguardando pagamento. |
| SNAPSHOT_EXISTENTE | Snapshot do pedido já foi gerado e não pode ser recriado. |
| CAMPO_OBRIGATORIO | Campo &1 é obrigatório. |
| EMAIL_INVALIDO | E-mail em formato inválido. |
| DATA_NASCIMENTO_FUTURA | Data de nascimento não pode ser futura. |
| TELEFONE_INVALIDO | Telefone deve conter 10 ou 11 dígitos (DDD + número). |
| PEDIDO_SEM_ITENS | Pedido deve possuir ao menos um item. |
| ITEM_QTDE_INVALIDA | Quantidade do item deve ser maior que zero. |
| ITEM_PRECO_INVALIDO | Preço unitário deve ser maior ou igual a zero. |
| ITEM_QTDE_ESTOQUE_INVALIDA | Qtde em estoque não pode ser negativa nem menor que a reservada (&1). |
| ITEM_EXCLUSAO_BLOQUEADA | Item não pode ser excluído pois está vinculado a pedido ou reserva. |
| CARTAO_DADOS_INVALIDOS | Dados do cartão inválidos: &1. |
| PEDIDO_CONFIRMADO | Pedido &1 registrado. Estoque reservado. |
| PEDIDO_FINALIZADO | Pedido &1 finalizado com sucesso. |
| PEDIDO_CANCELADO | Pedido &1 cancelado. |
| NUMERACAO_ERRO | Erro ao obter numeração (&1). Verifique o intervalo de numeração. |
| SEM_AUTORIZACAO | Usuário sem autorização para esta operação. |
| ITEM_RESERVA_INCONSISTENTE | Reserva do item &1 inconsistente com o pedido. |
| PEDIDO_EDICAO_BLOQUEADA | Pedido só pode ser editado ou excluído no status ABERTO. |
| ITEM_DIMENSAO_INVALIDA | Peso e dimensões não podem ser negativos. |
| VALOR_INVALIDO | Valor inválido para o campo &1. |
| PEDIDO_REEMBOLSO_SOLICITADO | Pedido &1 enviado para processamento de reembolso. |
| REEMBOLSO_MOTIVO_DECISAO_OBRIG | Informe o motivo da decisão sobre o reembolso. |
| REEMBOLSO_APROVADO | Reembolso do pedido &1 aprovado. Pedido cancelado. |
| REEMBOLSO_REJEITADO | Reembolso do pedido &1 rejeitado. Pedido retomado. |
| REEMBOLSO_STATUS_INVALIDO | Solicitação de reembolso não está mais pendente. |
| CEP_DUPLICADO_CLIENTE | Já existe um endereço cadastrado com este CEP para este cliente. |
| ITEM_SEM_ESTOQUE | Item &1 está sem estoque disponível e não pode ser adicionado ao pedido. |

As mensagens ficam na Message Class ZPC_MSG (textos com no máximo 73 caracteres, limite T100; &1/&2 são parâmetros) e são expostas pela classe de exceção ZCX_PC_MSG (IF_ABAP_BEHV_MESSAGE), cujas constantes têm no máximo 30 caracteres. A numeração 001–048 é mantida na Message Class ZPC_MSG (código-fonte).

# 18. Critérios de Aceite

## 18.1 Clientes

- Dado um usuário admin, quando cadastrar cliente com CPF válido e único, então o sistema deve salvar o CPF apenas com números e permitir exibição formatada.
- Dado um usuário comum, quando tentar criar, editar ou excluir cliente, então o sistema deve bloquear a operação por falta de permissão.
- Dado um cliente com pedido vinculado, quando o admin tentar excluí-lo, então o sistema deve bloquear a exclusão.
- Dado um cliente inativo, quando ele for selecionado em novo pedido, então o sistema deve bloquear o registro (Save) do pedido.
- Dado um upload de foto inválido, quando o cliente for salvo, então o sistema deve bloquear a persistência.
- Dado um endereço já gravado, quando o usuário tentar alterar o CEP, então o campo deve estar somente leitura (para trocar o CEP, excluir o endereço e cadastrar outro).

## 18.2 Estoque

- Dado um usuário admin, quando salvar um item com categoria selecionada, então o sistema deve gerar o SKU único automaticamente no Save, com as 3 primeiras letras da categoria (ex.: SKU-ELE-0000000001).
- Dado um item com QtdeEstoque = 10 e QtdeReservada = 3, quando recalcular disponibilidade, então QtdeDisponivel deve ser 7.
- Dado QtdeDisponivel = 0, quando recalcular status, então StatusEstoque deve ser SEM_ESTOQUE.
- Dado QtdeDisponivel entre 1 e 10, quando recalcular status, então StatusEstoque deve ser ACABANDO.
- Dado QtdeDisponivel >= 11, quando recalcular status, então StatusEstoque deve ser EM_ESTOQUE.
- Dado dois registros de pedido simultâneos para o mesmo item, quando o primeiro consumir a disponibilidade, então o segundo deve ser bloqueado caso não haja estoque suficiente.

## 18.3 Pedidos

- Dado um pedido em rascunho (draft), então nenhuma reserva de estoque deve ser realizada.
- Dado um rascunho com cliente ativo, endereço principal e itens com estoque disponível, quando o usuário salvar, então o pedido deve ser registrado como ABERTO e o estoque dos itens reservado.
- Dado um rascunho cujo estoque não cobre a quantidade de algum item (ou sem itens, ou sem endereço principal), quando o usuário salvar, então o registro deve ser bloqueado com a mensagem correspondente e nenhuma reserva gravada.
- Dado um pedido registrado (ABERTO), então ele oferece Editar (somente itens), Efetuar Pagamento e Cancelar, mas não Excluir; o cliente é somente leitura.
- Dado um pedido ABERTO, quando o usuário editar a quantidade de um item, incluir ou remover um item e salvar, então a reserva de estoque deve refletir apenas a diferença (e a remoção de um item libera a sua reserva).
- Dado um pedido FINALIZADO ou CANCELADO, quando abrir a Object Page, então deve ver as seções Dados do Cliente, Dados do Pedido, Itens, Pagamento e Finalização (ou Cancelamento), com cliente e itens lidos dos snapshots; nos demais status as seções Finalização e Cancelamento não aparecem e os dados vêm das tabelas principais.
- Dado um pedido ABERTO, quando o pagamento simulado (Efetuar Pagamento) for aprovado, então StatusPagamento deve ser APROVADO e StatusPedido deve ser AGUARDANDO_APROVACAO; se for recusado, o pedido continua ABERTO e uma nova tentativa é permitida.
- Dado um pagamento recusado, quando houver nova tentativa, então o sistema deve substituir os dados seguros da tentativa anterior.
- Dado um pedido em AGUARDANDO_APROVACAO, quando executar AprovarPedido, então o sistema deve baixar estoque reservado, gerar snapshots e alterar status para FINALIZADO.
- Dado um pedido cancelável sem pagamento aprovado, quando executar CancelarPedido com motivo, então o sistema deve liberar reserva, gerar snapshots e alterar status para CANCELADO.
- Dado um pedido com pagamento aprovado, quando executar CancelarPedido com motivo, então o sistema deve criar uma solicitação de reembolso PENDENTE e alterar o status para PROCESSANDO_REEMBOLSO, mantendo a reserva.
- Dado um pedido FINALIZADO ou CANCELADO, quando qualquer usuário tentar editá-lo, excluí-lo ou reabri-lo, então o sistema deve bloquear a operação.

## 18.4 Reembolsos

- Dada uma solicitação PENDENTE, quando o usuário executar Aprovar reembolso na aplicação Gestão de Reembolsos, então o reembolso deve ficar APROVADO, a reserva ser liberada, os snapshots gerados, o pedido CANCELADO e o pagamento DEVOLVIDO.
- Dada uma solicitação PENDENTE, quando o usuário executar Rejeitar reembolso sem informar o motivo, então a ação deve ser bloqueada; com motivo, o reembolso fica REJEITADO e o pedido retoma o status anterior à solicitação.
- Dada uma solicitação já decidida (APROVADO ou REJEITADO), então Aprovar e Rejeitar não devem estar disponíveis.

## 18.5 Aplicações Desacopladas

- Dado um usuário admin, quando acessar o Launchpad, então deve visualizar tiles para Clientes, Estoque, Pedidos e Reembolsos.
- Dado um usuário comum, quando acessar o Launchpad, então deve visualizar a aplicação de Pedidos e, quando configurado, consultas/value helps de cliente e estoque.
- Dado a aplicação Pedidos, quando selecionar cliente ou item, então deve consumir dados por value help/projections reutilizáveis e não por acoplamento direto de UI.
- Dado uma alteração posterior em cliente ou item, quando consultar pedido finalizado/cancelado, então o histórico deve ser exibido pelos snapshots.

# 19. Estrutura Recomendada do Projeto RAP

```text
ZAVBS_PC
|
+-- ZAVBS_PC_COMMON
| +-- ZIF_PC_CONSTANTS, ZCX_PC_MSG (+ Message Class ZPC_MSG)
| +-- ZCL_PC_UTIL, ZCL_PC_VIACEP, ZCL_PC_AUTH, ZCL_PC_NUMERACAO, ZCL_PC_SETUP
| +-- ZTA_PC_CODELIST / ZR_PC_CODELIST / ZC_PC_*_VH (CodeLists)
| +-- Number Range Object ZPC_NR, Authorization Objects ZPC_ADMIN / ZPC_PEDIDO
|
+-- ZAVBS_PC_CLIENTES
| +-- ZTA_PC_CLIENTE / ZTA_PC_CLIENTE_D, ZTA_PC_ENDERECO / ZTA_PC_ENDEREC_D
| +-- ZR_PC_CLIENTE / ZR_PC_ENDERECO
| +-- ZC_PC_CLIENTE_APP / ZC_PC_ENDERECO_APP (+ Metadata Extensions)
| +-- ZC_PC_CLIENTE_VH / ZC_PC_ENDERECO_VH / ZC_PC_CEP_VH
| +-- Behavior Definition ZR_PC_CLIENTE / Projection ZC_PC_CLIENTE_APP
| +-- Behavior Pool ZBP_R_PC_CLIENTE, Virtual Elements ZCL_PC_VE_CLIENTE
| +-- Service Definition ZUI_PC_CLIENTES / Binding ZUI_PC_CLIENTES_O4
| +-- IAM App ZPC_IAM_CLIENTES / Business Catalog ZPC_BC_CLIENTES
|
+-- ZAVBS_PC_ESTOQUE
| +-- ZTA_PC_ITEM / ZTA_PC_ITEM_D, ZR_PC_ITEM, ZC_PC_ITEM_APP, ZC_PC_ITEM_VH
| +-- Abstract Entity ZPC_A_QTDE_INPUT
| +-- Behavior Definition ZR_PC_ITEM / Projection ZC_PC_ITEM_APP, Behavior Pool ZBP_R_PC_ITEM
| +-- Service Definition ZUI_PC_ESTOQUE / Binding ZUI_PC_ESTOQUE_O4
| +-- IAM App ZPC_IAM_ESTOQUE / Business Catalog ZPC_BC_ESTOQUE
|
+-- ZAVBS_PC_PEDIDOS
+-- ZTA_PC_PEDIDO / ZTA_PC_PEDIDO_D, ZTA_PC_ITEM_PED / ZTA_PC_ITPED_D
+-- ZTA_PC_PAGAMENTO / ZTA_PC_PAGTO_D
+-- ZTA_PC_SNAP_CLI / ZTA_PC_SNPCLI_D, ZTA_PC_SNAP_ITM / ZTA_PC_SNPITM_D
+-- ZR_PC_PEDIDO / ZR_PC_ITEM_PEDIDO / ZR_PC_PAGAMENTO
+-- ZR_PC_PED_CLI_SNAP / ZR_PC_PED_ITEM_SNAP
+-- ZC_PC_PEDIDO_APP e projections filhas (+ Metadata Extensions)
+-- Abstract Entities ZPC_A_PAGAMENTO_INPUT / ZPC_A_CANCELAMENTO_INPUT / ZPC_A_RETOMADA_INPUT
+-- Behavior Definition ZR_PC_PEDIDO / Projection ZC_PC_PEDIDO_APP
+-- Behavior Pool ZBP_R_PC_PEDIDO, ZCL_PC_PAGAMENTO_SIM
+-- Service Definition ZUI_PC_PEDIDOS_COMPRAS / Binding ZUI_PC_PEDIDOS_COMPRAS_O4
+-- IAM App ZPC_IAM_PEDIDOS / Business Catalog ZPC_BC_PEDIDOS
+-- Reembolso: ZTA_PC_REEMBOLSO, ZR_PC_REEMBOLSO (root, sem draft),
| ZC_PC_REEMBOLSO_APP (+ Metadata Extension), ZC_PC_STATUSREEMB_VH,
| Abstract Entity ZPC_A_REEMB_DECISAO_INPUT,
| Behavior Definition ZR_PC_REEMBOLSO / Projection ZC_PC_REEMBOLSO_APP,
| Behavior Pool ZBP_R_PC_REEMBOLSO,
| Service Definition ZUI_PC_REEMBOLSOS / Binding ZUI_PC_REEMBOLSOS_O4
| IAM App ZPC_IAM_REEMBOLSOS / Business Catalog ZPC_BC_REEMBOLSOS (a criar no ADT)
+-- Obsoleta: tabela draft ZTA_PC_REEMB_D (antigo filho do Pedido) — pode ser excluída

ui5/ (quatro aplicações Fiori Elements V4 / BSP: ZPC_CLIENTES, ZPC_ESTOQUE, ZPC_PEDIDOS, ZPC_REEMBOLSOS)
+-- gestao-clientes, gestao-estoque, pedidos-compras, gestao-reembolsos
+-- analise-pedidos, analise-clientes, analise-estoque, analise-reembolsos (SAPUI5 freestyle)
```

No repositório, os pacotes acima ficam em `abap/` e servem aos dois cenários. A única classe com duas
versões é `ZCL_PC_VIACEP` (`ZCL_PC_VIACEP/` para o SAP BTP, ABAP environment e `ZCL_PC_VIACEP_T2/` para o
On-Premise); no On-Premise, `ZIF_PC_CONSTANTS` recebe `c_modo_trial = abap_false`. Ver
[`abap/README.md`](../abap/README.md) e a seção 26.

# 20. Deploy e Operação

- Desenvolvimento via ABAP Development Tools (ADT).
- Persistência no SAP HANA do ambiente (ABAP environment ou S/4HANA).
- Ativação na ordem: tabelas ZTA_\* → CDS base ZR_\* e CodeLists → value helps e abstract entities → tabelas draft ZTA_\*_D → projections e metadata extensions → behavior definitions → behavior pools → service definitions. O BO Reembolso (ZR_PC_REEMBOLSO) depende do Pedido apenas por EML; o Pedido referencia o BO Reembolso pelo create, então ZR_PC_REEMBOLSO e sua BDEF precisam estar ativos antes da behavior pool do Pedido.
- Criação manual (sem código-fonte): Message Class ZPC_MSG, domínio ZPC_NR_NUMC10, Number Range Object ZPC_NR e objetos de autorização ZPC_ADMIN / ZPC_PEDIDO.
- Execução da classe ZCL_PC_SETUP (F9) para criar os intervalos de numeração 01 (pedido) e 02 (SKU), carregar as CodeLists e os dados de demonstração. É pré-requisito para salvar o primeiro pedido ou item: sem os intervalos o Save falha com "Erro ao obter numeração". Também migra pedidos do modelo antigo de status (CRIADO/AGUARDANDO_PAGAMENTO/PROCESSANDO_REEMBOLSO) para o atual e recalcula os indicadores de status.
- Publicação de quatro Service Bindings OData V4 UI independentes (ZUI_PC_CLIENTES_O4, ZUI_PC_ESTOQUE_O4, ZUI_PC_PEDIDOS_COMPRAS_O4 e ZUI_PC_REEMBOLSOS_O4); o ADT só cria bindings V4 manualmente; a camada analítica usa o binding ZUI_PC_ANALITICO_O4 (serviço ZUI_PC_ANALITICO).
- Quatro aplicações Fiori Elements List Report/Object Page (pasta ui5/), publicadas no ABAP Repository com npm run deploy em cada app (BSP ZPC_CLIENTES, ZPC_ESTOQUE, ZPC_PEDIDOS e ZPC_REEMBOLSOS).
- Camada analítica: quatro aplicações SAPUI5 freestyle (ui5/analise-pedidos, analise-clientes, analise-estoque e analise-reembolsos), publicadas como BSPs ZPC_ANL_PEDIDOS, ZPC_ANL_CLIENTE, ZPC_ANL_ESTOQUE e ZPC_ANL_REEMB.
- Cenário On-Premise (SAP S/4HANA 2025 FPS01): ver seção 26.
- Configuração de IAM Apps, Business Catalogs e Business Roles (BTP) ou SU24 e roles PFCG (On-Premise).
- Exposição via Fiori Launchpad ou SAP Build Work Zone.
- Logs avançados e auditoria produtiva permanecem fora do escopo inicial.

# 21. Considerações de Segurança

- Controle de acesso por authorization control RAP, com Business Roles e IAM (BTP) ou roles PFCG (On-Premise).
- Validações críticas sempre no backend ABAP.
- Dados sensíveis de cartão nunca persistidos.
- CVV nunca salvo ou exibido.
- Número completo do cartão nunca salvo ou exibido.
- Validade completa do cartão nunca salva.
- Pedido finalizado e snapshots são imutáveis.
- Exclusão física controlada para preservar integridade histórica.
- Preferir inativação a exclusão em entidades de negócio.
- Operações críticas de estoque devem ser transacionais.
- A aplicação não deve confiar em cálculos enviados pela UI.
- Uploads de imagem devem validar MIME type e extensão permitida.

# 22. Conclusão

Esta especificação técnica consolida a versão SAP RAP do sistema de pedidos de compras em arquitetura desacoplada por aplicações. A solução mantém o escopo funcional original, mas reorganiza o projeto em quatro aplicações independentes: Gestão de Clientes, Gestão de Estoque, Pedidos de Compras e Gestão de Reembolsos.

O desenho adota nomenclatura RAP alinhada às boas práticas discutidas, usando tabelas ZTA_\* (e ZTA_\*_D para draft), root/base CDS view entities ZR_\*, projections ZC_\*, value helps ZC_\*_VH, behavior pools ZBP_R_\* e serviços OData V4 UI independentes.

A aplicação Pedidos de Compras se comunica com Clientes e Estoque por CDS reutilizáveis, value helps, associações e lógica transacional RAP no backend, e com a aplicação de Reembolsos por EML entre BOs, preservando desacoplamento de UI, consistência transacional e histórico imutável por snapshots.

# 23. Histórico de Revisões e Correções Técnicas

Versão 2.0 — revisão técnica para ABAP Cloud (strict mode 2) e alinhamento com o código-fonte gerado. O escopo funcional da versão 1.0 foi mantido; a tabela abaixo lista os ajustes.

| # | Seção | Problema na versão 1.0 | Correção na versão 2.0 |
|:---|:---|:---|:---|
| 1 | 4, 7.1, 19 | Nomes de tabela ZA_PC_ITEM_PEDIDO, ZD_PC_ITEM_PEDIDO, ZA_PC_PED_CLI_SNAP e ZA_PC_PED_ITEM_SNAP excedem o limite de 16 caracteres do ABAP Dictionary. | Renomeadas para ZA/ZD_PC_ITEM_PED, ZA/ZD_PC_SNAP_CLI e ZA/ZD_PC_SNAP_ITM (as CDS mantêm os nomes). |
| 2 | 7.1, 7.8, 8.3 | Snapshots definidos como filhos do BO com draft, porém "sem tabela draft" — o RAP exige tabela draft para toda entidade da composição. | Tabelas draft técnicas ZD_PC_SNAP_CLI/ZD_PC_SNAP_ITM (sempre vazias); snapshots só por internal create, sem update/delete. |
| 3 | 6.2, 15.2 | Disponibilidade das actions por status atribuída a get_instance_authorizations. | Status → feature control dinâmico (get_instance_features); perfil → authorization master ( global ). |
| 4 | 16.1 | BDEF sem with draft, total etag, Activate optimized, numbering : managed, campos readonly e mapping, obrigatórios em strict ( 2 ) com draft. | Behavior Definition completa na seção 16.1 e no código-fonte. |
| 5 | 16.1 | validation ValidarExclusaoPedido on save { delete; } — validations não são disparadas por delete. | delete ( features : instance ) no pedido; delete ( features : instance, precheck ) em cliente e item. |
| 6 | 16.1 | Parâmetros de action definidos como estruturas DDIC ZPC_S_\*. | Abstract entities ZPC_A_PAGAMENTO_INPUT e ZPC_A_CANCELAMENTO_INPUT. |
| 7 | 16, 16.1 | CalcularTotalPedido on modify no root não reage a mudanças nos itens (entidade filha). | CalcularValorItem no item + internal action RecalcularTotal; CalcularTotalPedido on save; total definitivo em ConfirmarPedido. |
| 8 | 16 | DefinirStatusInicial on save deixava o status vazio durante o draft. | on modify { create; }: CRIADO, PENDENTE e BRL já no draft. |
| 9 | 16.1 | Associações _Pagamento, _ClienteSnapshot e _ItensSnapshot sem create e sem with draft. | internal create + with draft; criação somente pelas actions. |
| 10 | 7.2 a 7.8 | Tipos: DEC(15,2) para valores sem moeda de referência; ABAP_BOOL (tipo, não elemento de dados); RAW(16)/UUID; SYSUNAME. | CURR(15,2) + CUKY, ABAP_BOOLEAN, SYSUUID_X16 e elementos ABP_\* nos campos administrativos. |
| 11 | 7.4, 15.1 | QtdeDisponivel virtual, mas usado como filtro da lista (elementos virtuais não são filtráveis). | Campo persistido, somente leitura, recalculado no backend. |
| 12 | 7.5, 15.1 | Lista de pedidos exige ID, data e status do pagamento sem campos correspondentes. | NumeroPedido (ZPC_NR/01), StatusPagamento replicado no pedido e CreatedAt como data do pedido. |
| 13 | 7.4 | Formato do SKU não definido. | SKU-\<3 letras da categoria>-\<10 dígitos> (ZPC_NR/02), validado como único. |
| 14 | 7.3, 10.2 | Logradouro sempre bloqueado, mas o ViaCEP não o retorna para CEP geral de município. | Campo CepGeral; Logradouro/Bairro editáveis e obrigatórios nesse caso (feature control). |
| 15 | 9.2, 12.5 | Movimentação de estoque sem mecanismo definido de acesso ao BO de estoque e de concorrência. | Actions internas do BO Item via EML, lock master do item, releitura sob lock e compensação em falha parcial. |
| 16 | 8.3, 10.4 | "Status editável" não definido. | Edição, exclusão e inclusão de itens somente em CRIADO; actions somente na instância ativa. |
| 17 | 17 | Textos com mais de 73 caracteres (limite T100) e códigos com mais de 30 caracteres (limite de constantes). | Textos reduzidos; PEDIDO_PAGAMENTO_PENDENTE e PEDIDO_MOTIVO_CANCEL_OBRIG; 19 mensagens complementares. |
| 18 | 4, 6.1 | Faltavam objetos de autorização, o sufixo _EXT das IAM Apps e o tratamento do ambiente Trial. | Objetos ZPC_ADMIN/ZPC_PEDIDO, classe ZCL_PC_AUTH e constante C_MODO_TRIAL. |
| 19 | 6.2 | @AccessControl.authorizationCheck: #CHECK sem Access Control (DCL) não restringe a leitura. | #NOT_REQUIRED documentado; DCL apenas se houver requisito de leitura por instância. |
| 20 | 7.1 | CodeLists indefinidas (ZA_PC_\*_TXT ou fixed values). | Tabela ZA_PC_CODELIST (código, descrição, criticality) + value helps ZC_PC_\*_VALUEHELP. |
| 21 | 13 | Recusa de pagamento e dados de cartão inválidos não eram diferenciados. | Dado inválido → erro CARTAO_DADOS_INVALIDOS; CVV 000 → RECUSADO (aviso, nova tentativa permitida). |
| 22 | 12.2, 12.3 | Numeração das listas continuava de 12 a 27. | Listas reiniciadas em 1. |

Versão 2.1 — alterações aplicadas depois da versão 2.0: Reembolso como aplicação própria, registro do pedido com reserva automática (sem ConfirmarPedido), SKU gerado no Save e ajustes de nomenclatura/escopo já presentes no código.

| # | Seção | Situação na versão 2.0 | Alteração na versão 2.1 |
|:---|:---|:---|:---|
| 1 | 2.1, 8.3, 10.4, 11, 12.1, 16, 17 | Action ConfirmarPedido validava e reservava o estoque (CRIADO → AGUARDANDO_PAGAMENTO). | Action removida. O Save do rascunho registra o pedido (CRIADO) e a determination ReservarEstoqueRegistro reserva o estoque; a validation ValidarRegistro bloqueia o Save sem endereço principal, sem itens ou sem disponibilidade. Mensagem 033: "Pedido &1 registrado. Estoque reservado." Activate deixa de ser "optimized" para que a determination dispare. |
| 2 | 5, 8.3, 10.4, 15.2 | Pedido CRIADO podia ser editado e excluído. | Pedido registrado (ativo) não oferece Edit nem Delete e não recebe itens; apenas SimularPagamento, AprovarPedido e CancelarPedido. |
| 3 | 11 | SimularPagamento exigia AGUARDANDO_PAGAMENTO. | Aceita CRIADO ou AGUARDANDO_PAGAMENTO; recusa leva/mantém AGUARDANDO_PAGAMENTO. |
| 4 | 3.1, 8.4, 15, 16.2, 19 | Reembolso era filho do Pedido (aba "Reembolsos"; actions no Pedido) e não constava desta especificação. | BO próprio ZR_PC_REEMBOLSO (root, sem draft, tabela ZTA_PC_REEMBOLSO), projection ZC_PC_REEMBOLSO_APP e quarta aplicação Gestão de Reembolsos (ZUI_PC_REEMBOLSOS / ZUI_PC_REEMBOLSOS_O4) com as actions AprovarReembolso e RejeitarReembolso. |
| 5 | 8.3, 12.4 | AprovarReembolso/RejeitarReembolso eram actions do BO Pedido. | O Pedido expõe apenas as actions internas CancelarPorReembolso e RetomarPedido (authorization : none); o BO Reembolso as executa por EML na mesma LUW. Nova abstract entity ZPC_A_RETOMADA_INPUT. |
| 6 | 7.4, 8.2, 16 | SKU gerado na ativação; itens criados ou editados saíam com prefixo XXX. | GerarSku passa a rodar no Save (on save, também no Prepare), usa as 3 primeiras letras da categoria selecionada (X se houver menos de 3) e regenera o SKU se a categoria mudar. |
| 7 | 4, 7.1, 19, 20 | Nomes ZA_\*/ZD_\*, value helps \*_VALUEHELP e pacotes ZPK_\*. | Nomes reais do código: tabelas ZTA_PC_\* e draft ZTA_PC_\*_D (abreviadas), value helps ZC_PC_\*_VH e pacotes ZAVBS_PC_\*. |
| 8 | 7.4, 7.8 | Item e snapshots com peso, altura, largura e profundidade. | Atributos removidos do modelo do item e dos snapshots. |
| 9 | 7.3, 17 | CEP sem unicidade por cliente. | CEP único por cliente (mensagem CEP_DUPLICADO_CLIENTE) e value help ZC_PC_CEP_VH. |
| 10 | 10.4, 17 | Item sem estoque podia ser adicionado ao rascunho. | Precheck da inclusão de item: QtdeDisponivel = 0 bloqueia na hora (mensagem ITEM_SEM_ESTOQUE). |
| 11 | 15.1 | Score do cliente exibido como número. | Score exibido como indicador de progresso (Process Indicator). |
| 12 | 20 | Intervalos de ZPC_NR sem destaque como pré-requisito. | ZCL_PC_SETUP (F9) é pré-requisito: sem os intervalos 01 e 02 o Save de pedido e de item falha com "Erro ao obter numeração". |
| 13 | 7.2, 7.4, 17 | Imagens de cliente e item: apenas JPEG ou PNG. | WEBP passa a ser aceito (image/webp): validar_imagem confere MIME, extensão .webp e assinatura RIFF....WEBP; acceptableMimeTypes das views e mensagem 009 atualizados. |
| 14 | 7.2 | Score do cliente exibido como número na barra de progresso, sem cor dinâmica. | Score exibido em % (unidade % por virtual element) e barra com criticidade calculada: vermelho até 40, amarelo de 40 a 70, verde a partir de 70. |

Versão 2.2 — novo modelo de status do pedido, edição dos itens do pedido aberto, Object Page dinâmica, correção do dump ao alterar o CEP, camada analítica e suíte permanente de testes.

| # | Seção | Situação na versão 2.1 | Alteração na versão 2.2 |
|:---|:---|:---|:---|
| 1 | 2.1, 8.3, 10.4, 11, 16, 18.3 | Status CRIADO, AGUARDANDO_PAGAMENTO, AGUARDANDO_APROVACAO, FINALIZADO, PROCESSAR_REEMBOLSO e CANCELADO. | Cinco status: ABERTO (renomeia CRIADO), AGUARDANDO_APROVACAO, PROCESSANDO_REEMBOLSO (renomeia PROCESSAR_REEMBOLSO), CANCELADO e FINALIZADO. AGUARDANDO_PAGAMENTO foi removido: pagamento recusado mantém o pedido ABERTO. |
| 2 | 7.5, 7.7, 12.4, 13 | StatusPagamento: PENDENTE, APROVADO, RECUSADO. | Novo status DEVOLVIDO, aplicado ao pagamento e ao pedido quando o reembolso é aprovado. |
| 3 | 8.3, 10.4, 12.7 | Pedido registrado não podia ser editado. | Pedido ABERTO permite editar só os itens (Edit + Save); ClienteUUID mandatory:create / readonly:update; reserva incremental (ReservarEstoqueRegistro on { create; update; } + Activate com implementação adicional). |
| 4 | 15.4, 7.5 | Object Page com seções estáticas (Dados administrativos, Histórico - cliente, Histórico - itens). | Seções dinâmicas: Dados do Cliente, Dados do Pedido (com os campos administrativos), Itens, Pagamento, Finalização/Cancelamento; origem dos dados (snapshot ou tabelas principais) conforme o status; indicadores persistidos mantidos por AtualizarFlagsStatus e hidden: #(Campo). |
| 5 | 5, 15.2, 16, 18 | Ações Simular Pagamento e Aprovar / finalizar. | Rótulos Efetuar Pagamento e Aprovar pedido (nomes técnicos SimularPagamento e AprovarPedido mantidos). |
| 6 | 7.3, 8.1, 10.2, 16 | CEP editável em endereço gravado; a alteração gerava RAISE_SHORTDUMP (UPDATE com sy-subrc 4 em ZTA_PC_ENDERECO, pois o CEP é chave da tabela mas não da entidade). | CEP somente leitura depois que o endereço é gravado (field ( features : instance ) Cep). Para trocar, excluir o endereço e cadastrar outro. |
| 7 | 20 | Pedidos existentes no modelo antigo de status. | ZCL_PC_SETUP migra CRIADO/AGUARDANDO_PAGAMENTO para ABERTO e PROCESSAR_REEMBOLSO para PROCESSANDO_REEMBOLSO, e recalcula os indicadores. |
| 8 | 2.1, 20, 24 | Sem camada analítica. | Cubos ZI_PC_\*_CUBE, consultas ZC_PC_\*_ANALISE, serviço ZUI_PC_ANALITICO, 20 ALPs e o Painel de Compras (OVP). |
| 9 | 2.2, 25 | Testes automatizados fora do escopo; classes de teste temporárias. | Suíte ABAP Unit permanente (50 testes em ZCL_PC_UTIL), mantida no SAP e no repositório e ajustada junto com as funcionalidades. |

Versão 2.3 — especificação em Markdown, diagramas num único arquivo, camada analítica atualizada e cenário On-Premise.

| # | Seção | Situação na versão 2.2 | Alteração na versão 2.3 |
|:---|:---|:---|:---|
| 1 | todas | Documento somente em Word (.docx). | Versão em Markdown (este arquivo), versionada junto com o código; o .docx v2.2 permanece como histórico. |
| 2 | 2.1, 20, 24 | Camada analítica com 20 ALPs e o Painel de Compras (OVP). | Quatro aplicações SAPUI5 freestyle, uma por domínio (5 análises cada), sobre o mesmo serviço ZUI_PC_ANALITICO, como já implementado no repositório (v2.5 do README). |
| 3 | 19 | Fontes ABAP numa única pasta. | abap/abap-environment (cenário principal, fonte completa) e abap/on-premise (somente as diferenças). |
| 4 | 26 (nova) | Sem cenário On-Premise na especificação (apenas tutoriais avulsos). | Implementação no SAP S/4HANA 2025 FPS01: arquitetura, pré-requisitos, passo a passo, limitações e diferenças em relação ao SAP BTP, ABAP environment. |
| 5 | capa, 26.1 | Seis arquivos draw.io separados. | Um único arquivo (diagramas/pedidos-de-compras.drawio) com uma página por diagrama, incluindo a nova arquitetura On-Premise (página 7). |

Versão 2.4 — projeto orientado aos dois ambientes (SAP BTP, ABAP environment e SAP S/4HANA On-Premise), com o foco no framework RAP.

| # | Seção | Situação na versão 2.3 | Alteração na versão 2.4 |
|:---|:---|:---|:---|
| 1 | 1, 3, 6, 20, 21 | Texto centrado no SAP BTP ABAP Environment Trial. | Os dois ambientes descritos lado a lado; segurança com IAM/Business Roles (BTP) ou SU21/SU24/PFCG (On-Premise). |
| 2 | 19, 26 | Código On-Premise em abap/on-premise, com pacotes ABAP for Cloud Development, subpacote tier 2 ZAVBS_PC_COMMON_T2 e contrato C1 para ZCL_PC_VIACEP. | Um único diretório abap/; no On-Premise os pacotes são Standard ABAP e todos os objetos RAP ativam sem erros; ZCL_PC_VIACEP tem a versão On-Premise em ZCL_PC_VIACEP_T2/. Tier 1 + C1 ficam como opção. |
| 3 | 26 | Tutoriais de ViaCEP, autorização e DCL em docs/. | Reunidos em abap/README.md (seções 5 a 7), para os dois cenários. |


# 24. Camada Analítica

A camada analítica é somente leitura e independente dos aplicativos de gestão. Cada domínio tem um cubo de análise (ZI_PC_\*_CUBE) e uma consulta (ZC_PC_\*_ANALISE) com @Aggregation.default nas medidas e @OData.applySupportedForAggregation: #FULL, o que permite ao servidor aceitar $apply=groupby/aggregate. Gráficos e filtros vêm das metadata extensions ZC_PC_\*_ANALISE: cada cenário é um UI.Chart mais uma UI.PresentationVariant com qualifier.

- Serviço: ZUI_PC_ANALITICO (Service Binding ZUI_PC_ANALITICO_O4, OData V4 UI), no pacote ZAVBS_PC_COMMON.
- Pedidos: ZI_PC_PEDIDO_CUBE → ZC_PC_PEDIDO_ANALISE. Clientes: ZI_PC_CLIENTE_CUBE → ZC_PC_CLIENTE_ANALISE. Estoque: ZI_PC_ITEM_CUBE → ZC_PC_ITEM_ANALISE. Reembolsos: ZI_PC_REEMB_CUBE → ZC_PC_REEMB_ANALISE.
- Quatro aplicações SAPUI5 freestyle, uma por domínio, cada uma com 5 análises (20 no total): painel com filtros, indicadores e gráficos (sap.viz) e uma página de detalhe por análise (troca do tipo de gráfico e tabela de valores). As consultas usam $apply (filter, groupby, aggregate) sobre o entity set do domínio; o botão Abrir gestão navega para o app de gestão correspondente.

| Aplicação | Pasta | Entity set | Tile (semantic object) | BSP / pacote |
|:---|:---|:---|:---|:---|
| Análise de Pedidos de Compras | ui5/analise-pedidos | PedidoAnalise | ZPCAnalisePedido-display | ZPC_ANL_PEDIDOS / ZAVBS_PC_PEDIDOS |
| Análise de Clientes | ui5/analise-clientes | ClienteAnalise | ZPCAnaliseCliente-display | ZPC_ANL_CLIENTE / ZAVBS_PC_CLIENTES |
| Análise de Itens do Estoque | ui5/analise-estoque | ItemAnalise | ZPCAnaliseItemEstoque-display | ZPC_ANL_ESTOQUE / ZAVBS_PC_ESTOQUE |
| Análise de Pedidos de Reembolsos | ui5/analise-reembolsos | ReembolsoAnalise | ZPCAnaliseReembolso-display | ZPC_ANL_REEMB / ZAVBS_PC_REEMBOLSOS |

- Elas substituem o app único analise-compras (BSP ZPC_ANALISE) e as propostas anteriores de ALP/Overview Page.
- Os gráficos dependem de agregação no servidor; para ter dados é preciso carregar os dados de demonstração (ZCL_PC_SETUP). Os apps passam no ESLint, no ui5 build e na suíte QUnit e foram testados no launchpad local com o mock server; a verificação em execução no launchpad do sistema ainda está pendente.

# 25. Testes Automatizados

As classes de teste ABAP Unit são permanentes: ficam no sistema SAP e no repositório e são ajustadas sempre que a funcionalidade que cobrem muda. Os testes de integração semeiam os próprios dados por INSERT (o ABAP Unit desfaz a gravação) e executam no máximo um Edit por teste, pois um rascunho sobrevive ao Activate dentro da mesma LUW. A classe ZCL_PC_UTIL tem 50 testes, todos passando.

- ltcl_digitos_cpf, ltcl_email_imagem e ltcl_estoque_endereco: CPF, telefone, e-mail, imagens (JPEG/PNG/WEBP), status de estoque e endereço formatado.
- ltcl_edicao_pedido: alterar, incluir e remover item com reserva incremental; apenas pedido ABERTO é editável.
- ltcl_registro_pedido: o Save cria o pedido ABERTO, o número e a reserva; nunca se reserva acima do estoque.
- ltcl_ciclo_pedido: pagamento aprovado e recusado, aprovação com baixa de estoque, cancelamento com e sem pagamento aprovado (reembolso).
- ltcl_reembolso: aprovar cancela o pedido, devolve o pagamento e libera a reserva; rejeitar exige motivo e retoma o pedido.
- ltcl_sku_item: SKU com prefixo da categoria e sequencial único (exige o objeto de numeração ZPC_NR configurado).
- ltcl_persistencia_endereco: save real (COMMIT ENTITIES) com test doubles (cl_cds_test_environment para as entidades ZR_\* e cl_osql_test_environment para as tabelas de rascunho); cobre endereço novo direto e por rascunho e o CEP somente leitura.
- Também permanentes: ZCL_PC_PAGAMENTO_SIM (14 testes), ZCL_PC_IMPORTACAO (17) e ZCL_PC_PLANILHA (17).
- Depois de editar um include de testes, ativar também o include testclasses; senão o ABAP Unit executa a versão antiga.

# 26. Implementação no cenário On-Premise (SAP S/4HANA 2025 FPS01)

O cenário principal desta especificação é o **SAP BTP, ABAP environment**. Esta seção ensina a implantar a
mesma solução num **SAP S/4HANA 2025 FPS01 On-Premise** (ABAP Platform 2025); o roteiro vale também para o
SAP S/4HANA Cloud Private Edition 2025, em que a infraestrutura é operada pela SAP.

A ideia central: o framework RAP é o mesmo no ABAP environment e no S/4HANA 2025. No On-Premise os pacotes
são criados com a versão de linguagem **Standard ABAP**, e **todos os objetos RAP do projeto são criados e
ativados normalmente, sem erros** — tabelas, CDS, behavior definitions e pools, serviços, classes e testes.
Só dois objetos mudam de conteúdo (`ZIF_PC_CONSTANTS` e `ZCL_PC_VIACEP`). O que
muda é tudo o que o BTP fornece como serviço gerenciado: identidade e autorização, conectividade de saída,
launchpad, ciclo de vida do sistema e transporte.

## 26.1 Arquitetura de implementação

<p align="center">
  <a href="../assets/arquitetura-onpremise.png"><img src="../assets/arquitetura-onpremise.png" alt="Arquitetura On-Premise: usuários via SAP Web Dispatcher, SAP Fiori launchpad e SAP Gateway embarcados no SAP S/4HANA 2025 FPS01, BOs RAP em pacotes Standard ABAP, ZCL_PC_VIACEP com SM59 e STRUST, proxy de saída, firewall e API ViaCEP" width="100%"></a>
</p>

Fonte editável: página 7 de [`diagramas/pedidos-de-compras.drawio`](../diagramas/pedidos-de-compras.drawio).

1. O usuário acessa pelo navegador o **SAP Web Dispatcher** (HTTPS), ponto único de entrada da intranet,
   com SSO por SAML 2.0 ou Kerberos/SPNego.
2. O **SAP Fiori launchpad** embarcado (componente SAP_UI do front-end server 2025, SAPUI5 1.136) exibe os
   tiles dos espaços e páginas atribuídos às roles do usuário e abre as oito aplicações (BSPs no ABAP
   Repository, servidas por `/sap/bc/ui5_ui5`).
3. As aplicações chamam os serviços **OData V4** publicados no **SAP Gateway** embarcado
   (`/sap/opu/odata4/...`). O acesso a cada grupo de serviços é verificado pelo objeto `S_START`.
4. Os serviços expõem os **BOs RAP** (pacotes Standard ABAP). As regras de negócio, o EML entre BOs e o
   draft funcionam exatamente como no BTP; os dados ficam no **SAP HANA** do próprio sistema.
5. Para consultar o CEP, o BO Cliente chama **`ZCL_PC_VIACEP`** (versão On-Premise, pasta
   `ZCL_PC_VIACEP_T2/`). Ele usa `CL_HTTP_CLIENT` com a destination **`Z_VIACEP`** (SM59) e a
   confiança TLS do **STRUST**, sai pelo **proxy** da DMZ, atravessa o **firewall** e chega à **API ViaCEP**.
6. O desenvolvimento ocorre no **Eclipse + ADT** (e SAP GUI para Basis) no sistema DEV; o front-end é
   publicado com o **SAP Fiori tools**; tudo segue por **transporte** (STMS) para QAS e PRD.

## 26.2 Componentes e versões de referência

| Componente | Referência no S/4HANA 2025 FPS01 | Observação |
| --- | --- | --- |
| Sistema | SAP S/4HANA 2025, Feature Package Stack 01 | Confirme em *Sistema → Status → Versões de componentes* (tabela `CVERS`). |
| ABAP Platform | ABAP Platform 2025 (`SAP_BASIS` 816) | RAP managed com draft, `strict ( 2 )`, EML, CDS view entities e ABAP Cloud no próprio sistema. |
| SAP Gateway | `SAP_GWFND` embarcado (*embedded deployment*) | OData V4 publicado em `/IWFND/V4_ADMIN`; alias de sistema `LOCAL`. |
| SAP Fiori front-end server | FES 2025 embarcado (`SAP_UI`), SAPUI5 1.136 (manutenção de longo prazo) | Atende ao requisito das apps (`manifest.json` com descriptor v2, SAPUI5 ≥ 1.136). |
| Banco de dados | SAP HANA 2.0 (SPS conforme a PAM do S/4HANA 2025) | Mesmo papel do SAP HANA do ABAP environment. |
| Acesso | SAP Web Dispatcher | Recomendado; em laboratório, o acesso direto ao ICM também funciona. |
| Ferramentas | Eclipse + ADT atualizado, SAP GUI 8.00+, Node.js 20+, VS Code ou BAS com SAP Fiori tools | As mesmas do cenário principal, mais o SAP GUI para as transações de Basis e segurança. |

> As versões de componente (`SAP_BASIS`, `SAP_UI`/SAPUI5) devem ser conferidas no sistema alvo (`CVERS` e
> *Sobre* do launchpad) e na nota de release do FPS: a especificação usa os valores do pacote de entrega padrão.

## 26.3 Pré-requisitos

- Sistema S/4HANA 2025 FPS01 com cliente de desenvolvimento aberto para objetos de repositório (`SCC4`),
  **landscape de transporte** configurado (`STMS`: DEV → QAS → PRD) e chave de desenvolvedor, se exigida.
- **SAP Gateway** embarcado ativo (`/IWFND/V4_ADMIN` acessível, alias `LOCAL`) e serviços ICF ativos em
  `SICF`: `/sap/bc/adt`, `/sap/bc/ui5_ui5`, `/sap/bc/ui2/flp`, `/sap/opu/odata4` e
  `/sap/opu/odata/ui5/abap_repository_srv` (deploy das BSPs).
- **ATC** configurado com a variante padrão da empresa (opcionalmente, a variante
  `ABAP_CLOUD_DEVELOPMENT_DEFAULT` para avaliar a prontidão do código para ABAP Cloud).
- Usuário de desenvolvimento com acesso ao ADT (`S_ADT_RES`, `S_DEVELOP`, `S_RFC`) e, para Basis/segurança,
  às transações `SM59`, `STRUST`, `SNRO`, `SU21`, `SU24`, `PFCG`, `SU01`, `/IWFND/V4_ADMIN`,
  `/UI2/FLPAM`, `/UI2/FLPCM_CUST`, `SU53` e `STAUTHTRACE` (ou apoio das equipes responsáveis).
- **Saída para a internet** a partir do servidor de aplicação até `viacep.com.br:443`, direta ou por proxy,
  liberada no firewall.

## 26.4 Passo a passo

### Passo 1 — Pacotes, software component e versão de linguagem

1. Crie o pacote principal `ZAVBS_PEDIDOS_COMPRAS` (ou sob um pacote de estrutura da empresa) com uma
   **camada de transporte** do landscape. No BTP os pacotes eram do software component `ZLOCAL`, sem
   transporte; aqui todo objeto vai para uma ordem Workbench.
2. Crie os subpacotes `ZAVBS_PC_COMMON`, `ZAVBS_PC_CLIENTES`, `ZAVBS_PC_ESTOQUE`, `ZAVBS_PC_PEDIDOS`
   (com `ZAVBS_PC_PEDIDOS_PAGAMENTOS` e `ZAVBS_PC_PEDIDOS_SNAPSHOTS`) e `ZAVBS_PC_REEMBOLSOS` com a versão de
   linguagem **Standard ABAP**. Todos os objetos RAP do projeto ativam sem erros nessa versão, e
   `ZCL_PC_VIACEP` pode usar `CL_HTTP_CLIENT` sem subpacote separado nem contrato de liberação.
3. (Opcional) Para seguir o modelo *tier 1* (ABAP Cloud no próprio S/4HANA), crie os subpacotes com
   *ABAP for Cloud Development*; nesse caso `ZCL_PC_VIACEP` precisa ficar num subpacote Standard ABAP,
   liberada com o contrato **C1** (*Use in Cloud Development*) antes de ativar `ZBP_R_PC_CLIENTE`
   ([`abap/README.md`](../abap/README.md#4-roteiro-no-sap-on-premise)).

### Passo 2 — Objetos criados manualmente

| Objeto | Onde criar no On-Premise | Valores |
| --- | --- | --- |
| Message Class `ZPC_MSG` | ADT ou `SE91` | Mensagens de `ZAVBS_PC_COMMON/Texts/ZPC_MSG.msagn.xml` (seção 17). |
| Domínio `ZPC_NR_NUMC10` | ADT ou `SE11` | NUMC 10, *Number Length Domain* de `ZPC_NR`. |
| Objeto de numeração `ZPC_NR` | `SNRO` | Domínio `ZPC_NR_NUMC10`, sem subobjeto, **buffer em memória principal** com 10 números (sem buffer, `GET NUMBER` faz `UPDATE` síncrono na `NRIV` e o save RAP termina em `BEHAVIOR_ILLEGAL_STATEMENT`). |
| Classe de objetos `ZPC` e objetos `ZPC_ADMIN`, `ZPC_PEDIDO` | `SU21` | Campo `ACTVT`; `ZPC_ADMIN`: 01, 02, 03, 06; `ZPC_PEDIDO`: 01, 02, 03, 06, **16**. No BTP eles ficavam na classe `CPAE`. |
| Índices secundários | ADT ou `SE11` | Os mesmos do cenário principal (`CPF` e `SKU` únicos; `ITEM_UUID`, `CLIENTE_UUID`). |

### Passo 3 — Importar os fontes

1. Crie os objetos de [`abap/`](../abap) na mesma ordem do cenário
   principal (README, *Ordem de criação e ativação*): interfaces e classes base → tabelas → CDS base →
   abstract entities e value helps → tabelas draft (*quick fix* `Create draft table`) → projeções e
   metadata extensions → behavior definitions e pools → service definitions e bindings.
2. **Ajuste** dois objetos:
   - `ZIF_PC_CONSTANTS` com `c_modo_trial = abap_false` (as verificações de `ZCL_PC_AUTH` passam a valer);
   - `ZCL_PC_VIACEP` com o conteúdo de `ZCL_PC_VIACEP_T2/` no pacote `ZAVBS_PC_COMMON`, com `CL_HTTP_CLIENT`
     e a destination `Z_VIACEP` (mesma interface pública da versão BTP; o behavior pool `ZBP_R_PC_CLIENTE`
     não muda).
3. **Não importe** os objetos exclusivos do BTP: IAM Apps (`*.sia6.xml`), o serviço de entrada
   `*_G4BA` (*Cloud Communication Management*), os valores propostos `*.sush.xml`, os objetos de
   autorização da classe `CPAE` (recriados no passo 2) e a tabela draft residual `ZTA_PC_REEMB_D`.
4. O repositório guarda os fontes no formato do ADT (um arquivo por objeto), não no formato abapGit: a
   criação é feita no ADT copiando cada fonte, como no BTP. Para automatizar, converta para abapGit ou gCTS.

### Passo 4 — Conectividade com o ViaCEP (SM59, STRUST e proxy)

| Item | Configuração |
| --- | --- |
| Destination | `SM59` → *Conexões HTTP com servidor externo* (tipo **G**) `Z_VIACEP`: host `viacep.com.br`, porta `443`, *Path Prefix* vazio, *Sem logon*, SSL **ativo** com a PSE *SSL Client (Anônimo)*; proxy HTTP(S) da empresa, se houver. |
| Certificados | `STRUST` → PSE *SSL Client Anônimo*: importar a cadeia da autoridade certificadora do ViaCEP (raiz e intermediárias) e gravar. Renovar quando a cadeia mudar. |
| Rede | Regra de firewall/proxy para `viacep.com.br:443` a partir dos servidores de aplicação. |
| Teste | Report `ZPC_TESTE_VIACEP` (em `abap/ZAVBS_PC_COMMON/.../ZPC_TESTE_VIACEP_T2/`): deve retornar HTTP 200 e o endereço para um CEP válido. |

O passo a passo detalhado, com o diagnóstico de `SSSLERR_PEER_CERT_UNTRUSTED`, timeout e status HTTP, está em
[`abap/README.md`, seção 5](../abap/README.md#5-consulta-de-cep-viacep-nos-dois-cenários).

### Passo 5 — Publicar os serviços OData V4

1. Publique os bindings `ZUI_PC_CLIENTES_O4`, `ZUI_PC_ESTOQUE_O4`, `ZUI_PC_PEDIDOS_COMPRAS_O4`,
   `ZUI_PC_REEMBOLSOS_O4` e `ZUI_PC_ANALITICO_O4` pelo botão *Publish* do ADT ou em `/IWFND/V4_ADMIN`
   (*Publish Service Groups*, alias `LOCAL`). Cada binding vira um **grupo de serviços** OData V4.
2. A publicação é feita em **cada sistema** (DEV, QAS e PRD) ou transportada como customizing, conforme a
   política do landscape.
3. Teste no *preview* do binding (ADT) antes de seguir para o front-end.

### Passo 6 — Autorizações (SU24 e PFCG)

| Etapa | No On-Premise |
| --- | --- |
| Valores propostos | `SU24`: grupo de serviços (tipo `G4BA`) → `ZPC_ADMIN` (01, 02, 03, 06) para Clientes e Estoque; `ZPC_PEDIDO` (01, 02, 03, 06, 16) para Pedidos; `ZPC_PEDIDO` (03, 16) para Reembolsos. |
| Roles | `PFCG`: `Z_PC_ADMIN` (quatro serviços + análises; `ZPC_ADMIN` completo; `ZPC_PEDIDO` completo) e `Z_PC_COMUM` (Pedidos e Reembolsos; `ZPC_ADMIN` 03; `ZPC_PEDIDO` conforme o processo). O menu da role recebe os serviços (gera `S_START`) e o conteúdo do launchpad (passo 9). |
| Usuários | `SU01`/`PFCG` + comparação de usuários. A atribuição **não é transportada**: é feita em cada sistema (ou por CUA/IdM). |
| Diagnóstico | `SU53`, `STAUTHTRACE`, `SUIM`. |

O roteiro completo, inclusive testes com `CL_AUNIT_AUTHORITY_CHECK`, está em
[`abap/README.md`, seção 6](../abap/README.md#6-autorização-authority-check-nos-dois-cenários). Se for
preciso restringir também a **leitura**, siga a [seção 7 (DCL)](../abap/README.md#7-controle-de-leitura-nas-cds-views-com-access-control-dcl), que
funciona igual nos dois cenários.

### Passo 7 — Carga inicial (numeração e CodeLists)

1. Em **DEV e QAS**, execute `ZCL_PC_SETUP` (F9 no ADT): cria os intervalos `01` (pedido) e `02` (SKU) de
   `ZPC_NR`, recarrega `ZTA_PC_CODELIST` e grava os **dados de demonstração** (100 clientes, 100 itens e 100
   pedidos). Sem os intervalos, o Save falha com "Erro ao obter numeração".
2. Em **PRD**, não execute o setup como está, porque ele carrega os dados de demonstração. Crie os intervalos
   `01` e `02` na `SNRO` (faixas de `ZIF_PC_CONSTANTS=>c_numeracao`) e transporte o conteúdo de
   `ZTA_PC_CODELIST` (entrada `R3TR TABU` na ordem) ou use uma variante do setup sem a carga de demonstração.
3. `ZCL_PC_RESET` só apaga dados com `c_modo_trial = abap_true`; no On-Premise ele se recusa a executar, o
   que protege QAS e PRD.

### Passo 8 — Front-end: deploy das aplicações (BSP)

Cada app em `ui5/` é publicada com `npm run deploy`, como no BTP; o que muda é o destino em
`ui5-deploy.yaml` (e o backend do proxy em `ui5.yaml`, para `npm start`):

```yaml
customTasks:
  - name: deploy-to-abap
    afterTask: generateCachebusterInfo
    configuration:
      ignoreCertErrors: false
      target:
        url: https://s4h2025.empresa.local:44300   # Web Dispatcher ou ICM do sistema DEV
        client: "100"
      credentials:
        username: env:ABAP_USER                    # variáveis de ambiente, nunca no arquivo
        password: env:ABAP_PASSWORD
      app:
        name: ZPC_PEDIDOS
        description: Pedidos de Compras
        package: ZAVBS_PC_PEDIDOS
        transport: S4DK900123                      # ordem Workbench (obrigatória fora do ZLOCAL)
      exclude:
        - /test/
```

- No BTP o deploy também gera a IAM App `<BSP>_UI5R`; no On-Premise é criada apenas a aplicação BSP, e o
  acesso ao tile vem da role `PFCG`.
- Se o certificado do sistema for de uma CA interna, instale-a no sistema operacional da máquina de
  desenvolvimento em vez de usar `ignoreCertErrors: true`.
- As BSPs, os pacotes e os tiles são os mesmos do cenário principal (`ZPC_CLIENTES`, `ZPC_ESTOQUE`,
  `ZPC_PEDIDOS`, `ZPC_REEMBOLSOS` e `ZPC_ANL_*`; ver [README, Front-end Fiori](../README.md#front-end-fiori)).

### Passo 9 — Conteúdo do SAP Fiori launchpad

1. Em `/UI2/FLPAM` (*Launchpad App Manager*), crie um catálogo técnico (ex.: `ZPC_TC_PEDIDOS_COMPRAS`) com
   um *app descriptor* por aplicação: tile + *target mapping* com o semantic object e a ação dos manifests.

   | App | Intent | BSP (ID SAPUI5) |
   | --- | --- | --- |
   | Gestão de Clientes | `ZPCCliente-manage` | `ZPC_CLIENTES` |
   | Gestão de Estoque | `ZPCItemEstoque-manage` | `ZPC_ESTOQUE` |
   | Pedidos de Compras | `ZPCPedidoCompra-manage` | `ZPC_PEDIDOS` |
   | Gestão de Reembolsos | `ZPCReembolso-manage` | `ZPC_REEMBOLSOS` |
   | Análise de Pedidos de Compras | `ZPCAnalisePedido-display` | `ZPC_ANL_PEDIDOS` |
   | Análise de Clientes | `ZPCAnaliseCliente-display` | `ZPC_ANL_CLIENTE` |
   | Análise de Itens do Estoque | `ZPCAnaliseItemEstoque-display` | `ZPC_ANL_ESTOQUE` |
   | Análise de Pedidos de Reembolsos | `ZPCAnaliseReembolso-display` | `ZPC_ANL_REEMB` |

2. Em `/UI2/FLPCM_CUST` (*Launchpad Content Manager*), crie os catálogos de negócio (equivalentes a
   `ZPC_BC_*`) referenciando o catálogo técnico, e o espaço/página **Pedidos de Compras** com as seções
   *Gestão* e *Análises*.
3. Inclua catálogos e espaço no menu das roles `Z_PC_ADMIN` (oito tiles) e `Z_PC_COMUM` (Pedidos,
   Reembolsos e as análises que fizerem sentido).
4. Limpe o cache (`/UI2/INVALIDATE_GLOBAL_CACHES`) e teste a navegação entre as apps: os intents são os
   mesmos do launchpad local (`ui5/launchpad`), então Pedido → Cliente/Item e *Abrir gestão* funcionam
   sem alteração.

### Passo 10 — Transporte entre DEV, QAS e PRD

| Objeto | Transporte | Observação |
| --- | --- | --- |
| Fontes ABAP, tabelas, CDS, BDEF, serviços | Workbench | Liberar a ordem após ATC sem erros. |
| BSPs (deploy do front-end) | Workbench | Ordem informada no `ui5-deploy.yaml`. |
| Objetos `SU21`, valores `SU24` | Workbench | — |
| Roles `PFCG` | Workbench ou Customizing | Gerar o perfil e fazer a comparação de usuários no destino. |
| Catálogos/espaços do launchpad | Customizing (`/UI2/FLPCM_CUST`) ou Workbench (`/UI2/FLPAM`) | Conforme o modo de manutenção usado. |
| Publicação dos grupos de serviços | Customizing ou manual em cada sistema | `/IWFND/V4_ADMIN`. |
| `SM59`, `STRUST`, proxy/firewall | **Manual em cada sistema** | Responsabilidade de Basis/infraestrutura. |
| Intervalos de `ZPC_NR` e CodeLists | Manual (`SNRO`) ou setup em DEV/QAS | Ver passo 7. |
| Usuários e atribuição de roles | **Não transportado** | Em cada sistema ou via CUA/IdM. |

### Passo 11 — Testes e aceite

1. ABAP Unit (`Ctrl+Shift+F10`) em `ZCL_PC_UTIL`, `ZCL_PC_PAGAMENTO_SIM`, `ZCL_PC_IMPORTACAO` e
   `ZCL_PC_PLANILHA`: os mesmos testes do BTP devem passar.
2. ATC nos pacotes do projeto, sem erros.
3. `ZPC_TESTE_VIACEP` em cada sistema; depois, cadastro de endereço na app Gestão de Clientes.
4. Cenários da seção 18 com dois usuários: `PC_ADMIN` (`Z_PC_ADMIN`) e `PC_COMUM` (`Z_PC_COMUM`), incluindo as
   negações esperadas (botões desabilitados, `403` sem `S_START`).
5. Navegação entre as oito apps pelo launchpad do sistema.

## 26.5 Diferenças em relação ao cenário principal (SAP BTP, ABAP environment)

| Tema | SAP BTP, ABAP environment (cenário principal) | SAP S/4HANA 2025 FPS01 On-Premise |
| --- | --- | --- |
| Operação da plataforma | SaaS/PaaS gerenciado pela SAP; atualizações trimestrais automáticas | Gerenciado pelo cliente (ou pela SAP na Private Edition); upgrades e FPS/SPS planejados |
| Versão de linguagem dos pacotes | Somente ABAP for Cloud Development | **Standard ABAP** (opcionalmente ABAP for Cloud Development, tier 1) |
| Código RAP (CDS, BDEF, pools, serviços) | `abap/` | **O mesmo**, sem alteração |
| Pacotes e transporte | Software component `ZLOCAL`, sem transporte (gCTS/ABAP CTS nos sistemas não trial) | Pacotes com camada de transporte e ordens Workbench/Customizing (`STMS`, DEV → QAS → PRD) |
| Usuários e login | SAP ID service / Identity Authentication | Usuários `SU01`, SSO por SAML 2.0 ou Kerberos via Web Dispatcher |
| Objetos de autorização | Classe `CPAE`, criados no ADT | Classe própria `ZPC` em `SU21` (mesmos objetos e atividades) |
| Vínculo serviço × autorização | IAM App (`*.sia6`) | `SU24` (valores propostos) |
| Agrupamento e atribuição | Business Catalog + Business Role (*Maintain Business Roles*) | Role `PFCG` (`Z_PC_ADMIN`, `Z_PC_COMUM`) com `S_START` e conteúdo do launchpad |
| Modo trial (`c_modo_trial`) | `abap_true` no trial compartilhado | **Sempre `abap_false`** |
| Publicação OData | *Publish* no ADT (gera serviço de entrada `*_G4BA`) | *Publish* no ADT ou `/IWFND/V4_ADMIN` (grupo de serviços, alias `LOCAL`) |
| Consulta ViaCEP | `ZCL_PC_VIACEP/`: `cl_http_destination_provider=>create_by_url` (URL no código); em produção, *Communication Arrangement* | `ZCL_PC_VIACEP_T2/`: `CL_HTTP_CLIENT` + `SM59` (`Z_VIACEP`) + `STRUST` + proxy |
| Numeração | Objeto `ZPC_NR` no editor do ADT | Objeto `ZPC_NR` na `SNRO` (mesmo buffer em memória) |
| Launchpad | SAP Build Work Zone (tiles URL no trial) ou launchpad do ABAP environment | SAP Fiori launchpad embarcado: `/UI2/FLPAM`, `/UI2/FLPCM_CUST`, espaços e páginas |
| Deploy das apps | `npm run deploy` gera BSP + IAM App `<BSP>_UI5R` | `npm run deploy` gera só a BSP; exige ordem de transporte |
| Dados de demonstração | `ZCL_PC_SETUP` em qualquer momento; `ZCL_PC_RESET` liberado | `ZCL_PC_SETUP` só em DEV/QAS; `ZCL_PC_RESET` bloqueado (modo trial desligado) |
| Monitoramento e suporte | ADT, apps de monitoramento do BTP | ADT + SAP GUI: `ST22`, `SM21`, `SAT`, `/IWFND/ERROR_LOG`, `/IWBEP/ERROR_LOG`, `SMICM` |
| Infraestrutura | Incluída (HANA Cloud, rede, certificados da SAP) | Responsabilidade do cliente: sizing, HANA, backup, alta disponibilidade, Web Dispatcher, certificados, firewall |

## 26.6 Limitações e cuidados no cenário On-Premise

1. **API clássica no ViaCEP.** A versão On-Premise de `ZCL_PC_VIACEP` usa `CL_HTTP_CLIENT`, permitida em
   Standard ABAP. Em cada upgrade, rode o ATC e revise as exceções de `CREATE_BY_DESTINATION`/`SEND`/
   `RECEIVE`, que podem mudar entre releases. Esse código não é *cloud-ready*: se a solução migrar para o BTP
   ou para o S/4HANA Cloud Public Edition, volta-se à versão da pasta `ZCL_PC_VIACEP/`.
2. **`create_by_url` não usado.** No sistema On-Premise em que a migração foi testada,
   `CL_HTTP_DESTINATION_PROVIDER` não estava disponível para o código. A alternativa ABAP Cloud seria um
   *Communication Scenario* com *Communication Arrangement*; ela não foi testada neste projeto.
3. **Dependência da internet.** Como no BTP, ViaCEP indisponível bloqueia o cadastro e a alteração de
   endereço (regra 10.2). No On-Premise há mais pontos de falha (proxy, firewall, certificados no `STRUST`)
   e todos são mantidos pela empresa; a renovação da cadeia de certificados deve entrar no calendário de
   Basis.
4. **Release mínimo.** O código usa recursos recentes do RAP e do ABAP Cloud (`strict ( 2 )`, `Activate`
   com implementação adicional, `hidden: #(Campo)` em facets, action estática com parâmetro `deep` e
   `@Semantics.largeObject`). Esta seção cobre o **S/4HANA 2025 FPS01**; em releases anteriores (2022 ou
   2023) parte da sintaxe pode não ativar e não foi verificada.
5. **Versão do SAPUI5.** As apps exigem SAPUI5 ≥ 1.136 (descriptor v2). Em *hub deployment* com um
   front-end server mais antigo, elas não abrem até o FES ser atualizado.
6. **Leitor de planilhas.** A importação usa a biblioteca XCO (`XCO_CP_XLSX`), que faz parte da ABAP
   Platform; as limitações do cenário principal continuam (XLSX do LibreOffice e textos *inline* não são
   lidos; use `.csv`).
7. **Itens não transportados.** Usuários, atribuição de roles, `SM59`, `STRUST`, regras de rede e,
   normalmente, intervalos de numeração precisam ser mantidos **em cada sistema**. Esquecer um deles é a
   causa mais comum de "funciona em DEV e não em QAS".
8. **Dados de demonstração.** `ZCL_PC_SETUP` grava 300 registros fictícios; não execute em PRD (passo 7).
9. **Operação.** Sizing, backup do SAP HANA, alta disponibilidade, monitoramento e aplicação de notas de
   segurança passam a ser da empresa (ou do contrato da Private Edition), e não da SAP como no BTP.
10. **Acesso externo.** O desenho cobre o acesso pela intranet/VPN. Publicar as apps na internet ou no SAP
    Build Work Zone exige Web Dispatcher na DMZ ou SAP Cloud Connector com *principal propagation*, fora do
    escopo desta especificação.
11. **Ambiente de estudo.** Não há *trial* gratuito do S/4HANA On-Premise como no BTP. Para estudo, há a
    appliance totalmente ativada no SAP Cloud Appliance Library, com custo de infraestrutura no hyperscaler.

## 26.7 Checklist do cenário On-Premise

- [ ] Release confirmado em `CVERS`: S/4HANA 2025 FPS01, ABAP Platform 2025, SAPUI5 1.136.
- [ ] Pacotes criados com a versão de linguagem *Standard ABAP*.
- [ ] `ZPC_MSG`, `ZPC_NR_NUMC10`, `SNRO ZPC_NR` (buffer 10), `SU21 ZPC_ADMIN`/`ZPC_PEDIDO` (com 16).
- [ ] Fontes de `abap/` importados, com `c_modo_trial = abap_false` e `ZCL_PC_VIACEP` de `ZCL_PC_VIACEP_T2/`.
- [ ] Objetos exclusivos do BTP não importados (`*.sia6`, `*_G4BA`, `*.sush`, `ZTA_PC_REEMB_D`).
- [ ] `SM59 Z_VIACEP`, `STRUST`, proxy/firewall configurados; `ZPC_TESTE_VIACEP` com HTTP 200.
- [ ] Cinco grupos de serviços OData V4 publicados.
- [ ] `SU24`, roles `Z_PC_ADMIN`/`Z_PC_COMUM` geradas e atribuídas.
- [ ] Intervalos e CodeLists em cada sistema (setup só em DEV/QAS).
- [ ] Oito BSPs implantadas com ordem de transporte.
- [ ] Catálogos, espaço e página do launchpad nas roles; cache invalidado.
- [ ] ABAP Unit e ATC sem erros; cenários da seção 18 aprovados com os dois perfis.
- [ ] Ordens liberadas e importadas em QAS e PRD; configurações manuais repetidas em cada sistema.
