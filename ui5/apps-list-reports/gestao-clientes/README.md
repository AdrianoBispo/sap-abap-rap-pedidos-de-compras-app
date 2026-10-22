# Gestão de Clientes

Cadastro de clientes com os seus endereços. O CEP preenche o restante do endereço (ViaCEP) e um dos
endereços é marcado como principal, usado depois pelos pedidos.

| | |
| --- | --- |
| Tipo | SAP Fiori Elements V4: List Report + Object Page, com draft |
| `sap.app.id` | `gestaoclientes` |
| Serviço | `ZUI_PC_CLIENTES` (binding OData V4 `ZUI_PC_CLIENTES_O4`) |
| Entity sets | `Cliente` (raiz) e `Endereco` (composição) |
| Tile (inbound) | `ZPCCliente-manage` — "Gestão de Clientes" / "Clientes e endereços" |
| BSP / pacote | `ZPC_CLIENTES` / `ZAVBS_PC_CLIENTES` |
| SAPUI5 mínimo | 1.136.7 |

## Telas

| Página | Rota | Conteúdo |
| --- | --- | --- |
| Lista de clientes | `#/` | Filtros CPF, nome, e-mail, ativo, cidade e UF; colunas CPF, nome, e-mail, telefone, ativo, cidade/UF do endereço principal e data de cadastro; botão **Importar planilha** |
| Cliente | `#/Cliente(...)` | Score no cabeçalho; seções *Dados do cliente*, *Endereços* e *Dados administrativos* |
| Endereço | `#/Cliente(...)/_Endereco(...)` | CEP, logradouro, número, complemento, bairro, cidade, UF e indicador de principal |

| Lista | Endereço pelo ViaCEP | Cliente |
| --- | --- | --- |
| <img src="../../../assets/telas/clientes/lista.png" alt="Lista de clientes" width="290"> | <img src="../../../assets/telas/clientes/endereco-viacep.png" alt="Endereço do CEP 01310-100 preenchido pelo ViaCEP" width="290"> | <img src="../../../assets/telas/clientes/cliente.png" alt="Object Page do cliente com score e endereços" width="290"> |

## Comportamento

As colunas, filtros, seções e ações vêm das metadata extensions do backend (`ZC_PC_CLIENTE_APP`,
`ZC_PC_ENDERECO_APP`); a app não tem extensões de código.

- **Criar e editar** em rascunho (draft): o cliente e os endereços são gravados juntos no *Salvar*.
- **CEP**: o value help `ZC_PC_CEP_VH` sugere CEPs já cadastrados. Ao informar o CEP, a determination
  `PreencherEnderecoViaCep` preenche logradouro, bairro, cidade e UF, e os side effects recarregam esses
  campos na tela. CEP inválido, CEP geral sem logradouro e CEP repetido no mesmo cliente são recusados no
  *Salvar*. Depois de gravado, o CEP fica somente leitura (para trocar, exclua o endereço e crie outro).
- **Definir endereço principal**: ação na tabela de endereços e na página do endereço.
- **Score**: somente leitura, sorteado na criação e exibido como indicador em %: vermelho até 40,
  amarelo de 40 a 70 e verde a partir de 70.
