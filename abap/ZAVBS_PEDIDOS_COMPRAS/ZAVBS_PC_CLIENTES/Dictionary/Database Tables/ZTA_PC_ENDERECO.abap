@EndUserText.label : 'Tabela de Endereço do cliente'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_endereco {

  key client         : abap.clnt not null;
  key endereco_uuid  : sysuuid_x16 not null;
  key cep            : zpc_de_cep not null;
  cliente_uuid       : sysuuid_x16;
  include zpc_s_endereco;
  cep_geral          : abap_boolean;
  cep_status         : zpc_de_cep_status;
  endereco_principal : abap_boolean;
  include zpc_s_admin;

}