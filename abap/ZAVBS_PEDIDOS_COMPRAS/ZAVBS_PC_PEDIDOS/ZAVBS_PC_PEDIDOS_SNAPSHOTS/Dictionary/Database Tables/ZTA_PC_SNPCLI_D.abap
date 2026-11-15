@EndUserText.label : 'Draft table for entity ZR_PC_PED_CLI_SNAP'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snpcli_d {

  key mandt        : mandt not null;
  key snapshotuuid : sysuuid_x16 not null;
  pedidouuid       : sysuuid_x16;
  clienteuuid      : sysuuid_x16;
  include zpc_s_dados_cliente_d;
  enderecouuid     : sysuuid_x16;
  cep              : zpc_de_cep;
  include zpc_s_endereco;
  enderecocompleto : zpc_de_endereco_completo;
  motivosnapshot   : zpc_de_motivo_snapshot;
  include zpc_s_admin_d;
  "%admin"         : include sych_bdl_draft_admin_inc;

}