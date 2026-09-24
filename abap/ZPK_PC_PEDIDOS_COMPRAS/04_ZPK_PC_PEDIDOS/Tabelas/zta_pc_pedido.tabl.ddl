@EndUserText.label : 'Pedido de compra'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pedido {

  key client            : abap.clnt not null;
  key pedido_uuid       : sysuuid_x16 not null;
  numero_pedido         : abap.char(10);
  cliente_uuid          : sysuuid_x16;
  endereco_uuid         : sysuuid_x16;
  endereco_completo     : abap.char(500);
  status_pedido         : abap.char(40);
  status_pagamento      : abap.char(30);
  observacao            : abap.char(500);
  currency              : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_pedido.currency'
  valor_total           : abap.curr(15,2);
  data_finalizacao      : timestampl;
  motivo_cancelamento   : abap.char(500);
  data_cancelamento     : timestampl;
  cancelado_por         : abp_lastchange_user;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
