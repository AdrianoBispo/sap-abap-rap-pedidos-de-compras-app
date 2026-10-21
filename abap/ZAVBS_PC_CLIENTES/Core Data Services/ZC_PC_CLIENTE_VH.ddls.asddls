@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clientes ativos - Value Help'
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true

/* View reutilizável consumida pela aplicação Pedidos de Compras.
   Somente clientes ativos são oferecidos para novos pedidos.        */

define view entity ZC_PC_CLIENTE_VH
  as select from ZR_PC_CLIENTE
{
      @UI.hidden: true
      @ObjectModel.text.element: [ 'Nome' ]
  key ClienteUUID,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'CPF'
      Cpf,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      @EndUserText.label: 'Nome'
      Nome,

      @EndUserText.label: 'E-mail'
      Email,

      @EndUserText.label: 'Cidade'
      _EnderecoPrincipal.Cidade as Cidade,

      @EndUserText.label: 'UF'
      _EnderecoPrincipal.Uf     as Uf
}
where
  ClienteAtivo = 'X'
