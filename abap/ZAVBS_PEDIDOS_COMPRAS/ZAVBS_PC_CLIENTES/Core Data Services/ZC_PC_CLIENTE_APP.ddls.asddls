@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cliente - Projection (App Gestão de Clientes)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Cpf' ]

/* Projeção root do BO ZR_PC_CLIENTE para o app Gestão de Clientes.
   Expõe os dados do cliente, campos calculados para exibição (CPF e telefone
   formatados, unidade e criticidade do score), cidade e UF do endereço
   principal para lista e filtros, e a composição de endereços
   (ZC_PC_ENDERECO_APP). O comportamento está em ZC_PC_CLIENTE_APP (bdef). */
define root view entity ZC_PC_CLIENTE_APP
  provider contract transactional_query
  as projection on ZR_PC_CLIENTE
{
  key     ClienteUUID,

          /* Campos da foto do cliente */
          FotoCliente,
          FotoMimeType,
          FotoFileName,

          @Search.defaultSearchElement: true
          Cpf,

          @Search.defaultSearchElement: true
          @Search.fuzzinessThreshold: 0.8
          Nome,

          @Search.defaultSearchElement: true
          Email,
          Telefone,

          @ObjectModel.text.element: [ 'GeneroTexto' ]
          Genero,
          DataNascimento,
          ClienteAtivo,

          /* Score 0-100 exibido em % (unidade vem do virtual element ScoreUnidade) */
          @Semantics.quantity.unitOfMeasure: 'ScoreUnidade'
          ScoreCliente,


          /* --- Elementos Virtuais --- */

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
          @EndUserText.label: 'Unidade do score'
  virtual ScoreUnidade      : abap.unit(3),
  
          /* Cor da barra: 1 vermelho (até 40), 2 amarelo (acima de 40 até 70), 3 verde (acima de 70) */
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
          @EndUserText.label: 'Criticidade do score'
  virtual ScoreCriticality  : abap.int1,

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
          @EndUserText.label: 'CPF formatado'
  virtual CpfFormatado      : abap.char(14),

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
          @EndUserText.label: 'Telefone formatado'
  virtual TelefoneFormatado : abap.char(15),

          /* Campos de auditoria e de controle do RAP */
          CreatedBy,
          CreatedAt,
          LastChangedBy,
          LastChangedAt,
          LocalLastChangedAt,


          /* --- Associações --- */

          _GeneroTxt.Descricao      as GeneroTexto,
          _Endereco : redirected to composition child ZC_PC_ENDERECO_APP,
          /* Endereço principal (somente leitura, para lista e filtros) */
          _EnderecoPrincipal.Cidade as CidadePrincipal,
          _EnderecoPrincipal.Uf     as UfPrincipal
}
