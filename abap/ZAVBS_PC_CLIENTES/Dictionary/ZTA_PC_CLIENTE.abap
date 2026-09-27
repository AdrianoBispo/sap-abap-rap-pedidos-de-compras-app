@EndUserText.label : 'Pedidos de Compras - Clientes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_cliente {

  key client            : abap.clnt not null;
  key cliente_uuid      : sysuuid_x16 not null;
  foto_cliente          : abap.rawstring(0);
  foto_mime_type        : abap.char(50);
  foto_file_name        : abap.char(255);
  cpf                   : abap.char(11);
  nome                  : abap.char(255);
  email                 : abap.char(100);
  telefone              : abap.char(11);
  genero                : abap.char(30);
  data_nascimento       : abap.dats;
  cliente_ativo         : abap_boolean;
  score_cliente         : abap.dec(5,2);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}