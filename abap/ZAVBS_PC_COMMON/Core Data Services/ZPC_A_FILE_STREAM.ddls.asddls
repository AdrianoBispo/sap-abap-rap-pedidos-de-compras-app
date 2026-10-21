@EndUserText.label: 'Parâmetro - arquivo de planilha (stream)'
define root abstract entity ZPC_A_FILE_STREAM
{
  @Semantics.largeObject.mimeType: 'MimeType'
  @Semantics.largeObject.fileName: 'FileName'
  @Semantics.largeObject.contentDispositionPreference: #INLINE
  @EndUserText.label: 'Planilha (.xlsx ou .csv)'
  StreamProperty : abap.rawstring(0);

  @UI.hidden: true
  MimeType       : abap.char(128);

  @UI.hidden: true
  FileName       : abap.char(128);
}
