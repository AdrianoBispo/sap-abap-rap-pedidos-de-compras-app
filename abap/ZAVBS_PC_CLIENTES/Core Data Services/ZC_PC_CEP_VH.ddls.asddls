@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CEPs já cadastrados - Value Help'
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true

/* Um registro por CEP já validado no cadastro de endereços. Ao escolher um
   CEP, a determination PreencherEnderecoViaCep reaproveita estes dados e só
   consulta o ViaCEP quando o CEP ainda não existe no cadastro. CEP geral de
   município fica de fora: logradouro e bairro variam de endereço para endereço. */
define view entity ZC_PC_CEP_VH
  as select from ZR_PC_ENDERECO
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'CEP'
  key Cep,

      @EndUserText.label: 'Logradouro'
      max( Logradouro ) as Logradouro,

      @EndUserText.label: 'Bairro'
      max( Bairro )     as Bairro,

      @EndUserText.label: 'Cidade'
      max( Cidade )     as Cidade,

      @EndUserText.label: 'UF'
      max( Uf )         as Uf,

      @EndUserText.label: 'Estado'
      max( Estado )     as Estado,

      @EndUserText.label: 'Endereços com este CEP'
      count( * )        as QtdeEnderecos
}
where
      CepStatus = 'V'
  and CepGeral  = ''
group by
  Cep
