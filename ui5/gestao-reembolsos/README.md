## gestao-reembolsos

Aprovação e rejeição de solicitações de reembolso de pedidos (List Report + Object Page, Fiori Elements V4).

- Serviço: `ZUI_PC_REEMBOLSOS` (service binding OData V4 `ZUI_PC_REEMBOLSOS_O4`), entity set `Reembolso`
- Actions: **Aprovar reembolso** (cancela o pedido, libera a reserva e gera os snapshots) e **Rejeitar reembolso** (motivo obrigatório; o pedido retoma o status anterior)
- As solicitações são criadas pela app Pedidos de Compras (cancelamento de pedido com pagamento aprovado); aqui não há criação/edição/exclusão
- Deploy: `npm run deploy` (BSP `ZPC_REEMBOLSOS`, pacote `ZAVBS_PC_PEDIDOS`)
- Intent do launchpad: `ZPCReembolso-manage`
