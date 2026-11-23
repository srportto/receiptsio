# Contrato REST: gestao-comprovantesquery

API somente leitura do catálogo de modelos de comprovante, para a tela web de administração.

- `openapi.yaml`: contrato OpenAPI 3.1, **fonte da verdade**. A aplicação não leva anotações OpenAPI.
- `bruno/`: coleção do [Bruno](https://www.usebruno.com/). Abra a pasta `bruno/` (Open Collection) e escolha o
  ambiente `local` (`baseUrl` = `http://localhost:9080`). Os dados esperados são os do seed de `infra/local/postgres`.

| Operação | Rota | Observação |
|---|---|---|
| Listar | `GET /modelos` | filtros opcionais `situacao`, `idModelo`, `versao`; paginação `page` (a partir de 1) e `size` (padrão 20, máx. 100) |
| Detalhar | `GET /modelos/{idModelo}/versoes/{versao}` | modelo + campos estruturais e variáveis |

Resposta de listagem: `{ items: [...], pagination: { page, size, totalElements, totalPages } }`.
Erros: `application/problem+json` (RFC 9457): 400, 404, 500, 503.
