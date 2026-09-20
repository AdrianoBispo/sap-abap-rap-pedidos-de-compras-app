@EndUserText.label : 'Item de estoque'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table za_pc_item {

  key client            : abap.clnt not null;
  key item_uuid         : sysuuid_x16 not null;
  foto_item             : abap.rawstring(0);
  foto_mime_type        : abap.char(50);
  foto_file_name        : abap.char(255);
  sku                   : abap.char(21);
  nome                  : abap.char(120);
  descricao             : abap.char(500);
  categoria             : abap.char(30);
  qtde_estoque          : abap.int4;
  qtde_reservada        : abap.int4;
  qtde_disponivel       : abap.int4;
  status_estoque        : abap.char(30);
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'za_pc_item.currency'
  preco_unitario        : abap.curr(15,2);
  peso                  : abap.dec(15,3);
  altura                : abap.dec(15,3);
  largura               : abap.dec(15,3);
  profundidade          : abap.dec(15,3);
  item_ativo            : abap_boolean;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
