> **Delegação** (skill `openspec-catalogo-java`, linha "apply — SQL e banco"): agent `especialista-banco-dados`, skill `banco-de-dados-performance`.
>
> **Comandos**: executados em `infra/local/postgres/`. Atalhos usados abaixo:
> - `$UP` = `docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d --build`
> - `$DOWN` = `docker compose --env-file ../../../.env -f postgres-db-v18.yml down -v`
> - `$VER` = `docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U docker -d db-receiptsio < verificar-catalogo.sql; echo "saida=$?"`
>
> **Prova** = comando executado, com saída e código de saída lidos e anotados na tarefa. Marcar `[x]` sem isso não vale. Foi assim que a change anterior foi arquivada com um banco que não subia.
>
> Sem código Java nesta change, portanto sem portão do `java-revisor`.

## 1. Pré-condições

- [x] 1.1 Confirmar que o volume `receiptsio_pg_data` e o container `postgres18-receiptsio` não existem (`docker volume ls`, `docker ps -a`). Confirmar também que o `.env` da raiz define `DB_PASSWORD`, `DB_CATALOGO_LEITURA_PASSWORD` e `DB_CATALOGO_ESCRITA_PASSWORD`, conferindo só os nomes, sem imprimir valores, e que a porta `DB_PORT` está livre. Prova: saídas lidas.

## 2. Verificação primeiro (RED)

- [x] 2.1 Reescrever `verificar-catalogo.sql` conforme D9:
  - funções `pg_temp.esperar_erro` (SQLSTATE exato) e `pg_temp.esperar_sucesso`;
  - dados com prefixo `VER_`;
  - um cenário por scenario das delta specs, exceto concorrência e seed;
  - checagem de catálogo: nenhuma coluna `version`, `data_version` só nas 4 tabelas, nenhum trigger de auditoria, nenhum `UPDATE` de `catalogo_escrita` em `data_hora_criacao`;
  - `\gset` + `\if :tem_falha` → erro SQL deliberado com `ON_ERROR_STOP` (código de saída 3; o `\q` do psql não aceita código).

  Comentários em português.
- [x] 2.2 Criar `verificar-concorrencia.sh` conforme D9: dois sentidos, prefixo `CONC_`, limpeza com `session_replication_role = replica`, código ≠ 0 na corrida.
- [x] 2.3 Prova RED: subir as migrations **atuais** num container descartável (nome e porta próprios, sem volume) com só B1 e B2 corrigidos, rodar os dois scripts e anotar quais cenários falham (esperado: I1–I4, datas/privilégio, `data_version`, descrições, view, duplicação). Remover o container. Prova: lista de `FALHA` e `saida=1` dos dois scripts.

## 3. Migrations (GREEN)

- [x] 3.1 `v1.0.00`:
  - remover `fn_atualiza_data_hora`;
  - `ALTER DATABASE` via `current_database()` (D7);
  - manter extensões, schema e `search_path`.
- [x] 3.2 `v1.0.01` (`campo`):
  - remover a `UNIQUE` com expressão (B1);
  - `version` → `data_version`;
  - remover o trigger de data;
  - comentários de colunas atualizados (contrato de `data_hora_atualizacao`).
- [x] 3.3 `v1.0.02` (`template_estrutural` e associação):
  - `nome_template` com CHECK de não vazio e `descricao` opcional;
  - `data_version`;
  - associação com `descricao_campo_template` e datas;
  - remover índice redundante e trigger de data.
- [x] 3.4 `v1.0.03` (`template_variavel` e associação): os mesmos ajustes do 3.3, sem indexador; comentário de `aceita_nulo_vazio` alinhado ao padrão `false` (D8).
- [x] 3.5 `v1.0.04` (`modelo`): `data_version`, remover trigger de data, comentários; criar `catalogo.vw_modelo_completo` (D6).
- [x] 3.6 `v1.0.05`, triggers de imutabilidade (D4):
  - `fn_modelo_imutavel` em `BEFORE INSERT OR UPDATE`, com a tabela de transições, congelamento de `id_modelo`/`versao`/`descricao`/templates e "validar publicação" (locks `FOR UPDATE` nos templates e `FOR SHARE` nos campos, antes da checagem do indexador 1);
  - associações com `FOR SHARE` no template e checagem de `OLD` e `NEW`;
  - novo `fn_campo_imutavel`;
  - mensagens nomeando modelo, template ou campo.
