# Pedidos de Compras – SAP RAP (ABAP Cloud e On-Premise)

<div>
  <img src="https://img.shields.io/badge/BTP-ABAP%20Environment-0FAAFF?style=for-the-badge&logo=sap&logoColor=white" alt="SAP BTP ABAP Environment" >
  <img src="https://img.shields.io/badge/S%2F4HANA-On--Premise-0A6ED1?style=for-the-badge&logo=sap&logoColor=white" alt="SAP S/4HANA On-Premise">
  <img src="https://img.shields.io/badge/ABAP-Cloud%20%7C%20Standard-1872C6?style=for-the-badge&logo=sap&logoColor=white" alt="ABAP Cloud ou Standard ABAP">
  <img src="https://img.shields.io/badge/RAP-Managed%20%2B%20Draft-0070F2?style=for-the-badge&logo=sap&logoColor=white" alt="RAP Managed com Draft">
  <img src="https://img.shields.io/badge/OData-V4-E9540D?style=for-the-badge&logo=sap&logoColor=white" alt="OData V4">
  <img src="https://img.shields.io/badge/Fiori-Elements-354A5F?style=for-the-badge&logo=sap&logoColor=white" alt="SAP Fiori Elements">
  <img src="https://img.shields.io/badge/UI5-%E2%89%A5%201.136-1873B4?style=for-the-badge&logo=sap&logoColor=white" alt="SAPUI5 1.136 ou superior">
  <img src="https://img.shields.io/badge/Node.js-20%2B-5FA04E?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js 20+">
  <img src="https://img.shields.io/badge/API-ViaCEP-2E7D32?style=for-the-badge" alt="API ViaCEP">
  <img src="https://img.shields.io/badge/abaplint-Cloud-4B32C3?style=for-the-badge&logo=sap&logoColor=white" alt="abaplint Cloud">
  <img src="https://img.shields.io/badge/ABAP%20Unit-testes-9C3493?style=for-the-badge&logo=sap&logoColor=white" alt="ABAP Unit">
</div>

<div>
  <img src="assets/telas/launchpad/inicio.png" alt="Launchpad local com os oito tiles: quatro de gestão e quatro de análise" width="100%">
</div>

---

## Índice

