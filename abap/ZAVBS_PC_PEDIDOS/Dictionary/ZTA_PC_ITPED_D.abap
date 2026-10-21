@EndUserText.label : 'Draft table for entity ZR_PC_ITEM_PEDIDO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_itped_d {

  key mandt             : mandt not null;
  key itempedidouuid    : sysuuid_x16 not null;
  pedidouuid            : sysuuid_x16;
  itemuuid              : sysuuid_x16;
  qtdeitempedido        : abap.int4;
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_itped_d.currency'
  precounitariosnapshot : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zta_pc_itped_d.currency'
  valortotal            : abap.curr(15,2);
  observacao            : abap.char(500);
  createdby             : abp_creation_user;
  createdat             : abp_creation_tstmpl;
  lastchangedby         : abp_lastchange_user;
  lastchangedat         : abp_lastchange_tstmpl;
  locallastchangedat    : abp_locinst_lastchange_tstmpl;
  "%admin"              : include sych_bdl_draft_admin_inc;

}