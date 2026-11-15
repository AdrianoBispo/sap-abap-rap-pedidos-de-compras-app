@EndUserText.label : 'Pedido de compra'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pedido {

  key client            : abap.clnt not null;
  key pedido_uuid       : sysuuid_x16 not null;
  numero_pedido         : zpc_de_numero_pedido;
  cliente_uuid          : sysuuid_x16;
  endereco_uuid         : sysuuid_x16;
  endereco_completo     : zpc_de_endereco_completo;
  status_pedido         : zpc_de_status_pedido;
  status_pagamento      : zpc_de_status_pagamento;
  observacao            : zpc_de_observacao;
  referencia_importacao : zpc_de_ref_importacao;
  currency              : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_pedido.currency'
  valor_total           : zpc_de_valor_total;
  data_finalizacao      : timestampl;
  motivo_cancelamento   : zpc_de_motivo_cancelamento;
  data_cancelamento     : timestampl;
  cancelado_por         : abp_lastchange_user;
  pedido_encerrado      : xfeld;
  pedido_ativo_sem_hist : xfeld;
  pedido_nao_finalizado : xfeld;
  pedido_nao_cancelado  : xfeld;
  include zpc_s_admin;

}