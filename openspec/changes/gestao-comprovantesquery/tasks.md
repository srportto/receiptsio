## 1. Esqueleto e spike do contrato

- [x] 1.1 Gerar `apps/gestao-comprovantesquery` com `criar-aplicacao-java` (Java 25 sem preview, Spring Boot 4, Maven, hexagonal, variante REST com banco, rota `/disponibilidade`), sem Spring Security e sem springdoc. Prova: `mvn -q verify` passa e `GET /disponibilidade` responde 200 com banco de pé.
- [x] 1.2 Spike do teste de contrato (design D6): escolher a biblioteca que valida JSON Schema 2020-12 (tipo `["string","null"]`) lendo os componentes de `docs/contratos-rest/gestao-comprovantesquery/openapi.yaml`. Prova: teste que valida um corpo válido e rejeita um inválido (campo faltando e `situacao` fora do enum), com saída lida.
- [x] 1.3 Preparar o teste de integração com Testcontainers sobre a imagem `postgres18-receiptsio-extras-partman_cron_vector:1.0`, montando `infra/local/postgres/migrations`, com a role `catalogo_leitura`. Prova: teste de fumaça lê `catalogo.modelo` e conta 6 modelos do seed; sem a imagem, falha com mensagem clara.

## 2. Domínio e aplicação (TDD: teste falhando primeiro)

- [x] 2.1 Tipos do domínio `IdModelo`, `Versao`, `Situacao`, `PageRequest` com invariantes e acúmulo de todos os erros. Prova: testes de unidade (`idModelo` minúsculo, `versao` 0/1000, `size` 0/101, `page` 0, `situacao` desconhecida; vários erros juntos).
- [x] 2.2 `Pagination` e `Pagina<T>` (`totalPages` = 0 sem itens; arredondamento para cima). Prova: testes de unidade (0, 3 itens/size 2, página além da última).
- [x] 2.3 Modelo de leitura (`ModeloResumo`, `ModeloDetalhe`, `CampoEstrutural`, `CampoVariavel`, templates) e porta de saída `CatalogoModelos`. Prova: compila e os casos de uso `ListarModelos` e `DetalharModelo` têm teste de unidade com a porta simulada (filtro repassado, 404 como exceção de domínio).

## 3. Adaptador de persistência

- [x] 3.1 Consulta da listagem (`catalogo.modelo`) com filtros opcionais parametrizados, ordem fixa, `LIMIT/OFFSET` e `count(*)` na mesma transação `readOnly`. Prova: teste de integração sobre o seed cobrindo sem filtro, `ATIVO`, `RASCUNHO`, `idModelo`, `idModelo`+`versao`, combinação e página além da última.
- [x] 3.2 Consulta do detalhe (`catalogo.vw_modelo_completo`) convertendo o `jsonb` para o domínio. Prova: teste de integração com `COMPTED` v1 (5 indexadores), `COMPBOL` v2 (rascunho sem indexador 1), descrição efetiva e contagem de campos igual à da view.
- [x] 3.3 Pool e timeouts (D8) e conexão `readOnly`, com senha vinda do ambiente e falha de subida nomeando a variável ausente. Prova: teste de configuração com variável ausente; teste de integração que tenta `INSERT`/`UPDATE`/`DELETE` em `catalogo.modelo` pela conexão da aplicação e recebe `42501`.

## 4. API REST

- [x] 4.1 Controller `GET /modelos` (filtros, `page`, `size`) e `GET /modelos/{idModelo}/versoes/{versao}`, convertendo `snake_case` em camelCase no contrato. Prova: testes de API (MockMvc ou servidor real) para cada cenário da spec, incluindo 405 em `POST`/`PUT`/`PATCH`/`DELETE`.
- [x] 4.2 Tratador de erros RFC 9457: 400 com `errors[]` (todos os parâmetros inválidos, antes do banco), 404, 405, 503 com `Retry-After` (banco parado, pool esgotado, timeout), 500 genérico sem vazamento. Prova: testes de API para cada status; o de 400 de path confirma que o banco não foi consultado; o de 503 para o banco com o container parado; nenhum corpo contém SQL, tabela ou stack.
- [x] 4.3 Teste de contrato: toda resposta de sucesso e de erro dos testes de API valida contra `openapi.yaml` (`PaginaModelos`, `ModeloDetalhe`, `ProblemDetails`). Prova: teste verde; prova negativa: alterar temporariamente um nome de campo no mapeamento faz o teste de contrato falhar (revertido depois).
- [x] 4.4 Garantias estáticas: nenhuma ocorrência de `io.swagger`/`springdoc` e nenhuma dependência `spring-security`. Prova: `mvn dependency:tree` e `grep` lidos, sem ocorrências.

## 5. Limites e comportamento sob falha

- [x] 5.1 Provar `queryTimeout`: consulta que excede o limite devolve 503 e a conexão volta ao pool. Prova: teste com `pg_sleep` (ou timeout reduzido por propriedade) e verificação de que o pool segue atendendo a próxima requisição.
- [x] 5.2 Provar o teto do pool: com o pool reduzido a 1 e uma conexão retida, a próxima requisição responde 503 em até `connectionTimeout`. Prova: teste de integração com medição do tempo lida.

## 6. Documentação e verificação ponta a ponta

- [x] 6.1 `README.md` em `apps/gestao-comprovantesquery`: como subir (banco local, `.env`, `mvn spring-boot:run`), variáveis, limites (D8), como rodar os testes e como usar a coleção Bruno. Atualizar `docs/contratos-rest/gestao-comprovantesquery/README.md` se o contrato mudar durante a implementação.
- [x] 6.2 Prova ponta a ponta: subir banco e aplicação e executar a coleção Bruno (`bru run` na pasta `docs/contratos-rest/gestao-comprovantesquery/bruno` com o ambiente `local`). Prova: 8/8 requisições com testes passando, saída lida. Se o CLI do Bruno não estiver instalado, rodar as mesmas chamadas com `curl` e registrar a saída.
- [x] 6.3 Atualizar `IMPLEMENTACAO_SUMARIO.md` (nova seção da aplicação de consulta e remoção do item correspondente em "Próximos passos").

## 7. Auditoria

- [ ] 7.1 Auditoria do `java-revisor` (modo `auditoria`) sobre `apps/gestao-comprovantesquery`, com veredicto APROVADO. Prova: relatório do agent; pendências corrigidas e a auditoria repetida até APROVADO.
