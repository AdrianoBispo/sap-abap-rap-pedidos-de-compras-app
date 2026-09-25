/* Campos de negócio de ZTA_PC_SNAP_ITM (sem a chave, declarada na tabela). */
@EndUserText.label : 'Snapshot do item - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_snap_itm {

  pedido_uuid      : zde_pc_pedido_uuid;
  item_pedido_uuid : zde_pc_item_pedido_uuid;
  item_uuid        : zde_pc_item_uuid;
  sku              : zde_pc_sku;
  nome             : zde_pc_nome_item;
  descricao        : zde_pc_descricao_item;
  categoria        : zde_pc_categoria;
  quantidade       : zde_pc_qtde_item_pedido;
  currency         : zde_pc_moeda;
  @Semantics.amount.currencyCode : 'zs_pc_snap_itm.currency'
  preco_unitario   : zde_pc_preco_unitario;
  @Semantics.amount.currencyCode : 'zs_pc_snap_itm.currency'
  valor_total      : zde_pc_valor_total;
  peso             : zde_pc_peso;
  altura           : zde_pc_altura;
  largura          : zde_pc_largura;
  profundidade     : zde_pc_profundidade;

}
