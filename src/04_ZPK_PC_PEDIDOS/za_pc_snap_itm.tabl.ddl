@EndUserText.label : 'Snapshot dos itens no pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table za_pc_snap_itm {

  key client             : abap.clnt not null;
  key snapshot_item_uuid : sysuuid_x16 not null;
  pedido_uuid            : sysuuid_x16;
  item_pedido_uuid       : sysuuid_x16;
  item_uuid              : sysuuid_x16;
  sku                    : abap.char(21);
  nome                   : abap.char(120);
  descricao              : abap.char(500);
  categoria              : abap.char(30);
  quantidade             : abap.int4;
  currency               : abap.cuky;
  @Semantics.amount.currencyCode : 'za_pc_snap_itm.currency'
  preco_unitario         : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'za_pc_snap_itm.currency'
  valor_total            : abap.curr(15,2);
  peso                   : abap.dec(15,3);
  altura                 : abap.dec(15,3);
  largura                : abap.dec(15,3);
  profundidade           : abap.dec(15,3);
  created_by             : abp_creation_user;
  created_at             : abp_creation_tstmpl;
  last_changed_by        : abp_lastchange_user;
  last_changed_at        : abp_lastchange_tstmpl;
  local_last_changed_at  : abp_locinst_lastchange_tstmpl;

}
