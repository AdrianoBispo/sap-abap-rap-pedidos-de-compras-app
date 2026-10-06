@EndUserText.label : 'Draft table for entity ZR_PC_REEMBOLSO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_reemb_d {

  key mandt            : mandt not null;
  key reembolsouuid    : sysuuid_x16 not null;
  pedidouuid           : sysuuid_x16;
  statusreembolso      : abap.char(20);
  statuspedidoanterior : abap.char(40);
  currency             : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_reemb_d.currency'
  valorreembolso       : abap.curr(15,2);
  motivosolicitacao    : abap.char(500);
  datasolicitacao      : timestampl;
  solicitadopor        : abp_creation_user;
  motivodecisao        : abap.char(500);
  datadecisao          : timestampl;
  decididopor          : abp_lastchange_user;
  createdby            : abp_creation_user;
  createdat            : abp_creation_tstmpl;
  lastchangedby        : abp_lastchange_user;
  lastchangedat        : abp_lastchange_tstmpl;
  locallastchangedat   : abp_locinst_lastchange_tstmpl;
  "%admin"             : include sych_bdl_draft_admin_inc;

}