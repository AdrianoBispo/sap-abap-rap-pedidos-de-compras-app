/* Campos de negócio de ZTA_PC_PAGAMENTO (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Pagamento - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_pagamento {

  pedido_uuid        : zde_pc_pedido_uuid;
  metodo_pagamento   : zde_pc_metodo_pagamento;
  status_pagamento   : zde_pc_status_pagamento;
  bandeira_cartao    : zde_pc_bandeira_cartao;
  ultimos4_digitos   : zde_pc_ultimos4_digitos;
  cartao_mascarado   : zde_pc_cartao_mascarado;
  codigo_autorizacao : zde_pc_codigo_autorizacao;
  mensagem_pagamento : zde_pc_mensagem_pagamento;
  data_pagamento     : timestampl;

}
