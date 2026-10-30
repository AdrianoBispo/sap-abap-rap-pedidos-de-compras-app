@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedidos de Compras - CodeList'
@Metadata.ignorePropagatedAnnotations: true

// View de leitura sobre a tabela ZTA_PC_CODELIST: lista única de códigos de domínio
// (valores e descrições) do app de Pedidos de Compras, separados por Lista.
define view entity ZR_PC_CODELIST
  as select from zta_pc_codelist
{
      // Chave composta: Lista identifica o domínio e Codigo o valor dentro dele.
  key lista       as Lista,
  key codigo      as Codigo,
      descricao   as Descricao,
      // Criticidade associada ao código, para destaque visual na UI.
      criticality as Criticality,
      // Ordem de exibição dos valores dentro da Lista.
      ordem       as Ordem
}
