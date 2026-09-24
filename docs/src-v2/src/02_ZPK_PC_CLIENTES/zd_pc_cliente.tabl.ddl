@EndUserText.label : 'Draft - Cliente'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zd_pc_cliente {

  key client         : abap.clnt not null;
  key clienteuuid    : sysuuid_x16 not null;
  fotocliente        : abap.rawstring(0);
  fotomimetype       : abap.char(50);
  fotofilename       : abap.char(255);
  cpf                : abap.char(11);
  nome               : abap.char(255);
  email              : abap.char(100);
  telefone           : abap.char(11);
  genero             : abap.char(30);
  datanascimento     : abap.dats;
  clienteativo       : abap_boolean;
  scorecliente       : abap.dec(5,2);
  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}
