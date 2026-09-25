/* Campos de negócio de ZTA_PC_CODELIST (sem a chave, declarada na tabela). */
@EndUserText.label : 'Pedidos de Compras - Dados de um código de CodeList'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_codelist {

  descricao   : zde_pc_codelist_descricao;
  criticality : zde_pc_criticality;
  ordem       : zde_pc_codelist_ordem;

}
