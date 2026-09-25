/* Campos de negócio de ZTA_PC_PEDIDO (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Pedido de compra - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_pedido {

  numero_pedido       : zde_pc_numero_pedido;
  cliente_uuid        : zde_pc_cliente_uuid;
  endereco_uuid       : zde_pc_endereco_uuid;
  endereco_completo   : zde_pc_endereco_completo;
  status_pedido       : zde_pc_status_pedido;
  status_pagamento    : zde_pc_status_pagamento;
  observacao          : zde_pc_observacao;
  currency            : zde_pc_moeda;
  @Semantics.amount.currencyCode : 'zs_pc_pedido.currency'
  valor_total         : zde_pc_valor_total;
  data_finalizacao    : timestampl;
  motivo_cancelamento : zde_pc_motivo_cancelamento;
  data_cancelamento   : timestampl;
  cancelado_por       : zde_pc_cancelado_por;

}
