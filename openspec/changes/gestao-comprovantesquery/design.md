## Context

O catálogo (`schema catalogo`, PostgreSQL 18) está pronto e provado. Falta uma porta de leitura para a tela web de administração. Não há aplicação Java no repositório (`apps/` vazio). O contrato REST já está escrito em `docs/contratos-rest/gestao-comprovantesquery/` (ver proposta).

Fatos do banco que moldam o desenho:
- `catalogo.modelo` tem PK `(id_modelo, versao)`, índice parcial único para o ATIVO e FKs indexadas.
- `catalogo.vw_modelo_completo` entrega uma linha por modelo, com `campos_estruturais` e `campos_variaveis` em `jsonb`, já ordenados e sem produto cartesiano.
- A role `catalogo_leitura` só tem `SELECT`. Dentro do container a autenticação é `trust`; pela rede exige senha (`DB_CATALOGO_LEITURA_PASSWORD`).
- O banco usa `timestamptz`; o fuso do banco é `America/Sao_Paulo`.

Stakeholders: o administrador (tela web), a camada web/gateway (autenticação, CORS) e o dono do catálogo.

## Goals / Non-Goals

**Goals:**
- Listar (paginado, filtrável) e detalhar modelos com seus campos, qualquer situação.
- Contrato como artefato independente do código, com teste que o impõe.
- Somente leitura garantida no banco, não só na aplicação.
- Operar com catálogo grande sem degradar o banco (paginação com teto, timeouts, pool pequeno).

**Non-Goals:**
- Autenticação, autorização, Spring Security, CORS.
- Escrita, cache, ordenação customizada, paginação por cursor.
- Mudanças em migrations, no seed ou no catálogo.
- Emissão de comprovantes (NoSQL) e carga de cache.

## Decisions

### D1. Hexagonal clássica, três camadas, dois casos de uso
`domain` (`Modelo`, `ModeloResumo`, `Campo*`, `Template*`, `Situacao`, `IdModelo`, `Versao`, `Pagination`, `Pagina<T>`), `application` (casos de uso `ListarModelos` e `DetalharModelo`, porta de saída `CatalogoModelos`, filtro e paginação validados), `infrastructure` (controller REST, adaptador JDBC, tratamento de erros, configuração). Dependência só aponta para dentro. Variante de `criar-aplicacao-java`: REST com banco, sem escrita.
*Alternativa:* camadas clássicas (controller/service/repository). Descartada: o domínio é pequeno, mas o catálogo já usa linguagem de ports/adapters e o custo extra é baixo.

### D2. Persistência com Spring JDBC (`JdbcClient`), não JPA
A aplicação só lê projeções (resumo e detalhe a partir de uma view com `jsonb`). Não há agregado a gravar, nem `@Version`, nem lazy loading. `JdbcClient` com SQL explícito evita N+1, mapeamento da view para entidade e `LazyInitializationException`, e deixa o SQL revisável.
*Alternativa:* Spring Data JPA com projeções. Descartada: traria entidades para um modelo que a aplicação nunca modifica.

### D3. Duas consultas, cada uma na fonte certa
- **Listagem:** `catalogo.modelo` (sem os `jsonb`): `SELECT ... WHERE (:situacao IS NULL OR situacao = :situacao) AND ... ORDER BY id_modelo, versao DESC LIMIT :size OFFSET :offset`, mais `SELECT count(*)` com o mesmo filtro. Todos os valores são parâmetros; a forma do SQL é fixa, sem concatenar entrada. Executadas na mesma transação `readOnly`.
- **Detalhe:** `catalogo.vw_modelo_completo` por `(id_modelo, versao)`. O `jsonb` é lido como texto e convertido em objetos de domínio com Jackson 3; a conversão `snake_case` → camelCase fica no adaptador.
*Alternativa:* montar o detalhe com joins na aplicação. Descartada: duplicaria a regra de descrição efetiva e de ordenação que a view já resolve e que já tem prova no verificador.

### D4. Paginação por offset com teto, objeto `Pagination` próprio
`Pagination` (`page` a partir de 1, `size` 1 a 100, `totalElements`, `totalPages`) é o objeto de resposta; `PageRequest` valida a entrada. `page` além da última devolve lista vazia com 200.
*Alternativa:* cursor/keyset. Descartada pelo dono do produto: a tela precisa de "página N de M". Gatilho de revisão: tempo do `count(*)` ou do `OFFSET` acima do orçamento medido, ou catálogo acima de ~1 milhão de modelos.
*Ressalva:* a ordem `id_modelo ASC, versao DESC` não coincide com a PK `(id_modelo, versao)`; o planejador ordena em memória. Para milhares de linhas é desprezível. Se a medição mostrar custo, a correção é um índice `(id_modelo, versao DESC)` em migration própria, fora desta change.

### D5. Validação na fronteira, antes do banco
Tipos do domínio (`IdModelo`, `Versao`, `Situacao`, `PageRequest`) garantem os invariantes no construtor e acumulam **todos** os erros de uma requisição numa exceção que o tratador converte em 400 com `errors[]`. Sem Bean Validation: as regras já são tipos.
*Alternativa:* `@Valid` no controller. Descartada: espalharia a regra e responderia só ao primeiro erro por padrão.

