@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedidos de Compras - CodeList (base)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PC_CODELIST
  as select from zta_pc_codelist
{
  key lista       as Lista,
  key codigo      as Codigo,
      descricao   as Descricao,
      criticality as Criticality,
      ordem       as Ordem
}
