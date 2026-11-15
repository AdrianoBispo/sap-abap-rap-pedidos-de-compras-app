@EndUserText.label : 'Tabela de Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item {

  key client      : abap.clnt not null;
  key item_uuid   : sysuuid_x16 not null;
  foto_item       : zpc_de_foto;
  foto_mime_type  : zpc_de_mime_type;
  foto_file_name  : zpc_de_nome_arquivo;
  include zpc_s_dados_item;
  qtde_estoque    : zpc_de_qtde_estoque;
  qtde_reservada  : zpc_de_qtde_reservada;
  qtde_disponivel : zpc_de_qtde_disponivel;
  status_estoque  : zpc_de_status_estoque;
  currency        : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_item.currency'
  preco_unitario  : zpc_de_preco_unitario;
  item_ativo      : abap_boolean;
  include zpc_s_admin;

}