### D6. Contrato como fonte da verdade, imposto por teste
Nada de `springdoc`/`swagger-annotations`. Um teste de contrato carrega `docs/contratos-rest/.../openapi.yaml` e valida corpo e status das respostas reais contra os schemas dos componentes (`PaginaModelos`, `ModeloDetalhe`, `ProblemDetails`) com um validador de JSON Schema que suporte o draft 2020-12 do OpenAPI 3.1 (tipo `["string","null"]`).
*Alternativa:* validador OpenAPI de requisição/resposta (swagger-request-validator). Risco: suporte parcial ao 3.1. A primeira tarefa é um *spike* que decide a biblioteca; o requisito (resposta válida contra o contrato) não muda.

### D7. Somente leitura em duas camadas
(1) Role `catalogo_leitura` sem privilégio de escrita; (2) conexão `readOnly` no pool. Nenhuma rota de escrita existe (405 para os demais métodos). O teste de integração prova (1) abrindo a conexão da aplicação e tentando `INSERT`/`UPDATE`/`DELETE` (espera `42501`).

### D8. Limites e proteção (contrato de `convencoes`/`resiliencia`)
| Recurso | Limite | Motivo | Ao estourar |
|---|---|---|---|
| Pool Hikari | máx. 10 conexões por instância, `connectionTimeout` 2 s | o catálogo é pequeno; somar réplicas × 10 contra o `max_connections` do banco | 503 + `Retry-After` |
| Consulta | `queryTimeout` 5 s | evitar que uma listagem pesada segure conexão | 503, conexão devolvida |
| `size` | 100 | limitar memória e custo por resposta | 400 |
| Corpo da resposta | no máximo 100 resumos ou 1 detalhe | derivado do teto acima | n/a |

Sem fila, sem retry interno e sem cache: leitura idempotente e barata; o cliente decide se repete (`Retry-After`). Sem circuit breaker: uma única dependência, e o pool com timeout curto já protege a aplicação.

### D9. Erros em RFC 9457 sem vazamento
`@RestControllerAdvice` mapeia: parâmetro inválido → 400 com `errors[]`; modelo ausente → 404; método não suportado → 405; banco indisponível/timeout/pool → 503 com `Retry-After`; resto → 500 genérico, com o detalhe só no log. Nenhuma resposta traz SQL, tabela, stack ou credencial.

### D10. Configuração e subida
Host, porta, nome do banco, usuário e senha vêm do ambiente (mesmo `.env` da raiz: `DB_NAME`, `DB_PORT`, `DB_CATALOGO_LEITURA_PASSWORD`; usuário fixo `catalogo_leitura` por ser nome de role do catálogo). Perfil local aponta para `localhost:${DB_PORT}`. Senha ausente falha na subida nomeando a variável. `GET /disponibilidade` (rota do catálogo) verifica o banco.

### D11. Testes (prova)
Teste de integração com **Testcontainers** sobre a imagem `postgres18-receiptsio-extras-partman_cron_vector:1.0` (as migrations criam `pg_cron`/`pg_partman`/`vector` e exigem `shared_preload_libraries`), montando `infra/local/postgres/migrations` em `docker-entrypoint-initdb.d`, como o compose faz. Isso exercita o seed real e a role real. Testes de unidade para os tipos de domínio e para o caso de uso (porta simulada). A imagem precisa existir localmente (`docker compose ... build`); a ausência vira falha clara do teste, não ignorada.
*Alternativa:* H2/Postgres genérico. Descartada: a view com `jsonb`, as roles e as extensões não seriam provadas.

## Risks / Trade-offs

- **Imagem do banco não construída na máquina de CI/dev** → o teste falha com mensagem que manda construí-la; a tarefa de CI (fora de escopo) fará o build antes.
- **Rascunhos e versões antigas expostos sem autenticação** → aceito: a camada web/gateway autentica; a API é de inspeção, não de cache. Registrado como premissa; não expor a API diretamente à internet.
- **`count(*)` e `OFFSET` crescem com o catálogo** → medir; gatilho de revisão em D4.
- **Biblioteca de validação 3.1** → *spike* inicial (D6).
- **View evolui (novo campo)** → o teste de contrato falha antes de a tela quebrar; o adaptador ignora campos desconhecidos do `jsonb`.
- **Duas consultas na listagem não são um snapshot único** → aceito: leitura administrativa tolera divergência momentânea entre o total e a página.

## Migration Plan

Aplicação nova, sem migração de dados. Subida: banco local de pé (`docker compose`), `.env` preenchido, `mvn spring-boot:run` (perfil local). Rollback: parar a aplicação; nada no banco muda.

## Open Questions

- Nenhuma que bloqueie a implementação. O resultado do *spike* de D6 pode trocar a biblioteca de validação sem alterar contrato ou requisitos.
