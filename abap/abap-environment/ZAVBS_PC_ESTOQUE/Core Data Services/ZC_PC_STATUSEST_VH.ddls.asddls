@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status do estoque - Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true

define view entity ZC_PC_STATUSEST_VH
  as select from ZR_PC_CODELIST
{
      @ObjectModel.text.element: ['Descricao']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Status do estoque'
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
  Lista = 'STATUS_ESTOQUE'
