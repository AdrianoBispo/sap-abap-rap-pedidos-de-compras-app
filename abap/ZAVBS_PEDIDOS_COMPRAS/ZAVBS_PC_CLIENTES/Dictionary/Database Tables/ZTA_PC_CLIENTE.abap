@EndUserText.label : 'Pedidos de Compras - Clientes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_cliente {

  key client       : abap.clnt not null;
  key cliente_uuid : sysuuid_x16 not null;
  foto_cliente     : zpc_de_foto;
  foto_mime_type   : zpc_de_mime_type;
  foto_file_name   : zpc_de_nome_arquivo;
  include zpc_s_dados_cliente;
  include zpc_s_admin;

}