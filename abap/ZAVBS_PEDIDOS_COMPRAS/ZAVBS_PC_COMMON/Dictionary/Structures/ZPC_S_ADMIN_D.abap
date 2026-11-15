@EndUserText.label : 'Campos administrativos - tabelas draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_admin_d {

  createdby          : abp_creation_user;
  createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_lastchange_user;
  lastchangedat      : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;

}