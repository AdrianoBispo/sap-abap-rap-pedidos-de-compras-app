@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clientes - consulta analítica'
@Metadata.allowExtensions: true
@OData.applySupportedForAggregation: #FULL

define view entity ZC_PC_CLIENTE_ANALISE
  as select from ZI_PC_CLIENTE_CUBE
{
  key ClienteUUID,
      Nome,
      @ObjectModel.text.element: [ 'GeneroTexto' ]
      Genero,
      GeneroTexto,
      ClienteAtivo,
      Uf,
      FaixaScore,
      MesCadastro,
      @Aggregation.default: #SUM
      QtdeClientes,
      @Aggregation.default: #AVG
      ScoreMedio
}
