package br.com.srportto.gestaocomprovantesquery.infrastructure.persistence;

import br.com.srportto.gestaocomprovantesquery.domain.exception.CatalogoIndisponivelException;
import br.com.srportto.gestaocomprovantesquery.domain.model.CampoEstrutural;
import br.com.srportto.gestaocomprovantesquery.domain.model.CampoVariavel;
import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import br.com.srportto.gestaocomprovantesquery.domain.model.Situacao;
import br.com.srportto.gestaocomprovantesquery.domain.model.TemplateEstrutural;
import br.com.srportto.gestaocomprovantesquery.domain.model.TemplateVariavel;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.TransientDataAccessException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionException;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.PropertyNamingStrategies;
import tools.jackson.databind.json.JsonMapper;

/**
 * Adaptador de saída: lê o catálogo no PostgreSQL com SQL explícito, sempre em transação somente leitura.
 *
 * <ul>
 *   <li>Listagem: {@code catalogo.modelo}, filtros opcionais com a forma do SQL fixa (todo valor é parâmetro) e
 *       {@code count(*)} com o mesmo filtro, na mesma transação.</li>
 *   <li>Detalhe: {@code catalogo.vw_modelo_completo}, que já entrega os campos ordenados e sem duplicação.</li>
 * </ul>
 *
 * <p>Banco fora do ar, pool esgotado e consulta acima do tempo limite viram {@link CatalogoIndisponivelException}.
 */
@Repository
public class CatalogoModelosJdbc implements CatalogoModelos {

    private static final String FILTRO = """
            WHERE (CAST(:situacao AS text) IS NULL OR situacao = :situacao)
              AND (CAST(:idModelo AS text) IS NULL OR id_modelo = :idModelo)
              AND (CAST(:versao AS integer) IS NULL OR versao = :versao)
            """;

    private static final String SQL_PAGINA = """
            SELECT id_modelo, versao, descricao, situacao, data_hora_atualizacao
              FROM catalogo.modelo
            """ + FILTRO + """
             ORDER BY id_modelo, versao DESC
             LIMIT :limite OFFSET :deslocamento
            """;

    private static final String SQL_TOTAL = "SELECT count(*) FROM catalogo.modelo " + FILTRO;

    private static final String SQL_DETALHE = """
            SELECT v.id_modelo, v.versao, v.descricao, v.situacao,
                   m.data_hora_criacao, m.data_hora_atualizacao,
                   v.id_template_estrutural, v.nome_template_estrutural,
                   v.id_template_variavel, v.nome_template_variavel,
                   v.campos_estruturais::text AS campos_estruturais,
                   v.campos_variaveis::text AS campos_variaveis
              FROM catalogo.vw_modelo_completo v
              JOIN catalogo.modelo m ON m.id_modelo = v.id_modelo AND m.versao = v.versao
             WHERE v.id_modelo = :idModelo AND v.versao = :versao
            """;

    /** O jsonb da view usa snake_case e pode ganhar campos novos sem quebrar a leitura. */
    private static final JsonMapper JSON = JsonMapper.builder()
            .propertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE)
            .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .build();

    private final JdbcClient jdbc;
    private final TransactionTemplate leitura;

    public CatalogoModelosJdbc(JdbcClient jdbc, PlatformTransactionManager transacoes) {
        this.jdbc = jdbc;
        this.leitura = new TransactionTemplate(transacoes);
        this.leitura.setReadOnly(true);
    }

    @Override
    public Pagina<ModeloResumo> listar(ConsultaModelos consulta) {
        return executar(() -> leitura.execute(status -> {
            var pedido = consulta.pagina();
            String situacao = consulta.situacao() == null ? null : consulta.situacao().name();

            List<ModeloResumo> itens = jdbc.sql(SQL_PAGINA)
                    .param("situacao", situacao)
                    .param("idModelo", consulta.idModelo())
                    .param("versao", consulta.versao())
                    .param("limite", pedido.size())
                    .param("deslocamento", pedido.offset())
                    .query((rs, linha) -> new ModeloResumo(
                            rs.getString("id_modelo"),
                            rs.getInt("versao"),
                            rs.getString("descricao"),
                            Situacao.valueOf(rs.getString("situacao")),
                            rs.getObject("data_hora_atualizacao", OffsetDateTime.class)))
                    .list();

            long total = jdbc.sql(SQL_TOTAL)
                    .param("situacao", situacao)
                    .param("idModelo", consulta.idModelo())
                    .param("versao", consulta.versao())
                    .query(Long.class)
                    .single();

            return Pagina.de(itens, pedido, total);
        }));
    }

    @Override
    public Optional<ModeloDetalhe> buscar(ChaveModelo chave) {
        return executar(() -> leitura.execute(status -> jdbc.sql(SQL_DETALHE)
                .param("idModelo", chave.idModelo())
                .param("versao", chave.versao())
                .query((rs, linha) -> new ModeloDetalhe(
                        rs.getString("id_modelo"),
                        rs.getInt("versao"),
                        rs.getString("descricao"),
                        Situacao.valueOf(rs.getString("situacao")),
                        rs.getObject("data_hora_criacao", OffsetDateTime.class),
                        rs.getObject("data_hora_atualizacao", OffsetDateTime.class),
                        new TemplateEstrutural(
                                rs.getObject("id_template_estrutural", UUID.class),
                                rs.getString("nome_template_estrutural"),
                                lerCampos(rs.getString("campos_estruturais"), CampoEstrutural.class)),
                        new TemplateVariavel(
                                rs.getObject("id_template_variavel", UUID.class),
                                rs.getString("nome_template_variavel"),
                                lerCampos(rs.getString("campos_variaveis"), CampoVariavel.class))))
                .optional()));
    }

    private static <T> List<T> lerCampos(String json, Class<T> tipo) {
        return List.copyOf(JSON.readerForListOf(tipo).readValue(json));
    }

    /**
     * Traduz falha de disponibilidade (conexão, pool, tempo limite) em exceção de domínio; erro de SQL ou de dado
     * segue como está e vira 500 na borda.
     */
    private static <T> T executar(Supplier<T> consulta) {
        try {
            return consulta.get();
        } catch (TransientDataAccessException | DataAccessResourceFailureException | TransactionException e) {
            throw new CatalogoIndisponivelException(e);
        }
    }
}
