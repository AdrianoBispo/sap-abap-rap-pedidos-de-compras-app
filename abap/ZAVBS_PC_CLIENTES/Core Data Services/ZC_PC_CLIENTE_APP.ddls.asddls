@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cliente - Projection (App Gestão de Clientes)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Cpf' ]

define root view entity ZC_PC_CLIENTE_APP
  provider contract transactional_query
  as projection on ZR_PC_CLIENTE
{
  key ClienteUUID,

      FotoCliente,
      FotoMimeType,
      FotoFileName,

      @Search.defaultSearchElement: true
      Cpf,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
      @EndUserText.label: 'CPF formatado'
      virtual CpfFormatado      : abap.char(14),

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Nome,

      @Search.defaultSearchElement: true
      Email,

      Telefone,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
      @EndUserText.label: 'Telefone formatado'
      virtual TelefoneFormatado : abap.char(15),

      @ObjectModel.text.element: [ 'GeneroTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_GENERO_VH', element: 'Codigo' },
                                           useForValidation: true }]
      Genero,
      _GeneroTxt.Descricao      as GeneroTexto,

      DataNascimento,
      ClienteAtivo,

      /* Score 0-100 exibido em % (unidade vem do virtual element ScoreUnidade) */
      @Semantics.quantity.unitOfMeasure: 'ScoreUnidade'
      ScoreCliente,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
      @EndUserText.label: 'Unidade do score'
      virtual ScoreUnidade      : abap.unit(3),
      /* Cor da barra: 1 vermelho (até 40), 2 amarelo (acima de 40 até 70), 3 verde (acima de 70) */
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PC_VE_CLIENTE'
      @EndUserText.label: 'Criticidade do score'
      virtual ScoreCriticality  : abap.int1,

      /* Endereço principal (somente leitura, para lista e filtros) */
      _EnderecoPrincipal.Cidade as CidadePrincipal,
      _EnderecoPrincipal.Uf     as UfPrincipal,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Endereco : redirected to composition child ZC_PC_ENDERECO_APP
}
