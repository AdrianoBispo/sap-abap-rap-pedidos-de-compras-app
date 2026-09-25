@EndUserText.label : 'Snapshot do cliente no pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snap_cli {

  // A chave é declarada aqui, campo a campo, e NÃO vem do include: uma
  // "key" dentro da estrutura deixaria a chave primária só com CLIENT.
  key client        : abap.clnt not null;
  key snapshot_uuid : zde_pc_snapshot_uuid not null;

  include zs_pc_snap_cli;
  include zs_pc_admin;

}
