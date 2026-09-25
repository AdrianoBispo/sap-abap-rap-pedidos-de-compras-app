/* Campos administrativos comuns às tabelas ativas do projeto. Os tipos
   abp_* são os elementos de dados padrão do RAP para @Semantics.user /
   @Semantics.systemDateTime e não foram substituídos por ZDE_PC_*.     */
@EndUserText.label : 'Pedidos de Compras - Campos administrativos RAP'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_admin {

  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
