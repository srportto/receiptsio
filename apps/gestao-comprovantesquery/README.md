# gestao-comprovantesquery

API REST **somente leitura** do catálogo de modelos de comprovante (schema `catalogo` do PostgreSQL local).
Atende a tela web de administração: listar e filtrar modelos (ativos, rascunhos, inativos) e detalhar um modelo com
todos os seus campos.

Java 25 (sem preview) + Spring Boot 4, arquitetura hexagonal clássica, SQL explícito com `JdbcClient`.
Sem Spring Security, sem autenticação e sem CORS: esses controles são da camada web/gateway à frente da API.

## Contrato

O contrato é artefato independente do código e está em
[`docs/contratos-rest/gestao-comprovantesquery/`](../../docs/contratos-rest/gestao-comprovantesquery/README.md)
(`openapi.yaml` + coleção do Bruno). A aplicação **não** tem anotações OpenAPI: os testes validam cada resposta
contra os schemas do `openapi.yaml`.

| Operação | Rota | Observação |
|---|---|---|
| Listar | `GET /modelos` | filtros opcionais `situacao` (`RASCUNHO`/`ATIVO`/`INATIVO`), `idModelo`, `versao`; `page` (a partir de 1) e `size` (padrão 20, máx. 100). Sem filtro, lista tudo |
| Detalhar | `GET /modelos/{idModelo}/versoes/{versao}` | modelo + campos estruturais (com indexadores) e variáveis |
| Smoke | `GET /disponibilidade` | `{"aplicacao":"gestao-comprovantesquery","status":"DISPONIVEL"}` |
| Probes | `GET /actuator/health/liveness` e `/readiness` | o banco fica **fora** da readiness; `/actuator/health/dependencias` mostra o estado do banco |

Resposta da listagem: `{ "items": [...], "pagination": { "page", "size", "totalElements", "totalPages" } }`.
Erros: `application/problem+json` (RFC 9457): 400 (com `errors[]`, todos os parâmetros inválidos de uma vez),
404, 405 (qualquer método de escrita), 503 com `Retry-After` (banco fora, pool esgotado ou consulta acima do limite)
e 500 genérico (a causa só vai para o log).

## Como rodar

Pré-requisito: o banco local de pé, com o seed (ver [`infra/local/postgres/README.md`](../../infra/local/postgres/README.md)) e
o `.env` da raiz preenchido.

```bash
cd apps/gestao-comprovantesquery
set -a; . ../../.env; set +a          # carrega DB_NAME, DB_PORT e DB_CATALOGO_LEITURA_PASSWORD
mvn spring-boot:run                    # ou: mvn clean package && java -jar target/gestao-comprovantesquery-0.0.1-SNAPSHOT.jar
curl http://localhost:9080/disponibilidade
curl "http://localhost:9080/modelos?situacao=ATIVO"
```

Se o `.env` tiver fim de linha do Windows (CRLF), use `. <(tr -d '\r' < ../../.env)` no lugar do `. ../../.env`.

### Variáveis

| Variável | Obrigatória | Uso |
|---|---|---|
| `DB_NAME` | sim | nome do banco |
| `DB_CATALOGO_LEITURA_PASSWORD` | sim | senha da role `catalogo_leitura` (a aplicação conecta só com ela) |
| `DB_HOST` | não (`localhost`) | host do banco |
| `DB_PORT` | não (`5432`) | porta do banco |
| `SERVER_PORT` | não (`9080`) | porta da API |

Variável obrigatória ausente derruba a subida com mensagem que **nomeia a variável**, sem imprimir valores.

> **Porta 9080:** em algumas máquinas Windows a 8080 cai numa faixa reservada pelo sistema (Hyper-V/WSL) e o
> bind falha sem processo dono (`netsh int ipv4 show excludedportrange protocol=tcp`). Use `SERVER_PORT` para trocar.

## Somente leitura, em duas camadas

