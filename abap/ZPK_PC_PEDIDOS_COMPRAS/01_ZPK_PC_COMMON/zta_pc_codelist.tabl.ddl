@EndUserText.label : 'Pedidos de Compras - Listas de códigos'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_codelist {

  // A chave é declarada aqui, campo a campo, e NÃO vem do include: uma
  // "key" dentro da estrutura deixaria a chave primária só com CLIENT.
  key client : abap.clnt not null;
  key lista  : zde_pc_codelist_lista not null;
  key codigo : zde_pc_codelist_codigo not null;

  include zs_pc_codelist;

}
