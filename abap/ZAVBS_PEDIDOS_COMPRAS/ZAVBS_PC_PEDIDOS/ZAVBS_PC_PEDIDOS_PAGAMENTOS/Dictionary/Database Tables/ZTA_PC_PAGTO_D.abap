@EndUserText.label : 'Draft table for entity ZR_PC_PAGAMENTO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pagto_d {

  key mandt             : mandt not null;
  key pagamentouuid     : sysuuid_x16 not null;
  pedidouuid            : sysuuid_x16;
  metodopagamento       : zpc_de_metodo_pagamento;
  statuspagamento       : zpc_de_status_pagamento;
  bandeiracartao        : zpc_de_bandeira_cartao;
  ultimos4digitoscartao : zpc_de_ultimos4;
  cartaomascarado       : zpc_de_cartao_mascarado;
  codigoautorizacao     : zpc_de_cod_autorizacao;
  mensagempagamento     : zpc_de_mensagem_pagamento;
  datapagamento         : timestampl;
  include zpc_s_admin_d;
  "%admin"              : include sych_bdl_draft_admin_inc;

}