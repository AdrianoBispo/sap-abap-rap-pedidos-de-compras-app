@EndUserText.label : 'Pedidos de Compras - Listas de códigos'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_codelist {

  key client  : abap.clnt not null;
  key lista   : zpc_de_lista not null;
  key codigo  : zpc_de_codigo not null;
  descricao   : zpc_de_descricao_codigo;
  criticality : zpc_de_criticality;
  ordem       : zpc_de_ordem;

}