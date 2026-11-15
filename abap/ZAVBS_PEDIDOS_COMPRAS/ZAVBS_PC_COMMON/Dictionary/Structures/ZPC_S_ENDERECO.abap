@EndUserText.label : 'Endereço (logradouro a estado)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_endereco {

  logradouro  : zpc_de_logradouro;
  numero      : zpc_de_numero_endereco;
  complemento : zpc_de_complemento;
  bairro      : zpc_de_bairro;
  cidade      : zpc_de_cidade;
  uf          : zpc_de_uf;
  estado      : zpc_de_estado;

}