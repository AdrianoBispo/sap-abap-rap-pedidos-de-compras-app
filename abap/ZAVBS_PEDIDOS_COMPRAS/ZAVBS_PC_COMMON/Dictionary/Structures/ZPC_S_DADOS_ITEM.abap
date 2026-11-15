@EndUserText.label : 'Dados do item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zpc_s_dados_item {

  sku       : zpc_de_sku;
  nome      : zpc_de_nome_item;
  descricao : zpc_de_descricao_item;
  categoria : zpc_de_categoria;

}