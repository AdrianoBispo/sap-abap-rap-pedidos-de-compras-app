/* ---------------------------------------------------------------------
 Entidade abstrata: raiz do parâmetro profundo (deep) da action estática ImportarPlanilha
 (ZR_PC_CLIENTE, ZR_PC_ITEM e ZR_PC_PEDIDO). Não é persistida nem consultável.
 --------------------------------------------------------------------- */

@EndUserText.label: 'Parâmetro - upload de planilha'
define root abstract entity ZPC_A_UPLOAD_INPUT
{
  // Campo técnico: uma entidade abstrata precisa de ao menos um campo próprio.
  // Por isso que esse campo é declarado e ocultado no metadata do OData
  @UI.hidden: true
  Dummy             : abap_boolean;

  // Filho que carrega o arquivo (conteúdo, MimeType e FileName);
  _StreamProperties : association [1] to ZPC_A_FILE_STREAM on 1 = 1;
}
