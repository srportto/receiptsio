package br.com.srportto.gestaocomprovantesquery.infrastructure.persistence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.BancoDeTeste;
import br.com.srportto.gestaocomprovantesquery.GestaoComprovantesqueryApplication;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.SQLException;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Somente leitura em duas camadas (role do banco e conexão read-only) e a configuração do pool e dos tempos
 * limite (design D7 e D8).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class SomenteLeituraTest {

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        BancoDeTeste.registrar(registro);
    }

    @Autowired
    DataSource dataSource;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private static final String INSERT = "INSERT INTO catalogo.modelo (id_modelo, versao, descricao, situacao, "
            + "id_template_estrutural, id_template_variavel) SELECT 'ZZTESTE', 1, 'x', 'RASCUNHO', "
            + "id_template_estrutural, id_template_variavel FROM catalogo.modelo LIMIT 1";
    private static final String UPDATE = "UPDATE catalogo.modelo SET descricao = 'alterada'";
    private static final String DELETE = "DELETE FROM catalogo.modelo";

    private static String sqlState(String sql, java.sql.Connection conexao) {
        var erro = assertThrows(SQLException.class, () -> {
            try (var st = conexao.createStatement()) {
                st.executeUpdate(sql);
            }
        });
        return erro.getSQLState();
    }

    @Test
    @DisplayName("A role catalogo_leitura rejeita INSERT, UPDATE e DELETE com insufficient_privilege (42501)")
    void roleRejeitaEscrita() throws SQLException {
        try (var conexao = BancoDeTeste.conexaoLeitura()) {
            assertEquals("42501", sqlState(INSERT, conexao));
            assertEquals("42501", sqlState(UPDATE, conexao));
            assertEquals("42501", sqlState(DELETE, conexao));
        }
    }

    @Test
    @DisplayName("A conexão da aplicação é somente leitura no banco (transaction_read_only = on) e rejeita escrita")
    void conexaoDaAplicacaoEReadOnly() throws SQLException {
        try (var conexao = dataSource.getConnection()) {
            assertTrue(conexao.isReadOnly());
            try (var st = conexao.createStatement(); var rs = st.executeQuery("SHOW transaction_read_only")) {
                rs.next();
                assertEquals("on", rs.getString(1));
            }
            // O Postgres checa o privilégio antes da transação read-only: com a role de leitura o erro é 42501.
            // Qualquer um dos dois estados prova a rejeição; as duas camadas valem de forma independente.
            for (String escrita : List.of(INSERT, UPDATE, DELETE)) {
                assertTrue(List.of("42501", "25006").contains(sqlState(escrita, conexao)), escrita);
            }
        }
    }

    @Test
    @DisplayName("Nada foi alterado no catálogo pelas tentativas de escrita")
    void catalogoIntacto() throws SQLException {
        try (var conexao = BancoDeTeste.conexaoAdmin(); var st = conexao.createStatement();
                var rs = st.executeQuery("SELECT count(*), count(*) FILTER (WHERE descricao = 'alterada') "
                        + "FROM catalogo.modelo")) {
            rs.next();
            assertEquals(6, rs.getInt(1));
            assertEquals(0, rs.getInt(2));
        }
    }

    @Test
    @DisplayName("Pool de no máximo 10 conexões, espera de 2 s por conexão, somente leitura; consulta limitada a 5 s")
    void poolETimeouts() throws SQLException {
        var hikari = dataSource.unwrap(HikariDataSource.class);
        assertEquals(10, hikari.getMaximumPoolSize());
        assertEquals(2000, hikari.getConnectionTimeout());
        assertTrue(hikari.isReadOnly());
        assertEquals("catalogo_leitura", hikari.getUsername());
        assertEquals(5, jdbcTemplate.getQueryTimeout());
    }

    @Test
    @DisplayName("Senha da role ausente derruba a subida nomeando a variável, sem imprimir valores")
    void senhaAusenteFalhaNaSubida() {
        // Ambiente vazio: nem variáveis do SO nem propriedades do sistema, para o teste não depender da máquina
        var semAmbiente = new StandardEnvironment() {
            @Override
            protected void customizePropertySources(MutablePropertySources fontes) {
                // sem systemEnvironment e sem systemProperties
            }
        };
        var erro = assertThrows(Exception.class, () -> new SpringApplicationBuilder(GestaoComprovantesqueryApplication.class)
                .web(WebApplicationType.NONE)
                .environment(semAmbiente)
                .properties("DB_NAME=nome_do_banco_secreto")
                .run());

        var mensagens = new StringBuilder();
        for (Throwable t = erro; t != null; t = t.getCause()) {
            mensagens.append(t.getMessage()).append('\n');
        }
        assertTrue(mensagens.toString().contains("DB_CATALOGO_LEITURA_PASSWORD"), mensagens.toString());
        assertFalse(mensagens.toString().contains("nome_do_banco_secreto"), "a mensagem não deve repetir valores");
    }
}
