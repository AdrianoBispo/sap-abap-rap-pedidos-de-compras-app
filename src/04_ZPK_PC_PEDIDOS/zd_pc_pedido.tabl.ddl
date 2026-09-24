@EndUserText.label : 'Draft - Pedido de compra'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_pedido_d {

  key client                : abap.clnt not null;
  key pedidouuid            : sysuuid_x16 not null;
  numeropedido              : abap.char(10);
  clienteuuid               : sysuuid_x16;
  enderecouuid              : sysuuid_x16;
  enderecoprincipalcompleto : abap.char(500);
  statuspedido              : abap.char(40);
  statuspagamento           : abap.char(30);
  observacao                : abap.char(500);
  currency                  : abap.cuky;
  @Semantics.amount.currencyCode : 'zta_pc_pedido_d.currency'
  valortotal                : abap.curr(15,2);
  datafinalizacao           : timestampl;
  motivocancelamento        : abap.char(500);
  datacancelamento          : timestampl;
  canceladopor              : abp_lastchange_user;
  createdby                 : abp_creation_user;
  createdat                 : abp_creation_tstmpl;
  lastchangedby             : abp_lastchange_user;
  lastchangedat             : abp_lastchange_tstmpl;
  locallastchangedat        : abp_locinst_lastchange_tstmpl;
  "%admin"                  : include sych_bdl_draft_admin_inc;

}
