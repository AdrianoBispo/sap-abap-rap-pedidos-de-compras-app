@EndUserText.label : 'Snapshot do cliente no pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snap_cli {

  key client        : abap.clnt not null;
  key snapshot_uuid : sysuuid_x16 not null;
  pedido_uuid       : sysuuid_x16;
  cliente_uuid      : sysuuid_x16;
  include zpc_s_dados_cliente;
  endereco_uuid     : sysuuid_x16;
  cep               : zpc_de_cep;
  include zpc_s_endereco;
  endereco_completo : zpc_de_endereco_completo;
  motivo_snapshot   : zpc_de_motivo_snapshot;
  include zpc_s_admin;

}