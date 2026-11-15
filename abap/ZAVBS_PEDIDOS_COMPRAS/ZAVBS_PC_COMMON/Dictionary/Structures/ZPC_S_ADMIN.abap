@EndUserText.label : 'Campos administrativos (managed)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_admin {

  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}