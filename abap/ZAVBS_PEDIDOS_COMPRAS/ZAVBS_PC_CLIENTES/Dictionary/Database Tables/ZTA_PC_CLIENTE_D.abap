@EndUserText.label : 'Draft table for entity ZR_PC_CLIENTE'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_cliente_d {

  key mandt       : mandt not null;
  key clienteuuid : sysuuid_x16 not null;
  fotocliente     : zpc_de_foto;
  fotomimetype    : zpc_de_mime_type;
  fotofilename    : zpc_de_nome_arquivo;
  include zpc_s_dados_cliente_d;
  include zpc_s_admin_d;
  "%admin"        : include sych_bdl_draft_admin_inc;

}