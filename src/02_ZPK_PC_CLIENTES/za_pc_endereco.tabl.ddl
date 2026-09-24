@EndUserText.label : 'Endereço do cliente'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_endereco {

  key client            : abap.clnt not null;
  key endereco_uuid     : sysuuid_x16 not null;
  cliente_uuid          : sysuuid_x16;
  cep                   : abap.char(8);
  logradouro            : abap.char(150);
  numero                : abap.char(20);
  complemento           : abap.char(100);
  bairro                : abap.char(100);
  cidade                : abap.char(100);
  uf                    : abap.char(2);
  estado                : abap.char(100);
  cep_geral             : abap_boolean;
  endereco_principal    : abap_boolean;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
