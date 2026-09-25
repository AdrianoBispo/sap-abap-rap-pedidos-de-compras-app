@EndUserText.label : 'Endereço do cliente'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_endereco {

  // A chave é declarada aqui, campo a campo, e NÃO vem do include: uma
  // "key" dentro da estrutura deixaria a chave primária só com CLIENT.
  key client        : abap.clnt not null;
  key endereco_uuid : zde_pc_endereco_uuid not null;

  include zs_pc_endereco;
  include zs_pc_admin;

}
