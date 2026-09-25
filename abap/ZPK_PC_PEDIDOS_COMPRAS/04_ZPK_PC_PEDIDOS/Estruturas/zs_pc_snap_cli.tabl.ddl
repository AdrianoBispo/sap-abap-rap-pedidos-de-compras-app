/* Campos de negócio de ZTA_PC_SNAP_CLI (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Snapshot do cliente - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_snap_cli {

  pedido_uuid       : zde_pc_pedido_uuid;
  cliente_uuid      : zde_pc_cliente_uuid;
  cpf               : zde_pc_cpf;
  nome              : zde_pc_nome_cliente;
  email             : zde_pc_email;
  telefone          : zde_pc_telefone;
  genero            : zde_pc_genero;
  data_nascimento   : zde_pc_data_nascimento;
  cliente_ativo     : abap_boolean;
  score_cliente     : zde_pc_score_cliente;
  endereco_uuid     : zde_pc_endereco_uuid;
  cep               : zde_pc_cep;
  logradouro        : zde_pc_logradouro;
  numero            : zde_pc_numero_endereco;
  complemento       : zde_pc_complemento;
  bairro            : zde_pc_bairro;
  cidade            : zde_pc_cidade;
  uf                : zde_pc_uf;
  estado            : zde_pc_estado;
  endereco_completo : zde_pc_endereco_completo;
  motivo_snapshot   : zde_pc_motivo_snapshot;

}