- [x] 3.7 `v1.0.06` (roles):
  - `run_sql` repassa os argumentos (B2);
  - `$POSTGRES_USER`/`$POSTGRES_DB` (D7);
  - `catalogo_escrita` com `SELECT/INSERT/DELETE` e `UPDATE` coluna a coluna, tabela a tabela, sem `data_hora_criacao` (D3);
  - `catalogo_leitura` com `SELECT` (inclui a view).
- [x] 3.8 `v1.0.07`: seed de inspeção conforme D10, com templates populados antes dos modelos publicados e associações com e sem `descricao_campo_template`.
- [x] 3.9 Prova GREEN: `$DOWN` e `$UP`; aguardar `healthy` (`docker inspect -f '{{.State.Health.Status}}' postgres18-receiptsio`); `docker logs postgres18-receiptsio 2>&1 | grep -c ERROR` igual a 0; `$VER` com todos `OK` e `saida=0`; `./verificar-concorrencia.sh` com `OK` nos dois sentidos e saída 0.

## 4. Provas negativas e de ambiente

- [x] 4.1 Regra quebrada no verificador: numa sessão manual, `ALTER TABLE catalogo.campo DROP CONSTRAINT <check de tipo_dado>`, rodar `$VER` e anotar o cenário `FALHA` e `saida=1`. Depois `$DOWN` + `$UP`.
- [x] 4.2 Corrida sem proteção: numa sessão manual, recriar `fn_modelo_imutavel` sem os locks, rodar `verificar-concorrencia.sh` e anotar `FALHA` e saída ≠ 0. Depois `$DOWN` + `$UP`.
- [x] 4.3 Banco com outro nome: container descartável com `POSTGRES_DB=db-outro-nome` e `POSTGRES_USER=outro`; o log não pode ter `ERROR` e `SHOW timezone` em `db-outro-nome` deve dar `America/Sao_Paulo`. Remover o container. Prova: saídas lidas.
- [x] 4.4 Seed: `SELECT id_modelo, versao, situacao FROM catalogo.modelo ORDER BY 1, 2` mostra as 6 versões de D10. `UPDATE catalogo.modelo SET situacao = 'ATIVO' WHERE id_modelo = 'COMPBOL' AND versao = 2` é rejeitado com a mensagem do template. Para cada linha de `vw_modelo_completo`, o tamanho das listas é igual às contagens das associações. Prova: saídas lidas.

## 5. Documentação

- [x] 5.1 Atualizar `exemplos-queries.sql`:
  - usar a `vw_modelo_completo`;
  - consulta de versão vigente;
  - exemplos dos cenários do seed (rascunho editável, Boleto v2 bloqueado, `UPDATE` com `data_hora_atualizacao = now()` e `data_version + 1` como a aplicação fará).

  Prova: arquivo executado com `psql -v ON_ERROR_STOP=1`, envolto em `BEGIN; … ROLLBACK;` para não deixar alteração no banco.
- [x] 5.2 Atualizar `README.md`:
  - tabelas e colunas novas;
  - `data_version`;
  - ausência de trigger de auditoria e contrato da aplicação;
  - regras de imutabilidade corrigidas;
  - privilégio de coluna;
  - view;
  - seed de inspeção;
  - os dois verificadores;
  - corrigir a contagem de campos do seed.

  Prova: cada comando do README executado conforme escrito.
- [x] 5.3 Atualizar `info_pra_run_v18.txt` com o verificador de concorrência e as consultas de inspeção do seed.
- [x] 5.4 Reescrever `explicacao.md` para o estado pós-change:
  - diagramas Mermaid atualizados (ER com as colunas novas, ciclo de vida com `RASCUNHO → INATIVO` rejeitado, sequência de locks);
  - aderência a `docs/` refeita;
  - histórico dos achados de 2026-11-22 com o status "corrigido", apontando a prova.
- [x] 5.5 Validar a change: `openspec validate corrigir-catalogo-modelos-comprovante --strict`. Deixar o ambiente rodando com o seed para inspeção do dono do produto e informar como conectar.
