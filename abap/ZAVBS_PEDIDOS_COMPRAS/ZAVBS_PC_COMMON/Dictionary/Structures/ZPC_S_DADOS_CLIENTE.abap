@EndUserText.label : 'Dados do cliente'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_dados_cliente {

  cpf             : zpc_de_cpf;
  nome            : zpc_de_nome_cliente;
  email           : zpc_de_email;
  telefone        : zpc_de_telefone;
  genero          : zpc_de_genero;
  data_nascimento : zpc_de_data_nascimento;
  cliente_ativo   : abap_boolean;
  score_cliente   : zpc_de_score_cliente;

}