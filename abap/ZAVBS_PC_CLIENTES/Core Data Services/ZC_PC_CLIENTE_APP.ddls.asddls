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
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_GENERO_VH', element: 'Codigo' },
                                           useForValidation: true }]
      Genero,
      _GeneroTxt.Descricao      as GeneroTexto,

      DataNascimento,
      ClienteAtivo,
      ScoreCliente,

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
