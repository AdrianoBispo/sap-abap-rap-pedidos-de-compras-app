@EndUserText.label : 'Pagamento (ultima tentativa)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pagamento {

  key client            : abap.clnt not null;
  key pagamento_uuid    : sysuuid_x16 not null;
  pedido_uuid           : sysuuid_x16;
  metodo_pagamento      : abap.char(20);
  status_pagamento      : abap.char(30);
  bandeira_cartao       : abap.char(30);
  ultimos4_digitos      : abap.char(4);
  cartao_mascarado      : abap.char(30);
  codigo_autorizacao    : abap.char(50);
  mensagem_pagamento    : abap.char(255);
  data_pagamento        : timestampl;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}