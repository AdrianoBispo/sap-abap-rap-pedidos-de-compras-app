/* Campos de negócio de ZTA_PC_CLIENTE (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Cliente - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_cliente {

  foto_cliente    : zde_pc_foto_cliente;
  foto_mime_type  : zde_pc_mime_type;
  foto_file_name  : zde_pc_nome_arquivo;
  cpf             : zde_pc_cpf;
  nome            : zde_pc_nome_cliente;
  email           : zde_pc_email;
  telefone        : zde_pc_telefone;
  genero          : zde_pc_genero;
  data_nascimento : zde_pc_data_nascimento;
  cliente_ativo   : abap_boolean;
  score_cliente   : zde_pc_score_cliente;

}
