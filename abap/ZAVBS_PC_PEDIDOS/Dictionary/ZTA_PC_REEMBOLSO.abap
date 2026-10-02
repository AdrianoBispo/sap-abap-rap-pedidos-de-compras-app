@EndUserText.label : 'Solicitacao de reembolso do pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_reembolso {

  key client             : abap.clnt not null;
  key reembolso_uuid     : sysuuid_x16 not null;
  pedido_uuid            : sysuuid_x16;
  numero_pedido          : abap.char(10);
  cliente_uuid           : sysuuid_x16;
  status_reembolso       : abap.char(20);
  status_pedido_anterior : abap.char(40);
  currency               : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_reembolso.currency'
  valor_reembolso        : abap.curr(15,2);
  motivo_solicitacao     : abap.char(500);
  data_solicitacao       : timestampl;
  solicitado_por         : abp_creation_user;
  motivo_decisao         : abap.char(500);
  data_decisao           : timestampl;
  decidido_por           : abp_lastchange_user;
  created_by             : abp_creation_user;
  created_at             : abp_creation_tstmpl;
  last_changed_by        : abp_lastchange_user;
  last_changed_at        : abp_lastchange_tstmpl;
  local_last_changed_at  : abp_locinst_lastchange_tstmpl;

}