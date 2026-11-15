@EndUserText.label : 'Draft table for entity ZR_PC_ITEM'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item_d {

  key mandt      : mandt not null;
  key itemuuid   : sysuuid_x16 not null;
  fotoitem       : zpc_de_foto;
  fotomimetype   : zpc_de_mime_type;
  fotofilename   : zpc_de_nome_arquivo;
  include zpc_s_dados_item;
  qtdeestoque    : zpc_de_qtde_estoque;
  qtdereservada  : zpc_de_qtde_reservada;
  qtdedisponivel : zpc_de_qtde_disponivel;
  statusestoque  : zpc_de_status_estoque;
  currency       : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_item_d.currency'
  precounitario  : zpc_de_preco_unitario;
  itemativo      : abap_boolean;
  include zpc_s_admin_d;
  "%admin"       : include sych_bdl_draft_admin_inc;

}