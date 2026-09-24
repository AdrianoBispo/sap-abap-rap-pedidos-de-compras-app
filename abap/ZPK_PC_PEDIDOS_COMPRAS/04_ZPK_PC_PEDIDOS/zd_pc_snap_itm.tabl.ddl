@EndUserText.label : 'Draft - Snapshot dos itens no pedido'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zd_pc_snap_itm {

  key client           : abap.clnt not null;
  key snapshotitemuuid : sysuuid_x16 not null;
  pedidouuid           : sysuuid_x16;
  itempedidouuid       : sysuuid_x16;
  itemuuid             : sysuuid_x16;
  sku                  : abap.char(21);
  nome                 : abap.char(120);
  descricao            : abap.char(500);
  categoria            : abap.char(30);
  quantidade           : abap.int4;
  currency             : abap.cuky;
  @Semantics.amount.currencyCode : 'zd_pc_snap_itm.currency'
  precounitario        : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zd_pc_snap_itm.currency'
  valortotal           : abap.curr(15,2);
  peso                 : abap.dec(15,3);
  altura               : abap.dec(15,3);
  largura              : abap.dec(15,3);
  profundidade         : abap.dec(15,3);
  createdby            : abp_creation_user;
  createdat            : abp_creation_tstmpl;
  lastchangedby        : abp_lastchange_user;
  lastchangedat        : abp_lastchange_tstmpl;
  locallastchangedat   : abp_locinst_lastchange_tstmpl;
  "%admin"             : include sych_bdl_draft_admin_inc;

}
