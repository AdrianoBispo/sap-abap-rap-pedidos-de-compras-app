@EndUserText.label : 'Item do pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_item_ped {

  // A chave é declarada aqui, campo a campo, e NÃO vem do include: uma
  // "key" dentro da estrutura deixaria a chave primária só com CLIENT.
  key client           : abap.clnt not null;
  key item_pedido_uuid : zde_pc_item_pedido_uuid not null;

  include zs_pc_item_ped;
  include zs_pc_admin;

}
