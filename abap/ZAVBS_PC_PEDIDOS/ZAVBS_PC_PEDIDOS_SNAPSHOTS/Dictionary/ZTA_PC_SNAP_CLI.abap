@EndUserText.label : 'Snapshot do cliente no pedido'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zta_pc_snap_cli {

  key client            : abap.clnt not null;
  key snapshot_uuid     : sysuuid_x16 not null;
  pedido_uuid           : sysuuid_x16;
  cliente_uuid          : sysuuid_x16;
  cpf                   : abap.char(11);
  nome                  : abap.char(255);
  email                 : abap.char(100);
  telefone              : abap.char(11);
  genero                : abap.char(30);
  data_nascimento       : abap.dats;
  cliente_ativo         : abap_boolean;
  score_cliente         : abap.dec(5,2);
  endereco_uuid         : sysuuid_x16;
  cep                   : abap.char(8);
  logradouro            : abap.char(150);
  numero                : abap.char(20);
  complemento           : abap.char(100);
  bairro                : abap.char(100);
  cidade                : abap.char(100);
  uf                    : abap.char(2);
  estado                : abap.char(100);
  endereco_completo     : abap.char(500);
  motivo_snapshot       : abap.char(40);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}