@EndUserText.label : 'Draft table for entity ZR_PC_PEDIDO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pedido_d {

  key mandt                 : mandt not null;
  key pedidouuid            : sysuuid_x16 not null;
  numeropedido              : zpc_de_numero_pedido;
  clienteuuid               : sysuuid_x16;
  enderecouuid              : sysuuid_x16;
  enderecoprincipalcompleto : zpc_de_endereco_completo;
  statuspedido              : zpc_de_status_pedido;
  statuspagamento           : zpc_de_status_pagamento;
  observacao                : zpc_de_observacao;
  referenciaimportacao      : zpc_de_ref_importacao;
  currency                  : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_pedido_d.currency'
  valortotal                : zpc_de_valor_total;
  datafinalizacao           : timestampl;
  motivocancelamento        : zpc_de_motivo_cancelamento;
  datacancelamento          : timestampl;
  canceladopor              : abp_lastchange_user;
  pedidoencerrado           : xfeld;
  pedidoativosemhistorico   : xfeld;
  pedidonaofinalizado       : xfeld;
  pedidonaocancelado        : xfeld;
  include zpc_s_admin_d;
  "%admin"                  : include sych_bdl_draft_admin_inc;

}