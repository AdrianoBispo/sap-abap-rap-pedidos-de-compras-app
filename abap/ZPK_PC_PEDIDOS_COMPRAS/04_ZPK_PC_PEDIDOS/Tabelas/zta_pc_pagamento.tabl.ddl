@EndUserText.label : 'Pagamento (última tentativa)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pagamento {

  // A chave é declarada aqui, campo a campo, e NÃO vem do include: uma
  // "key" dentro da estrutura deixaria a chave primária só com CLIENT.
  key client         : abap.clnt not null;
  key pagamento_uuid : zde_pc_pagamento_uuid not null;

  include zs_pc_pagamento;
  include zs_pc_admin;

}
