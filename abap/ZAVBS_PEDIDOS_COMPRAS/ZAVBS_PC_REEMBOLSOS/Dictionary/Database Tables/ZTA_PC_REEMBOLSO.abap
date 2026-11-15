@EndUserText.label : 'Solicitacao de reembolso do pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_reembolso {

  key client             : abap.clnt not null;
  key reembolso_uuid     : sysuuid_x16 not null;
  pedido_uuid            : sysuuid_x16;
  numero_pedido          : zpc_de_numero_pedido;
  cliente_uuid           : sysuuid_x16;
  status_reembolso       : zpc_de_status_reembolso;
  status_pedido_anterior : zpc_de_status_pedido;
  currency               : zpc_de_moeda;
  @Semantics.amount.currencyCode : 'zta_pc_reembolso.currency'
  valor_reembolso        : zpc_de_valor_reembolso;
  motivo_solicitacao     : zpc_de_motivo_solicitacao;
  data_solicitacao       : timestampl;
  solicitado_por         : abp_creation_user;
  motivo_decisao         : zpc_de_motivo_decisao;
  data_decisao           : timestampl;
  decidido_por           : abp_lastchange_user;
  include zpc_s_admin;

}