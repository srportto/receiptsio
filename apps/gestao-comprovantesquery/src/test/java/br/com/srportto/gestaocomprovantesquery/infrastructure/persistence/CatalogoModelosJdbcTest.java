package br.com.srportto.gestaocomprovantesquery.infrastructure.persistence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.BancoDeTeste;
import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloResumo;
import br.com.srportto.gestaocomprovantesquery.domain.model.Situacao;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;
import java.sql.SQLException;
import java.util.List;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Adaptador JDBC contra o PostgreSQL real (imagem do catálogo + migrations + seed), com a role de leitura.
 *
 * <p>Seed: COMPPIX v1 INATIVO / v2 ATIVO / v3 RASCUNHO; COMPTED v1 ATIVO; COMPBOL v1 ATIVO / v2 RASCUNHO.
 * Ordem fixa da listagem: idModelo crescente, versao decrescente.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class CatalogoModelosJdbcTest {

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        BancoDeTeste.registrar(registro);
    }

    @Autowired
    CatalogoModelos catalogo;

    private static String chaves(List<ModeloResumo> itens) {
        return itens.stream().map(m -> m.idModelo() + ":" + m.versao()).collect(Collectors.joining(","));
    }

    private List<ModeloResumo> listar(String situacao, String idModelo, String versao) {
        return catalogo.listar(ConsultaModelos.de(situacao, idModelo, versao, null, null)).items();
    }

    @Test
    @DisplayName("Sem filtro: todos os 6 modelos, de qualquer situação, na ordem fixa")
    void semFiltro() {
        var pagina = catalogo.listar(ConsultaModelos.de(null, null, null, null, null));
        assertEquals("COMPBOL:2,COMPBOL:1,COMPPIX:3,COMPPIX:2,COMPPIX:1,COMPTED:1", chaves(pagina.items()));
        assertEquals(6, pagina.pagination().totalElements());
        assertEquals(1, pagina.pagination().totalPages());
    }

    @Test
    @DisplayName("situacao=ATIVO devolve só os 3 ativos")
    void ativos() {
        assertEquals("COMPBOL:1,COMPPIX:2,COMPTED:1", chaves(listar("ATIVO", null, null)));
    }

    @Test
    @DisplayName("situacao=RASCUNHO devolve só os 2 rascunhos")
    void rascunhos() {
        assertEquals("COMPBOL:2,COMPPIX:3", chaves(listar("RASCUNHO", null, null)));
    }

    @Test
    @DisplayName("situacao=INATIVO devolve só a versão retirada")
    void inativos() {
        assertEquals("COMPPIX:1", chaves(listar("INATIVO", null, null)));
    }

    @Test
    @DisplayName("idModelo sem versão devolve todas as versões, da maior para a menor")
    void porModelo() {
        assertEquals("COMPPIX:3,COMPPIX:2,COMPPIX:1", chaves(listar(null, "COMPPIX", null)));
    }

    @Test
    @DisplayName("idModelo e versao identificam um único modelo")
    void porModeloEVersao() {
        var itens = listar(null, "COMPPIX", "2");
        assertEquals("COMPPIX:2", chaves(itens));
        assertEquals(Situacao.ATIVO, itens.getFirst().situacao());
        assertEquals("Comprovante de Pagamento PIX (v2, vigente)", itens.getFirst().descricao());
        assertTrue(itens.getFirst().dataHoraAtualizacao() != null);
    }

    @Test
    @DisplayName("Filtros combinam por E lógico")
    void combinados() {
        assertEquals("COMPBOL:2", chaves(listar("RASCUNHO", "COMPBOL", null)));
        assertEquals("", chaves(listar("ATIVO", "COMPBOL", "2")));
    }

    @Test
    @DisplayName("Sem resultado: items vazio, total 0 e totalPages 0")
    void semResultado() {
        var pagina = catalogo.listar(ConsultaModelos.de(null, "COMPPIX", "999", null, null));
        assertTrue(pagina.items().isEmpty());
        assertEquals(0, pagina.pagination().totalElements());
        assertEquals(0, pagina.pagination().totalPages());
    }

    @Test
    @DisplayName("Paginação: página 2 de size 2 traz o 3º e o 4º; total e totalPages vêm do filtro")
    void paginacao() {
        var pagina = catalogo.listar(ConsultaModelos.de(null, null, null, "2", "2"));
        assertEquals("COMPPIX:3,COMPPIX:2", chaves(pagina.items()));
        assertEquals(2, pagina.pagination().page());
        assertEquals(2, pagina.pagination().size());
        assertEquals(6, pagina.pagination().totalElements());
        assertEquals(3, pagina.pagination().totalPages());
    }

    @Test
    @DisplayName("Página além da última: items vazio e total real")
    void alemDaUltima() {
        var pagina = catalogo.listar(ConsultaModelos.de(null, null, null, "99", "20"));
        assertTrue(pagina.items().isEmpty());
        assertEquals(6, pagina.pagination().totalElements());
        assertEquals(1, pagina.pagination().totalPages());
    }

    @Test
    @DisplayName("Detalhe de COMPTED v1: 5 indexadores, de 1 a 5, e campos ordenados")
    void detalheComIndexadores() {
        var detalhe = catalogo.buscar(ChaveModelo.de("COMPTED", "1")).orElseThrow();
        assertEquals(Situacao.ATIVO, detalhe.situacao());
        var posicoes = detalhe.templateEstrutural().campos().stream()
                .filter(c -> c.posicaoIndexador() != null)
                .map(c -> c.posicaoIndexador()).sorted().toList();
        assertEquals(List.of(1, 2, 3, 4, 5), posicoes);
        var ordens = detalhe.templateEstrutural().campos().stream().map(c -> c.ordem()).toList();
        assertEquals(ordens.stream().sorted().toList(), ordens);
        assertEquals("Estrutura TED v1", detalhe.templateEstrutural().nome());
        assertEquals("Variáveis TED v1", detalhe.templateVariavel().nome());
    }

    @Test
    @DisplayName("Detalhe de rascunho COMPBOL v2: nenhum campo com indexador 1")
    void detalheRascunhoSemIndexadorUm() {
        var detalhe = catalogo.buscar(ChaveModelo.de("COMPBOL", "2")).orElseThrow();
        assertEquals(Situacao.RASCUNHO, detalhe.situacao());
        assertTrue(detalhe.templateEstrutural().campos().stream()
                .noneMatch(c -> Integer.valueOf(1).equals(c.posicaoIndexador())));
    }

    @Test
    @DisplayName("Descrição efetiva é a do campo no template, ou a base quando aquela é nula")
    void descricaoEfetiva() {
        var detalhe = catalogo.buscar(ChaveModelo.de("COMPPIX", "2")).orElseThrow();
        var todos = detalhe.templateEstrutural().campos();
        assertFalse(todos.isEmpty());
        for (var campo : todos) {
            var esperada = campo.descricaoCampoTemplate() != null ? campo.descricaoCampoTemplate() : campo.descricaoBase();
            assertEquals(esperada, campo.descricaoEfetiva(), campo.nomeCampo());
        }
        assertTrue(todos.stream().anyMatch(c -> c.descricaoCampoTemplate() == null), "há campo sem descrição própria");
    }

    @Test
    @DisplayName("Quantidade de campos de cada modelo bate com a da view (sem produto cartesiano)")
    void contagemBateComAView() throws SQLException {
        try (var conexao = BancoDeTeste.conexaoAdmin();
                var st = conexao.createStatement();
                var rs = st.executeQuery("SELECT id_modelo, versao, jsonb_array_length(campos_estruturais) AS e, "
                        + "jsonb_array_length(campos_variaveis) AS v FROM catalogo.vw_modelo_completo")) {
            int verificados = 0;
            while (rs.next()) {
                var chave = ChaveModelo.de(rs.getString("id_modelo"), String.valueOf(rs.getInt("versao")));
                var detalhe = catalogo.buscar(chave).orElseThrow();
                assertEquals(rs.getInt("e"), detalhe.templateEstrutural().campos().size(), chave.toString());
                assertEquals(rs.getInt("v"), detalhe.templateVariavel().campos().size(), chave.toString());
                verificados++;
            }
            assertEquals(6, verificados);
        }
    }

    @Test
    @DisplayName("Detalhe de chave inexistente devolve vazio")
    void inexistente() {
        assertTrue(catalogo.buscar(ChaveModelo.de("COMPPIX", "999")).isEmpty());
    }
}
