"! <p class="shorttext synchronized">Pedidos de Compras - Carga de pedidos de demonstração</p>
"! Constantes, tipos e métodos públicos de ZCL_SETUP_PEDIDOS, que implementa esta interface.
INTERFACE zif_setup_pedidos PUBLIC.

  CONSTANTS c_quantidade TYPE i VALUE 100.
  CONSTANTS c_marcador TYPE string VALUE `Pedido de demonstração`.

  METHODS carregar_dados
    IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
    RAISING   cx_uuid_error cx_number_ranges.

ENDINTERFACE.