- [Pedidos de Compras – SAP RAP (ABAP Cloud e On-Premise)](#pedidos-de-compras--sap-rap-abap-cloud-e-on-premise)
  - [Índice](#índice)
  - [Sobre o projeto](#sobre-o-projeto)
  - [Demonstração](#demonstração)
    - [Pedidos de Compras: do rascunho à finalização](#pedidos-de-compras-do-rascunho-à-finalização)
  - [Funcionalidades](#funcionalidades)
  - [Tecnologias](#tecnologias)
  - [Arquitetura](#arquitetura)
  - [Estrutura do repositório](#estrutura-do-repositório)
  - [Como começar](#como-começar)
  - [Diagramas](#diagramas)
    - [Fluxogramas das operações dos BOs](#fluxogramas-das-operações-dos-bos)
  - [Documentação](#documentação)
  - [Histórico de versões](#histórico-de-versões)
  - [Autor](#autor)

---

## Sobre o projeto

Projeto de estudo **SAP ABAP RAP (RESTful Application Programming Model)** e **SAP Fiori** que contempla o fluxo de gestão de clientes, estoque, pedidos de compras e reembolsos e que conta também com os apps para análise dos dados dessas mesmas aplicações Fiori. O backend RAP fica em [`abap/`](abap/) e o front-end em [`ui5/`](ui5/).

Os mesmos códigos e objetos ABAP e RAP podem ser utilizados nos **SAP BTP, ABAP environment** (ABAP Cloud) e
no ambiente **SAP S/4HANA On-Premise** (pacotes Standard ABAP). Nos dois ambientes a solução usa CDS View Entities, Behavior Definitions, Behavior Implementations, Service Definitions e Service Bindings OData V4; só a
configuração da plataforma (segurança, conectividade, launchpad e transporte) muda de um para o outro.

| Cenário    | Ambiente                                                | Pacotes                      | Segurança                                    | Launchpad                     |
| ---------- | ------------------------------------------------------- | ---------------------------- | -------------------------------------------- | ----------------------------- |
| ABAP Cloud | SAP BTP, ABAP environment (Trial ou pago)               | *ABAP for Cloud Development* | IAM Apps, Business Catalogs e Business Roles | SAP Build Work Zone           |
| On-Premise | SAP S/4HANA (referência: 2025 FPS01) ou Private Edition | *Standard ABAP*              | `SU21`, `SU24`, `PFCG`                       | SAP Fiori launchpad embarcado |

| App                              | O que gerencia                                                                                     |
| -------------------------------- | -------------------------------------------------------------------------------------------------- |
| Gestão de Clientes               | Clientes e seus endereços, com preenchimento e cadastro automático via ViaCEP                      |
| Gestão de Estoque                | Itens (SKU, foto, categoria, descrição) e quantidade disponível                                    |
| Pedidos de Compras               | Pedidos, itens, pagamento simulado, cancelamento e histórico (snapshots)                           |
| Gestão de Reembolsos             | Aprovação e rejeição das solicitações de reembolso de pedidos cancelados com pagamento aprovado    |
| Análise de Pedidos de Compras    | Valores, quantidades, ticket médio, status e pagamentos dos pedidos (somente leitura)              |
| Análise de Clientes              | Clientes por gênero, UF, faixa de score e mês de cadastro (somente leitura)                        |
| Análise de Itens do Estoque      | Itens, quantidades reservada e disponível e valor em estoque por categoria (somente leitura)       |
| Análise de Pedidos de Reembolsos | Valores e quantidades das solicitações de reembolso por status, mês, UF e motivo (somente leitura) |

> [!NOTE]
> Os fontes foram escritos em ABAP Cloud (`strict ( 2 )`, `with draft`) e verificados com *abaplint*
> (linguagem **Cloud**). Por isso ativam no SAP BTP, ABAP environment e também, sem erros, em pacotes
> *Standard ABAP* do On-Premise. Só dois objetos mudam entre os ambientes; as diferenças estão no
> [`abap/README.md`](abap/README.md#2-o-que-muda-entre-os-cenários).

---

## Demonstração

Telas capturadas no launchpad local (`ui5/launchpad`) com os dados de demonstração do SAP BTP, ABAP
environment, executando os fluxos completos das apps.

<details>
<summary><b>Gestão de Clientes: cadastro com consulta ao ViaCEP</b></summary>
<br>

| Lista de clientes | Endereço preenchido pelo ViaCEP | Cliente cadastrado |
| :---------------: | :-----------------------------: | :----------------: |
|                   |                                 |                    |

</details>

<details>
<summary><b>Gestão de Estoque</b></summary>
<br>

| Lista de itens | Item cadastrado (SKU gerado no Save) |
| :------------: | :----------------------------------: |
|                |                                      |

</details>

### Pedidos de Compras: do rascunho à finalização

| Lista de pedidos | Rascunho com itens inline | Efetuar Pagamento |
| :--------------: | :-----------------------: | :---------------: |
|                  |                           |                   |

| Pedido finalizado (snapshot do cliente) | Itens, pagamento e finalização |
| :-------------------------------------: | :----------------------------: |
|                                         |                                |

<details>
<summary><b>Cancelamento com pagamento aprovado e Gestão de Reembolsos</b></summary>
<br>

| Cancelar pedido (motivo) | Pedido em processamento de reembolso | Lista de reembolsos |
| :----------------------: | :----------------------------------: | :-----------------: |
|                          |                                      |                     |

| Solicitação pendente | Aprovar reembolso (motivo da decisão) | Reembolso aprovado |
| :------------------: | :-----------------------------------: | :----------------: |
|                      |                                       |                    |

<p >
  <img src="assets/telas/pedidos/cancelado.png" alt="Pedido cancelado pelo reembolso aprovado, com pagamento devolvido e o snapshot do cliente" width="700"><br>
  <sub>Pedido aberto pelo link do reembolso (navegação entre apps): cancelado, pagamento devolvido e snapshot do cliente.</sub>
</p>

</details>

<details>
<summary><b>Análises</b></summary>
<br>

| Análise de Pedidos de Compras | Análise de Clientes |
| :---------------------------: | :-----------------: |
|                               |                     |

| Análise de Itens do Estoque | Análise de Pedidos de Reembolsos |
| :-------------------------: | :------------------------------: |
|                             |                                  |

</details>

---

## Funcionalidades

- **Clientes**: cadastro com draft, vários endereços por cliente (um principal), score exibido como barra
  de progresso e bloqueio da exclusão de cliente com pedido.
- **Endereço com ViaCEP**: o CEP preenche logradouro, bairro, cidade e UF; CEPs já consultados são
  reaproveitados e o CEP é único por cliente.
- **Estoque**: itens com SKU gerado automaticamente a partir da categoria, foto e controle de quantidade
  em estoque, reservada e disponível.
- **Pedidos**: criados em rascunho com itens *inline*; ao salvar, o pedido é registrado e o estoque
  reservado. Depois vêm **Efetuar Pagamento** (cartão simulado, sem gravar dados sensíveis),
  **Aprovar pedido** (baixa o estoque) e **Cancelar** (libera a reserva).
- **Histórico imutável**: snapshots do cliente e dos itens no encerramento do pedido.
- **Reembolsos**: cancelar um pedido já pago abre uma solicitação, decidida na app Gestão de Reembolsos.
- **Importação em massa** de clientes, itens e pedidos por planilha (`.xlsx` ou `.csv`).
- **Análises**: quatro apps freestyle com filtros, indicadores e 5 gráficos cada.
- **Autorização** por perfil (administrador e usuário comum) e **navegação entre apps** pelo launchpad.

O funcionamento de cada regra no backend está no [`abap/README.md`](abap/README.md); as telas e a navegação,
no [`ui5/README.md`](ui5/README.md).

---

## Tecnologias

| Camada      | Tecnologia                                                                                                      |
| ----------- | --------------------------------------------------------------------------------------------------------------- |
| Plataforma  | SAP BTP, ABAP environment **ou** SAP S/4HANA On-Premise (ABAP Platform 2025)                                    |
| Backend     | RAP Managed com Draft (`strict ( 2 )`), CDS View Entities, EML — ABAP Cloud no BTP, Standard ABAP no On-Premise |
| Serviços    | Cinco serviços OData V4 (um por app de gestão e um analítico)                                                   |
| Integração  | API pública ViaCEP                                                                                              |
| Front-end   | SAP Fiori Elements V4 (List Report + Object Page) e SAPUI5 freestyle (`sap.viz`) nas análises                   |
| Ferramentas | ADT (Eclipse ou VS Code), SAP GUI (On-Premise), SAP Fiori tools, UI5 CLI, UI5 linter, abaplint                  |
| Testes      | ABAP Unit, OPA5 e QUnit                                                                                         |

---

## Arquitetura

O mesmo backend RAP tem duas arquiteturas de implantação. No **SAP BTP, ABAP environment**:

<p >
  <a href="assets/arquitetura.png"><img src="assets/arquitetura.png" alt="Arquitetura: usuários e Work Zone, launchpad local e ferramentas de desenvolvimento acessando o SAP BTP, ABAP environment, com as 8 apps (BSP), os 5 serviços OData V4, os BOs RAP, a camada analítica, ZAVBS_PC_COMMON, SAP HANA e a API ViaCEP" width="100%"></a>
</p>

No **SAP S/4HANA On-Premise**, com SAP Fiori launchpad e SAP Gateway embarcados e a consulta ao ViaCEP
por uma destination `SM59`:

<p >
  <a href="assets/arquitetura-onpremise.png"><img src="assets/arquitetura-onpremise.png" alt="Arquitetura On-Premise: usuários via SAP Web Dispatcher, SAP Fiori launchpad e SAP Gateway embarcados no SAP S/4HANA 2025 FPS01, BOs RAP em pacotes Standard ABAP, ZCL_PC_VIACEP com SM59 e STRUST, proxy, firewall e API ViaCEP" width="100%"></a>
</p>

- Cada app chama o próprio serviço OData V4, que expõe um BO RAP; as quatro análises usam o mesmo
  serviço analítico.
- O BO Pedido reserva estoque no BO Item, grava os snapshots e abre a solicitação no BO Reembolso, tudo por
  EML na mesma transação; o BO Cliente consulta a API ViaCEP.

Ciclo de vida do pedido:

```mermaid
stateDiagram-v2
    direction LR
    [*] --> ABERTO: Criar + Salvar (reserva o estoque)
    ABERTO --> ABERTO: Editar itens / Pagamento recusado
    ABERTO --> AGUARDANDO_APROVACAO: Pagamento aprovado
    AGUARDANDO_APROVACAO --> FINALIZADO: Aprovar pedido
    ABERTO --> CANCELADO: Cancelar
    AGUARDANDO_APROVACAO --> PROCESSANDO_REEMBOLSO: Cancelar (pagamento aprovado)
    PROCESSANDO_REEMBOLSO --> CANCELADO: Aprovar reembolso
    PROCESSANDO_REEMBOLSO --> AGUARDANDO_APROVACAO: Rejeitar reembolso
    FINALIZADO --> [*]
    CANCELADO --> [*]
```

---

## Estrutura do repositório

```text
.
├── abap/            backend RAP, o mesmo para ABAP Cloud e On-Premise (pacote ZAVBS_PEDIDOS_COMPRAS com um ZAVBS_PC_* por domínio)
├── ui5/
│   ├── apps-list-reports/   quatro apps Fiori Elements (List Report + Object Page), uma por domínio
│   ├── apps-analiticos/     quatro apps freestyle de análise, uma por domínio
│   └── launchpad/           launchpad local que reúne as oito apps
├── assets/          imagens dos diagramas, dos fluxogramas dos BOs (assets/fluxos-bo/) e capturas de tela (assets/telas/)
└── docs/
    ├── Pedidos_de_Compras_-_Especificacao_Tecnica.md     especificação técnica (Markdown)
    ├── Pedidos_de_Compras_-_Especificacao_Tecnica.docx   especificação técnica (Word)
    ├── pedidos-de-compras.drawio                         diagramas (uma página por diagrama)
    ├── fluxos-bo/                                        fluxogramas das operações de cada BO (um .drawio por BO)
    ├── apresentacoes/                                    slides das cinco etapas
    └── modelos-importacao/                               planilhas modelo (CSV/XLSX)
```

> [!TIP]
> **Prefixo dos pacotes.** `ZAVBS` (em `ZAVBS_PEDIDOS_COMPRAS` e `ZAVBS_PC_*`) é uma escolha pessoal do autor,
> com as iniciais do seu nome completo, e é opcional. No seu projeto, use os prefixos que preferir; como
> sugestão genérica, `ZPK` (`ZPK_PEDIDOS_COMPRAS`, `ZPK_PC_COMMON`, `ZPK_PC_PEDIDOS`…). O código não depende do
> nome dos pacotes; detalhes em [`abap/README.md`](abap/README.md#12-prefixo-dos-pacotes).

---

## Como começar

**Pré-requisitos:** um SAP BTP, ABAP environment (Trial serve) ou um SAP S/4HANA On-Premise com RAP;
ADT no Eclipse ou no VS Code (extensão *ABAP Development Tools*); Node.js 20+; VS Code com SAP Fiori tools ou
SAP Business Application Studio.

1. **Backend** — siga o [`abap/README.md`](abap/README.md): objetos criados à mão, ordem de ativação,
   roteiro de cada ambiente (BTP ou On-Premise), ViaCEP e autorização.
2. **Front-end** — siga o [`ui5/README.md`](ui5/README.md): execução local, deploy das apps e conteúdo do
   launchpad.
3. **Teste completo** — rode o launchpad local, que reúne as oito apps com a navegação entre elas:

   ```bash
   cd ui5/launchpad
   npm install
   npm start          # dados do sistema ABAP configurado no ui5.yaml
   npm run start-mock # sem backend
   ```

---

## Diagramas

Desenhados no **draw.io** com as formas oficiais da SAP, num único arquivo
([`docs/pedidos-de-compras.drawio`](docs/pedidos-de-compras.drawio)) com uma página por diagrama, exportada
para [`assets/`](assets).

| Página | Diagrama                                        | Imagem                                                          |
| ------ | ----------------------------------------------- | --------------------------------------------------------------- |
| 1      | Arquitetura (SAP BTP, ABAP environment)         | [`arquitetura.png`](assets/arquitetura.png)                     |
| 2      | Fluxo do pedido de compra                       | [`fluxo-pedido.png`](assets/fluxo-pedido.png)                   |
| 3      | Fluxo de reembolso                              | [`fluxo-reembolso.png`](assets/fluxo-reembolso.png)             |
| 4      | Endereço e consulta de CEP (ViaCEP)             | [`fluxo-endereco-viacep.png`](assets/fluxo-endereco-viacep.png) |
| 5      | Importação em massa por planilha                | [`fluxo-importacao.png`](assets/fluxo-importacao.png)           |
| 6      | Apps de análise                                 | [`fluxo-analises.png`](assets/fluxo-analises.png)               |
| 7      | Arquitetura On-Premise (SAP S/4HANA 2025 FPS01) | [`arquitetura-onpremise.png`](assets/arquitetura-onpremise.png) |

Para regerar as imagens: *Arquivo → Exportar como → PNG* no draw.io (escala 2, borda 20), uma página por vez.

### Fluxogramas das operações dos BOs

As operações de cada business object estão em um arquivo próprio em [`docs/fluxos-bo/`](docs/fluxos-bo), com
uma página por fluxo desenhada na horizontal: autorização, feature control, determinations, validations,
chamadas EML entre BOs e os caminhos de erro. Cada página tem a sua imagem em [`assets/fluxos-bo/`](assets/fluxos-bo).

| Arquivo                                                                         | BO                                   | Páginas                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`fluxos-bo-cliente.drawio`](docs/fluxos-bo/fluxos-bo-cliente.drawio)           | Cliente e Endereço (`ZR_PC_CLIENTE`) | [criar cliente](assets/fluxos-bo/cliente-1-criar-cliente.png) · [editar cliente](assets/fluxos-bo/cliente-2-editar-cliente.png) · [excluir cliente](assets/fluxos-bo/cliente-3-excluir-cliente.png) · [endereço e cep](assets/fluxos-bo/cliente-4-endereco-e-cep.png) · [endereço principal](assets/fluxos-bo/cliente-5-endereco-principal.png) · [importar planilha](assets/fluxos-bo/cliente-6-importar-planilha.png)                                                                                                            |
| [`fluxos-bo-item-estoque.drawio`](docs/fluxos-bo/fluxos-bo-item-estoque.drawio) | Item de Estoque (`ZR_PC_ITEM`)       | [criar item](assets/fluxos-bo/item-estoque-1-criar-item.png) · [editar e inativar item](assets/fluxos-bo/item-estoque-2-editar-e-inativar-item.png) · [excluir item](assets/fluxos-bo/item-estoque-3-excluir-item.png) · [movimentar estoque](assets/fluxos-bo/item-estoque-4-movimentar-estoque.png) · [importar planilha](assets/fluxos-bo/item-estoque-5-importar-planilha.png)                                                                                                                                                 |
| [`fluxos-bo-pedido.drawio`](docs/fluxos-bo/fluxos-bo-pedido.drawio)             | Pedido (`ZR_PC_PEDIDO`)              | [criar e registrar pedido](assets/fluxos-bo/pedido-1-criar-e-registrar-pedido.png) · [editar itens do pedido](assets/fluxos-bo/pedido-2-editar-itens-do-pedido.png) · [simular pagamento](assets/fluxos-bo/pedido-3-simular-pagamento.png) · [aprovar pedido](assets/fluxos-bo/pedido-4-aprovar-pedido.png) · [cancelar pedido](assets/fluxos-bo/pedido-5-cancelar-pedido.png) · [decisão do reembolso](assets/fluxos-bo/pedido-6-decisao-do-reembolso.png) · [importar planilha](assets/fluxos-bo/pedido-7-importar-planilha.png) |
| [`fluxos-bo-reembolso.drawio`](docs/fluxos-bo/fluxos-bo-reembolso.drawio)       | Reembolso (`ZR_PC_REEMBOLSO`)        | [abrir solicitação](assets/fluxos-bo/reembolso-1-abrir-solicitacao.png) · [aprovar reembolso](assets/fluxos-bo/reembolso-2-aprovar-reembolso.png) · [rejeitar reembolso](assets/fluxos-bo/reembolso-3-rejeitar-reembolso.png)                                                                                                                                                                                                                                                                                                      |

---

## Documentação

- [Backend RAP](abap/README.md) — instalação, diferenças entre os ambientes, regras implementadas, ViaCEP,
  autorização, controle de leitura (DCL), testes e limitações.
- [Front-end Fiori](ui5/README.md) — apps, páginas, navegação, análises, launchpad local, deploy e
  launchpad do sistema.
- [Especificação técnica](docs/Pedidos_de_Compras_-_Especificacao_Tecnica.md) — requisitos técnicos do
  projeto nos dois ambientes (também em [Word](docs/Pedidos_de_Compras_-_Especificacao_Tecnica.docx)).
- [Apresentações](docs/apresentacoes/) — cinco decks, um por etapa (modelagem de dados, CDS, comportamento
  RAP, serviços OData e apps Fiori), para o SAP BTP, ABAP environment ou o On-Premise.
- Projeto relacionado: [sap-abap-enderecos-viacep](https://github.com/AdrianoBispo/sap-abap-enderecos-viacep).

---

## Histórico de versões

| Versão | Mudanças                                                                                                                                                                                                                                                                           |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| v2.14  | Fluxogramas das operações de cada BO no draw.io (`docs/fluxos-bo/`), uma página por fluxo na horizontal, no padrão visual SAP, com as imagens em `assets/fluxos-bo/`                                                                                                               |
| v2.13  | Classes de teste ABAP Unit em todas as classes e behavior pools (204 testes em 13 classes, com test doubles nos BOs); mapa de cobertura no [`abap/README.md`](abap/README.md#111-abap-unit) e Especificação Técnica v3.3                                                           |
| v2.12  | Launchpad no início do README, logo após os badges, como no projeto CAP; telas da Demonstração recolhidas em seções expansíveis, com o fluxo de Pedidos de Compras sempre visível                                                                                                  |
| v2.11  | README próprio para cada app Fiori e para o launchpad local; prefixo `ZAVBS` dos pacotes documentado como opcional (escolha pessoal do autor), com a sugestão genérica `ZPK` na documentação, na Especificação Técnica v3.1 e nas apresentações                                    |
| v2.10  | README principal só com a visão geral; detalhes do backend em [`abap/README.md`](abap/README.md) e do front-end em [`ui5/README.md`](ui5/README.md); Especificação Técnica v3.0 escrita como requisitos técnicos para os dois ambientes, com diagramas e telas, em Markdown e Word |
| v2.9   | Projeto orientado aos dois ambientes (SAP BTP, ABAP environment e SAP S/4HANA On-Premise): `abap/` sem diretório por cenário, tutoriais de ViaCEP, autorização e DCL no `abap/README.md`, pacotes *Standard ABAP* no On-Premise e apresentações para os dois ambientes             |
| v2.8   | Diagramas num único arquivo draw.io, com a arquitetura On-Premise; Especificação Técnica em Markdown                                                                                                                                                                               |
| v2.7   | Atividade 16 (Executar) em `ZPC_PEDIDO`; tutoriais de autorização On-Premise e de controle de leitura (DCL)                                                                                                                                                                        |
| v2.6   | Diagramas no draw.io com as formas oficiais da SAP (arquitetura e fluxogramas)                                                                                                                                                                                                     |
| v2.5   | Análises divididas em quatro apps freestyle, um por domínio; launchpad local com oito tiles                                                                                                                                                                                        |
| v2.4   | Importação de pedidos sem duplicidade (referência de importação); link direto do reembolso para o pedido                                                                                                                                                                           |
| v2.3   | Navegação entre apps ampliada (CPF e item como links; links no reembolso)                                                                                                                                                                                                          |
| v2.2   | Novo modelo de status do pedido, edição dos itens do pedido aberto, Object Page dinâmica, camada analítica e suíte permanente de testes                                                                                                                                            |
| v2.1   | Reembolso como BO e app próprios; registro do pedido no Save com reserva de estoque; SKU gerado no Save                                                                                                                                                                            |
| v1.5   | Score com Process Indicator, precheck de estoque zerado, cadastro automático de endereço, CEP único por cliente                                                                                                                                                                    |
| v1.4   | Dicionário de dados próprio e novos nomes das tabelas draft                                                                                                                                                                                                                        |
| v1.3   | Consulta de CEP do endereço movida para custom entity                                                                                                                                                                                                                              |
| v1.2   | Front-end Fiori Elements e ajustes de backend para navegação entre apps                                                                                                                                                                                                            |
| v1.1   | Correções do code review                                                                                                                                                                                                                                                           |

O detalhe das correções do backend (v1.1, v1.2 e v1.5) está no
[`abap/README.md`](abap/README.md#13-histórico-de-correções-do-backend).

---

## Autor

Desenvolvido por **Adriano Bispo**.

[![GitHub](https://img.shields.io/badge/GitHub-AdrianoBispo-181717?style=for-the-badge&logo=github)](https://github.com/AdrianoBispo)
