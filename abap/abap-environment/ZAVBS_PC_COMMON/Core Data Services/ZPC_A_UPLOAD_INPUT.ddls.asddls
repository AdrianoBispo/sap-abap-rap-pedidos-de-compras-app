@EndUserText.label: 'Parâmetro - upload de planilha'
define root abstract entity ZPC_A_UPLOAD_INPUT
{
  @UI.hidden: true
  Dummy             : abap_boolean;

  _StreamProperties : association [1] to ZPC_A_FILE_STREAM on 1 = 1;
}
