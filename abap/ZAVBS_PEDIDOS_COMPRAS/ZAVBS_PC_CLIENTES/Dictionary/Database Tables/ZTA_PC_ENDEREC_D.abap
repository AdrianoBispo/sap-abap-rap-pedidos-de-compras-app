@EndUserText.label : 'Draft table for entity ZR_PC_ENDERECO'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_enderec_d {

  key mandt         : mandt not null;
  key enderecouuid  : sysuuid_x16 not null;
  clienteuuid       : sysuuid_x16;
  cep               : zpc_de_cep;
  include zpc_s_endereco;
  cepgeral          : abap_boolean;
  cepstatus         : zpc_de_cep_status;
  enderecoprincipal : abap_boolean;
  include zpc_s_admin_d;
  "%admin"          : include sych_bdl_draft_admin_inc;

}