@EndUserText.label: 'Parâmetro - resultado da consulta de CEP'
/* Mesmos campos de ZI_PC_CEP_LOOKUP: a UI repassa a linha lida da
   custom entity, sem transformação, como parâmetro de AplicarDadosCep. */
define abstract entity ZPC_A_CEP_RESULTADO
{
  @EndUserText.label: 'CEP'
  Cep         : abap.char(8);
  @EndUserText.label: 'Logradouro'
  Logradouro  : abap.char(150);
  @EndUserText.label: 'Complemento'
  Complemento : abap.char(100);
  @EndUserText.label: 'Bairro'
  Bairro      : abap.char(100);
  @EndUserText.label: 'Cidade'
  Cidade      : abap.char(100);
  @EndUserText.label: 'UF'
  Uf          : abap.char(2);
  @EndUserText.label: 'Estado'
  Estado      : abap.char(100);
  @EndUserText.label: 'CEP geral'
  CepGeral    : abap_boolean;
  @EndUserText.label: 'Status'
  Status      : abap.char(1);
  @EndUserText.label: 'Mensagem'
  Message     : abap.char(120);
}