- **Foto** (JPEG, PNG ou WEBP) na página do cliente; sem foto, aparece um avatar.
- **Excluir** é bloqueado para cliente que tem pedido.
- **Importar planilha** (CSV ou XLSX, até 500 linhas, tudo ou nada): uma linha por cliente com o endereço
  principal. Colunas e regras em
  [`abap/README.md`](../../../abap/README.md#94-importação-em-massa-por-planilha); modelo em
  [`docs/modelos-importacao/`](../../../docs/modelos-importacao).

Regras completas do BO: [`abap/README.md`](../../../abap/README.md#91-clientes-estoque-e-pedidos) e
[consulta de CEP](../../../abap/README.md#92-endereço-do-cliente-consulta-de-cep).

## Navegação

- **Entrada**: CPF e nome do cliente nas apps Pedidos de Compras e Gestão de Reembolsos e *Abrir gestão* na
  Análise de Clientes abrem esta app pelo semantic object `ZPCCliente`. Com `ClienteUUID` ou `Cpf` no
  intent, a app abre direto a página do cliente.
- A navegação entre apps precisa de um launchpad (o do sistema ou o [launchpad local](../../launchpad/)).

## Estrutura

```
gestao-clientes/
├── package.json            scripts (start, start-mock, build, lint, int-test, deploy)
├── ui5.yaml                proxy /sap → sistema ABAP; SAPUI5 da CDN
├── ui5-local.yaml          igual, com SAPUI5 local
├── ui5-mock.yaml           mock server com webapp/localService/
├── ui5-deploy.yaml         deploy no ABAP Repository
└── webapp/
    ├── manifest.json       serviço, rotas Lista → Cliente → Endereço, inbound do tile
    ├── Component.js        sap/fe/core/AppComponent
    ├── index.html          página standalone (abre sem launchpad)
    ├── clearLaunchpadIntent.js   descarta o intent que tiles do tipo URL acrescentam ao hash
    ├── annotations/annotation.xml   anotações locais (vazio)
    ├── i18n/i18n.properties textos pt-BR
    ├── localService/mainService/    metadata do serviço e dos value helps, para o mock
    └── test/integration/   testes OPA5 gerados (lista e Object Page)
```

## Executar

```bash
npm install
npm start           # launchpad de preview com dados reais (proxy /sap → sistema ABAP)
npm run start-mock  # sem backend: mock server com dados gerados a partir do metadata
npm run start-local # como o start, com SAPUI5 local
npm run start-noflp # index.html, sem launchpad
```

O `ui5.yaml` aponta para o SAP BTP, ABAP environment (`authenticationType: reentranceTicket`: o navegador
abre o login do BTP na primeira chamada). Para um SAP S/4HANA On-Premise, troque o `backend` como em
[`ui5/README.md`](../../README.md#sistema-on-premise).

## Validar

```bash
npm run lint        # ESLint (@sap-ux/eslint-plugin-fiori-tools)
npm run build       # ui5 build → dist/
npm run int-test    # OPA5 com o mock server
```

## Deploy

```bash
npm run deploy-test   # simula, sem gravar nada
npm run deploy        # build + deploy da BSP ZPC_CLIENTES
npm run undeploy      # remove a BSP
```

| | SAP BTP, ABAP environment | SAP S/4HANA On-Premise |
| --- | --- | --- |
| `ui5-deploy.yaml` | Como está: URL do sistema, `reentranceTicket`, `transport: ""` (pacotes do `ZLOCAL`) | URL e mandante do sistema, `credentials` por variáveis de ambiente e ordem de transporte Workbench |
| O que é criado | BSP `ZPC_CLIENTES` e IAM App `ZPC_CLIENTES_UI5R` | Só a BSP `ZPC_CLIENTES` |
| Acesso | Tile pelo business catalog (ou tile URL no SAP Build Work Zone) | Catálogo `/UI2/FLPAM` e role `PFCG` |
| URL direta | `https://<id>.abap-web.<região>.hana.ondemand.com/sap/bc/ui5_ui5/sap/zpc_clientes/index.html` | `https://<host>:<porta>/sap/bc/ui5_ui5/sap/zpc_clientes/index.html` |

O prefixo `ZAVBS` do pacote `ZAVBS_PC_CLIENTES` é uma escolha pessoal do autor (iniciais do nome) e é opcional: no seu
projeto, troque o `package:` do `ui5-deploy.yaml` pelo pacote que você criou (sugestão genérica:
`ZPK_PC_CLIENTES`; veja [`abap/README.md`](../../../abap/README.md#12-prefixo-dos-pacotes)).
Configuração On-Premise e conteúdo do launchpad: [`ui5/README.md`](../../README.md#sistema-on-premise).
Autorização: objeto `ZPC_ADMIN` (01 criar e importar, 02 alterar e definir endereço principal, 06 excluir),
em [`abap/README.md`](../../../abap/README.md#6-autorização-authority-check-nos-dois-cenários).

---

Gerada com o SAP Fiori Application Generator 1.28.0 (template *List Report Page V4*, OData URL) em
27/09/2026; os dados da geração estão em `.appGenInfo.json`.
