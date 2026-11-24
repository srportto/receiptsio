## Why

O catálogo de modelos de comprovante existe no PostgreSQL, mas só dá para inspecioná-lo por SQL. O administrador precisa, numa tela web, ver quais modelos estão ativos, quais são rascunhos e quais campos compõem cada um. Uma API de consulta isolada entrega isso sem tocar no catálogo: o banco já garante a leitura segura pela role `catalogo_leitura`.

## What Changes

- Nova aplicação `apps/gestao-comprovantesquery`: API REST **somente leitura** (Java 25 sem preview, Spring Boot 4, hexagonal), variante REST com banco de `criar-aplicacao-java`.
- `GET /modelos`: lista simples paginada (`Pagination` por offset: `page` a partir de 1, `size` padrão 20, máx. 100), com filtros opcionais e combináveis `situacao`, `idModelo` e `versao`. Sem `situacao`, lista todas as situações. Ordem fixa: `idModelo` crescente, `versao` decrescente.
- `GET /modelos/{idModelo}/versoes/{versao}`: detalha um modelo com os campos dos templates estrutural e variável (ordem, tipo, indexador, aceita nulo, descrição efetiva).
- Contrato já escrito em `docs/contratos-rest/gestao-comprovantesquery/` (OpenAPI 3.1 + coleção Bruno). É a fonte da verdade; a aplicação **não** leva anotações OpenAPI e é validada contra esse arquivo.
- Conexão somente com a role `catalogo_leitura`, lendo `catalogo.modelo` e `catalogo.vw_modelo_completo`.
- Erros em RFC 9457 (400, 404, 500, 503).
- Fora de escopo: autenticação, autorização, Spring Security e CORS (camada web/gateway), escrita de qualquer tipo, cache, ordenação customizada, paginação por cursor, alterações no banco.

## Capabilities

### New Capabilities
- `consulta-catalogo-modelos`: consulta read-only de modelos de comprovante e seus campos pela API REST (listagem paginada com filtros, detalhe, erros, garantia de somente leitura).

### Modified Capabilities

(nenhuma: o catálogo e o ambiente local não mudam de requisito)

## Impact

- Código novo em `apps/gestao-comprovantesquery` (Java 25, Spring Boot 4, Maven).
- Depende do PostgreSQL local (`infra/local/postgres`), do seed e da role `catalogo_leitura`, usando `DB_CATALOGO_LEITURA_PASSWORD` do `.env`.
- `docs/contratos-rest/gestao-comprovantesquery/` passa a ser verificado por teste de contrato.
- Sem mudança em migrations, specs existentes ou infra. Por haver código Java, a última tarefa é a auditoria do `java-revisor`.
