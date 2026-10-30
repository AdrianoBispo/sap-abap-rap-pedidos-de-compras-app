/* ---------------------------------------------------------------------
 Entidade abstrata: filho de ZPC_A_UPLOAD_INPUT que carrega o arquivo da planilha enviada
 pela action ImportarPlanilha. Não é persistida nem consultável.
 --------------------------------------------------------------------- */

@EndUserText.label: 'Parâmetro - arquivo de planilha (stream)'
define root abstract entity ZPC_A_FILE_STREAM
{
  // Conteúdo binário do arquivo. As anotações largeObject fazem o Fiori Elements exibir o
  // upload e preencher MimeType e FileName automaticamente.
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
