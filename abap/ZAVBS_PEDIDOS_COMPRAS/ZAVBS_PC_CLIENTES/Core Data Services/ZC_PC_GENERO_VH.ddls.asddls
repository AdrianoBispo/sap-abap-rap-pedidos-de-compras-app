@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Gênero - Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true

define view entity ZC_PC_GENERO_VH
  as select from ZR_PC_CODELIST
{
      @ObjectModel.text.element: ['Descricao']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Gênero'
  key Codigo,
  
      @Semantics.text: true
      @EndUserText.label: 'Descrição'
      Descricao,
      
      @UI.hidden: true
      Criticality,
      
      @UI.hidden: true
      Ordem
}
where
  Lista = 'GENERO'
