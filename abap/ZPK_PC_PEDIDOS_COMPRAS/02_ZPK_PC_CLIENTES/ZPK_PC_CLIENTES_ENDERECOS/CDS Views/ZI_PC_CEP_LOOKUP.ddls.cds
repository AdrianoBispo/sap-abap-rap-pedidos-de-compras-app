@EndUserText.label: 'Consulta de CEP (ViaCEP)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_PC_CEP_LOOKUP_PROVIDER'
/* Consultada pela seção "Consulta de CEP" da app de Clientes com
   $filter=Cep eq '<8 dígitos>'. Nunca falha por CEP inexistente: devolve
   uma linha com Status I (inválido) ou X (ViaCEP indisponível).
   O resultado é repassado à ação AplicarDadosCep do Endereço.         */
define custom entity ZI_PC_CEP_LOOKUP
{
      @EndUserText.label: 'CEP'
  key Cep         : abap.char(8);

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
