@EndUserText.label : 'Pedidos de Compras - Listas de códigos'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_codelist {

  key client  : abap.clnt not null;
  key lista   : abap.char(30) not null;
  key codigo  : abap.char(40) not null;
  descricao   : abap.char(60);
  criticality : abap.int1;
  ordem       : abap.int2;

}
