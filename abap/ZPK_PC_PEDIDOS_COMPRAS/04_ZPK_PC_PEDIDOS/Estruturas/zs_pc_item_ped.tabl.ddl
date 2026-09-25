/* Campos de negócio de ZTA_PC_ITEM_PED (sem a chave, declarada na tabela). */
@EndUserText.label : 'Item do pedido - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_item_ped {

  pedido_uuid         : zde_pc_pedido_uuid;
  item_uuid           : zde_pc_item_uuid;
  qtde_item_pedido    : zde_pc_qtde_item_pedido;
  currency            : zde_pc_moeda;
  @Semantics.amount.currencyCode : 'zs_pc_item_ped.currency'
  preco_unitario_snap : zde_pc_preco_unitario;
  @Semantics.amount.currencyCode : 'zs_pc_item_ped.currency'
  valor_total         : zde_pc_valor_total;
  observacao          : zde_pc_observacao;

}
