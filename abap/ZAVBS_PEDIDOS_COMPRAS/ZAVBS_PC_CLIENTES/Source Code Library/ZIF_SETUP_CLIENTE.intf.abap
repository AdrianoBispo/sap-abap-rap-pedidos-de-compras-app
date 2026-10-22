"! <p class="shorttext synchronized">Pedidos de Compras - Carga de clientes de demonstração</p>
"! Constantes, tipos e métodos públicos de ZCL_SETUP_CLIENTE, que implementa esta interface.
INTERFACE zif_setup_cliente PUBLIC.

  CONSTANTS c_quantidade TYPE i VALUE 100.

  METHODS carregar_dados
    IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out
    RAISING   cx_uuid_error.

ENDINTERFACE.