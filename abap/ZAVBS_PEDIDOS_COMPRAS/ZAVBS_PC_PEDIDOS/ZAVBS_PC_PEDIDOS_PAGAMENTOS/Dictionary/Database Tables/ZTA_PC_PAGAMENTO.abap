@EndUserText.label : 'Pagamento (ultima tentativa)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pagamento {

  key client         : abap.clnt not null;
  key pagamento_uuid : sysuuid_x16 not null;
  pedido_uuid        : sysuuid_x16;
  metodo_pagamento   : zpc_de_metodo_pagamento;
  status_pagamento   : zpc_de_status_pagamento;
  bandeira_cartao    : zpc_de_bandeira_cartao;
  ultimos4_digitos   : zpc_de_ultimos4;
  cartao_mascarado   : zpc_de_cartao_mascarado;
  codigo_autorizacao : zpc_de_cod_autorizacao;
  mensagem_pagamento : zpc_de_mensagem_pagamento;
  data_pagamento     : timestampl;
  include zpc_s_admin;

}