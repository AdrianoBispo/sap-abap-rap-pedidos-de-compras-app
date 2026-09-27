@EndUserText.label: 'Parâmetros - Simular pagamento'
/* Dados do cartão existem apenas em memória durante a action
   SimularPagamento. Número completo, validade e CVV NUNCA são
   persistidos (somente bandeira, últimos 4 dígitos e máscara). */
define abstract entity ZPC_A_PAGAMENTO_INPUT
{
  @EndUserText.label: 'Método de pagamento'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_METODOPAG_VH', element: 'Codigo' } }]
  MetodoPagamento : abap.char(20);

  @EndUserText.label: 'Número do cartão'
  NumeroCartao    : abap.char(19);

  @EndUserText.label: 'Validade (MM/AA)'
  Validade        : abap.char(5);

  @EndUserText.label: 'CVV'
  Cvv             : abap.char(4);
}
