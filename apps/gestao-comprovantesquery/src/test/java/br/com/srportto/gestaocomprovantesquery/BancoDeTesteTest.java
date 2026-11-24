package br.com.srportto.gestaocomprovantesquery;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.sql.SQLException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Fumaça do banco de teste: as migrations e o seed foram aplicados e a role de leitura enxerga o catálogo. */
class BancoDeTesteTest {

    @Test
    @DisplayName("A role catalogo_leitura lê o seed: 6 modelos, 3 ATIVOS, 29 campos")
    void seedVisivelPelaRoleDeLeitura() throws SQLException {
        try (var conexao = BancoDeTeste.conexaoLeitura(); var st = conexao.createStatement()) {
            assertEquals(6, contar(st, "SELECT count(*) FROM catalogo.modelo"));
            assertEquals(3, contar(st, "SELECT count(*) FROM catalogo.modelo WHERE situacao = 'ATIVO'"));
            assertEquals(29, contar(st, "SELECT count(*) FROM catalogo.campo"));
            assertEquals(6, contar(st, "SELECT count(*) FROM catalogo.vw_modelo_completo"));
        }
    }

    private static int contar(java.sql.Statement st, String sql) throws SQLException {
        try (var rs = st.executeQuery(sql)) {
            rs.next();
            return rs.getInt(1);
        }
    }
}
