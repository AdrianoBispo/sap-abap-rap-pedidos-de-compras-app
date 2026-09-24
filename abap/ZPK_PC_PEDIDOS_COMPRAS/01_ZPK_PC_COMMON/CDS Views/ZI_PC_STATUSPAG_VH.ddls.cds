@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status do pagamento - Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PC_STATUSPAG_VH
  as select from ZI_PC_CODELIST
{
      @ObjectModel.text.element: ['Descricao']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Status do pagamento'
  key Codigo,
      @Semantics.text: true
      @EndUserText.label: 'Descrição'
      Descricao,
      @UI.hidden: true
      Criticality,
      @UI.hidden: true
      Ordem
}
where
  Lista = 'STATUS_PAGAMENTO'
