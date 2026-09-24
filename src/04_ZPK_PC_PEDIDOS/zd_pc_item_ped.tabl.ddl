@EndUserText.label : 'Draft - Item do pedido'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zd_pc_item_ped {

  key client            : abap.clnt not null;
  key itempedidouuid    : sysuuid_x16 not null;
  pedidouuid            : sysuuid_x16;
  itemuuid              : sysuuid_x16;
  qtdeitempedido        : abap.int4;
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'zd_pc_item_ped.currency'
  precounitariosnapshot : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zd_pc_item_ped.currency'
  valortotal            : abap.curr(15,2);
  observacao            : abap.char(500);
  createdby             : abp_creation_user;
  createdat             : abp_creation_tstmpl;
  lastchangedby         : abp_lastchange_user;
  lastchangedat         : abp_lastchange_tstmpl;
  locallastchangedat    : abp_locinst_lastchange_tstmpl;
  "%admin"              : include sych_bdl_draft_admin_inc;

}