1. **Role do banco:** `catalogo_leitura` só tem `SELECT`; `INSERT`/`UPDATE`/`DELETE` falham com `42501`.
2. **Conexão:** pool com `read-only` e `readOnlyMode=always` (sessão `transaction_read_only = on`); o adaptador
   ainda abre cada consulta numa transação `readOnly`.

Não existe rota de escrita (405 para `POST`/`PUT`/`PATCH`/`DELETE`).

## Limites e proteções

| Recurso | Limite | Ao estourar |
|---|---|---|
| Pool HikariCP | 10 conexões por instância (somar réplicas × 10 contra o `max_connections` do banco); espera de 2 s por conexão | 503 + `Retry-After` |
| Consulta | `query-timeout` de 5 s | 503; a conexão volta ao pool |
| `size` | máximo 100 | 400 |

Sem fila, retry interno ou cache: a leitura é idempotente e barata; o cliente decide se repete, guiado pelo
`Retry-After`. A listagem usa offset (`count(*)` + `LIMIT/OFFSET`); se o catálogo crescer a ponto de o `count` ou o
`OFFSET` passarem do orçamento medido, rever (cursor ou índice `(id_modelo, versao DESC)`).

## Estrutura

```
br.com.srportto.gestaocomprovantesquery
├── domain/          modelos puros (records), tipos validados (ConsultaModelos, ChaveModelo, PageRequest),
│                    portas port/in (casos de uso) e port/out (CatalogoModelos), exceções de domínio
├── application/     ListarModelosService, DetalharModeloService (sem anotação de framework)
└── infrastructure/
    ├── web/         ModelosController, DisponibilidadeController, ApiExceptionHandler (RFC 9457)
    ├── persistence/ CatalogoModelosJdbc (JdbcClient; lista em catalogo.modelo, detalhe em vw_modelo_completo)
    └── config/      BeansConfig, VerificaConfiguracaoBanco
```

`domain` e `application` não importam Spring nem Jackson. Os parâmetros chegam como texto e são validados pelo
domínio (400 com todos os erros juntos, antes de qualquer consulta ao banco).

## Testes

```bash
mvn clean verify
```

Os testes de integração usam **Testcontainers** com a imagem real do catálogo e as migrations de
`infra/local/postgres/migrations` (mesmo seed e mesma role de leitura do ambiente local). A imagem precisa existir
no Docker local; se faltar, o teste falha dizendo como construí-la:

```bash
cd infra/local/postgres && docker compose --env-file ../../../.env -f postgres-db-v18.yml build
```

| Grupo | O que prova |
|---|---|
| `domain/*`, `application/*` | invariantes, valores padrão, acúmulo de erros, `Pagination`, casos de uso com a porta simulada |
| `CatalogoModelosJdbcTest` | listagem (filtros, ordem, paginação) e detalhe sobre o seed real; contagem de campos igual à da view |
| `SomenteLeituraTest` | role rejeita escrita (`42501`), conexão read-only, pool/timeouts, subida sem senha |
| `ModelosApiTest` | todos os cenários da API de ponta a ponta, **cada resposta validada contra o `openapi.yaml`** |
| `BancoForaDoArTest`, `ConsultaLentaTest`, `PoolEsgotadoTest`, `ErroInesperadoTest` | 503 (banco fora, consulta travada por `LOCK`, pool esgotado), 500 sem vazamento |
| `ContratoOpenApiTest` | o validador do contrato aceita corpo válido (inclusive `["integer","null"]`) e rejeita o inválido |

## Coleção Bruno

Abra `docs/contratos-rest/gestao-comprovantesquery/bruno` no [Bruno](https://www.usebruno.com/), escolha o ambiente
`local` (`baseUrl` = `http://localhost:9080`) e execute a pasta `modelos`. Com a API de pé, via CLI:
`cd docs/contratos-rest/gestao-comprovantesquery/bruno && bru run modelos --env local`.
