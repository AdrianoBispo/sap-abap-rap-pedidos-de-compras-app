@EndUserText.label: 'Parâmetros - Cancelar pedido'
define abstract entity ZPC_A_CANCELAMENTO_INPUT
{
  @EndUserText.label: 'Motivo do cancelamento'
  MotivoCancelamento : abap.char(500);
}
