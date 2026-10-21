@EndUserText.label : 'Draft table for entity ZR_PC_PAGAMENTO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pagto_d {

  key mandt             : mandt not null;
  key pagamentouuid     : sysuuid_x16 not null;
  pedidouuid            : sysuuid_x16;
  metodopagamento       : abap.char(20);
  statuspagamento       : abap.char(30);
  bandeiracartao        : abap.char(30);
  ultimos4digitoscartao : abap.char(4);
  cartaomascarado       : abap.char(30);
  codigoautorizacao     : abap.char(50);
  mensagempagamento     : abap.char(255);
  datapagamento         : timestampl;
  createdby             : abp_creation_user;
  createdat             : abp_creation_tstmpl;
  lastchangedby         : abp_lastchange_user;
  lastchangedat         : abp_lastchange_tstmpl;
  locallastchangedat    : abp_locinst_lastchange_tstmpl;
  "%admin"              : include sych_bdl_draft_admin_inc;

}