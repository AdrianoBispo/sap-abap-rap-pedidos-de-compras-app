@EndUserText.label : 'Draft - Snapshot do cliente no pedido'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zd_pc_snap_cli {

  key client         : abap.clnt not null;
  key snapshotuuid   : sysuuid_x16 not null;
  pedidouuid         : sysuuid_x16;
  clienteuuid        : sysuuid_x16;
  cpf                : abap.char(11);
  nome               : abap.char(255);
  email              : abap.char(100);
  telefone           : abap.char(11);
  genero             : abap.char(30);
  datanascimento     : abap.dats;
  clienteativo       : abap_boolean;
  scorecliente       : abap.dec(5,2);
  enderecouuid       : sysuuid_x16;
  cep                : abap.char(8);
  logradouro         : abap.char(150);
  numero             : abap.char(20);
  complemento        : abap.char(100);
  bairro             : abap.char(100);
  cidade             : abap.char(100);
  uf                 : abap.char(2);
  estado             : abap.char(100);
  enderecocompleto   : abap.char(500);
  motivosnapshot     : abap.char(40);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}
