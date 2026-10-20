"! <p class="shorttext synchronized">Pedidos de Compras - Constantes globais</p>
INTERFACE zif_pc_constants PUBLIC.

  TYPES ty_status_pedido    TYPE c LENGTH 40.
  TYPES ty_status_pagamento TYPE c LENGTH 30.
  TYPES ty_metodo_pagamento TYPE c LENGTH 20.
  TYPES ty_status_estoque   TYPE c LENGTH 30.
  TYPES ty_codelist         TYPE c LENGTH 30.

  "! Modo educacional do SAP BTP ABAP Environment Trial. No On-Premise
  "! (SAP S/4HANA 2025) fica sempre abap_false: ZCL_PC_AUTH executa o
  "! AUTHORITY-CHECK em ZPC_ADMIN / ZPC_PEDIDO, atribuídos pelas roles PFCG
  "! Z_PC_ADMIN / Z_PC_COMUM. Nunca transporte para QAS/PRD com abap_true.
  CONSTANTS c_modo_trial TYPE abap_boolean VALUE abap_false.

  CONSTANTS c_moeda_padrao TYPE waers VALUE 'BRL'.

  CONSTANTS:
    BEGIN OF c_status_pedido,
      aberto                TYPE ty_status_pedido VALUE 'ABERTO',
      aguardando_aprovacao  TYPE ty_status_pedido VALUE 'AGUARDANDO_APROVACAO',
      processando_reembolso TYPE ty_status_pedido VALUE 'PROCESSANDO_REEMBOLSO',
      cancelado             TYPE ty_status_pedido VALUE 'CANCELADO',
      finalizado            TYPE ty_status_pedido VALUE 'FINALIZADO',
    END OF c_status_pedido.

  CONSTANTS:
    BEGIN OF c_status_pagamento,
      pendente TYPE ty_status_pagamento VALUE 'PENDENTE',
      aprovado TYPE ty_status_pagamento VALUE 'APROVADO',
      recusado TYPE ty_status_pagamento VALUE 'RECUSADO',
      devolvido TYPE ty_status_pagamento VALUE 'DEVOLVIDO',
    END OF c_status_pagamento.

  TYPES ty_status_reembolso TYPE c LENGTH 20.

  "! Ciclo de vida da solicitação de reembolso (ver ZR_PC_REEMBOLSO).
  "! Criada quando CancelarPedido é chamado com StatusPagamento = APROVADO;
  "! decidida por AprovarReembolso/RejeitarReembolso (Pedido~*).
  CONSTANTS:
    BEGIN OF c_status_reembolso,
      pendente  TYPE ty_status_reembolso VALUE 'PENDENTE',
      aprovado  TYPE ty_status_reembolso VALUE 'APROVADO',
      rejeitado TYPE ty_status_reembolso VALUE 'REJEITADO',
    END OF c_status_reembolso.

  CONSTANTS:
    BEGIN OF c_metodo_pagamento,
      credito TYPE ty_metodo_pagamento VALUE 'CARTAO_CREDITO',
      debito  TYPE ty_metodo_pagamento VALUE 'CARTAO_DEBITO',
    END OF c_metodo_pagamento.

  CONSTANTS:
    BEGIN OF c_status_estoque,
      sem_estoque TYPE ty_status_estoque VALUE 'SEM_ESTOQUE',
      acabando    TYPE ty_status_estoque VALUE 'ACABANDO',
      em_estoque  TYPE ty_status_estoque VALUE 'EM_ESTOQUE',
    END OF c_status_estoque.

  "! Limite superior da faixa ACABANDO (1 a 10). A partir de 11 = EM_ESTOQUE.
  CONSTANTS c_limite_acabando TYPE i VALUE 10.

  "! Resultado da consulta ao ViaCEP, gravado pela determination (fase de
  "! interação) e avaliado pela validation (fase de save, sem I/O remoto).
  CONSTANTS:
    BEGIN OF c_status_cep,
      validado     TYPE c LENGTH 1 VALUE 'V',
      invalido     TYPE c LENGTH 1 VALUE 'I',
      indisponivel TYPE c LENGTH 1 VALUE 'X',
    END OF c_status_cep.

  CONSTANTS:
    BEGIN OF c_codelist,
      genero           TYPE ty_codelist VALUE 'GENERO',
      categoria        TYPE ty_codelist VALUE 'CATEGORIA',
      status_pedido    TYPE ty_codelist VALUE 'STATUS_PEDIDO',
      status_pagamento TYPE ty_codelist VALUE 'STATUS_PAGAMENTO',
      status_estoque   TYPE ty_codelist VALUE 'STATUS_ESTOQUE',
      metodo_pagamento TYPE ty_codelist VALUE 'METODO_PAGAMENTO',
      status_reembolso TYPE ty_codelist VALUE 'STATUS_REEMBOLSO',
    END OF c_codelist.

  "! Objeto de intervalo de numeração (Number Range Object) do projeto.
  CONSTANTS:
    BEGIN OF c_numeracao,
      objeto          TYPE c LENGTH 10 VALUE 'ZPC_NR',
      intervalo_pedido TYPE c LENGTH 2 VALUE '01',
      intervalo_sku    TYPE c LENGTH 2 VALUE '02',
      " Intervalos do mesmo objeto não podem se sobrepor. O SKU exibe o
      " número relativo ao início do intervalo 02 (sku_de => 0000000000).
      pedido_de        TYPE n LENGTH 10 VALUE '0000000001',
      pedido_ate       TYPE n LENGTH 10 VALUE '4999999999',
      sku_de           TYPE n LENGTH 10 VALUE '5000000000',
      sku_ate          TYPE n LENGTH 10 VALUE '9999999999',
    END OF c_numeracao.

  "! Objetos de autorização (criados no ADT e atribuídos às IAM Apps).
  CONSTANTS:
    BEGIN OF c_auth,
      objeto_admin  TYPE c LENGTH 10 VALUE 'ZPC_ADMIN',
      objeto_pedido TYPE c LENGTH 10 VALUE 'ZPC_PEDIDO',
    END OF c_auth.

  CONSTANTS:
    BEGIN OF c_mime,
      jpeg TYPE string VALUE `image/jpeg`,
      png  TYPE string VALUE `image/png`,
      webp TYPE string VALUE `image/webp`,
    END OF c_mime.

ENDINTERFACE.