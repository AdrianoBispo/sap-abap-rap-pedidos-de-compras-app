@EndUserText.label : 'Dados do cliente - tabelas draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_dados_cliente_d {

  cpf            : zpc_de_cpf;
  nome           : zpc_de_nome_cliente;
  email          : zpc_de_email;
  telefone       : zpc_de_telefone;
  genero         : zpc_de_genero;
  datanascimento : zpc_de_data_nascimento;
  clienteativo   : abap_boolean;
  scorecliente   : zpc_de_score_cliente;

}