@EndUserText.label: 'Parâmetros - Retomar pedido após reembolso rejeitado'
define abstract entity ZPC_A_RETOMADA_INPUT
{
  @EndUserText.label: 'Status anterior do pedido'
  StatusAnterior : abap.char(40);
}
