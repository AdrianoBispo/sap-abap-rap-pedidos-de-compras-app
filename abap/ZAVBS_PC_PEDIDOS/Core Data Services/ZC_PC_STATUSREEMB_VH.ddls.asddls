@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS
@EndUserText.label: 'Status do reembolso - Value Help'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZC_PC_STATUSREEMB_VH
  as select from ZR_PC_CODELIST
{
      @ObjectModel.text.element: ['Descricao']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Status do reembolso'
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
  Lista = 'STATUS_REEMBOLSO'
