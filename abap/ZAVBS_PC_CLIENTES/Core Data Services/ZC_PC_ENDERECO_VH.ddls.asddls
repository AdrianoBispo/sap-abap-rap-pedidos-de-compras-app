@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Endereços do cliente - Value Help'
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true

/* View reutilizável consumida pela aplicação Pedidos de Compras.
   Usar com additionalBinding em ClienteUUID.                          */

define view entity ZC_PC_ENDERECO_VH
  as select from ZR_PC_ENDERECO
{
      @UI.hidden: true
      @ObjectModel.text.element: [ 'Descricao' ]
  key EnderecoUUID,

      @UI.hidden: true
      ClienteUUID,

      @Semantics.text: true
      @EndUserText.label: 'Endereço'
      @Search.defaultSearchElement: true
      concat_with_space( concat( Logradouro, ',' ), Numero, 1 ) as Descricao,

      @EndUserText.label: 'CEP'
      @Search.defaultSearchElement: true
      Cep,

      @EndUserText.label: 'Bairro'
      Bairro,

      @EndUserText.label: 'Cidade'
      Cidade,

      @EndUserText.label: 'UF'
      Uf,

      @EndUserText.label: 'Principal'
      EnderecoPrincipal
}
