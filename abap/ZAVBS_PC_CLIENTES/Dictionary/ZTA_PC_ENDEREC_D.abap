@EndUserText.label : 'Draft table for entity ZR_PC_ENDERECO'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_enderec_d {

  key mandt          : mandt not null;
  key enderecouuid   : sysuuid_x16 not null;
  clienteuuid        : sysuuid_x16;
  cep                : abap.char(8);
  logradouro         : abap.char(150);
  numero             : abap.char(20);
  complemento        : abap.char(100);
  bairro             : abap.char(100);
  cidade             : abap.char(100);
  uf                 : abap.char(2);
  estado             : abap.char(100);
  cepgeral           : abap_boolean;
  cepstatus          : abap.char(1);
  enderecoprincipal  : abap_boolean;
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}