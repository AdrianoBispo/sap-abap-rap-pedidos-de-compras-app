@EndUserText.label : 'Draft table for entity ZR_PC_ITEM'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item_d {

  key mandt          : mandt not null;
  key itemuuid       : sysuuid_x16 not null;
  fotoitem           : abap.rawstring(0);
  fotomimetype       : abap.char(50);
  fotofilename       : abap.char(255);
  sku                : abap.char(21);
  nome               : abap.char(120);
  descricao          : abap.char(500);
  categoria          : abap.char(30);
  qtdeestoque        : abap.int4;
  qtdereservada      : abap.int4;
  qtdedisponivel     : abap.int4;
  statusestoque      : abap.char(30);
  currency           : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_item_d.currency'
  precounitario      : abap.curr(15,2);
  peso               : abap.dec(15,3);
  altura             : abap.dec(15,3);
  largura            : abap.dec(15,3);
  profundidade       : abap.dec(15,3);
  itemativo          : abap_boolean;
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}