/* Campos de negócio de ZTA_PC_ENDERECO (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Endereço do cliente - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_endereco {

  cliente_uuid       : zde_pc_cliente_uuid;
  cep                : zde_pc_cep;
  logradouro         : zde_pc_logradouro;
  numero             : zde_pc_numero_endereco;
  complemento        : zde_pc_complemento;
  bairro             : zde_pc_bairro;
  cidade             : zde_pc_cidade;
  uf                 : zde_pc_uf;
  estado             : zde_pc_estado;
  cep_geral          : abap_boolean;
  cep_status         : zde_pc_cep_status;
  consulted_cep      : zde_pc_cep_consultado;
  endereco_principal : abap_boolean;

}
