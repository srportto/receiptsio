package br.com.srportto.gestaocomprovantesquery.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.domain.exception.ParametrosInvalidosException;
import br.com.srportto.gestaocomprovantesquery.domain.model.ConsultaModelos;
import br.com.srportto.gestaocomprovantesquery.domain.model.ErroParametro;
import br.com.srportto.gestaocomprovantesquery.domain.model.Situacao;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** Invariantes da consulta de listagem: valores padrão, limites e acúmulo de todos os erros. */
class ConsultaModelosTest {

    private static List<String> parametrosComErro(ParametrosInvalidosException erro) {
        return erro.erros().stream().map(ErroParametro::parametro).toList();
    }

    @Test
    @DisplayName("Sem nenhum parâmetro: sem filtros, página 1 e tamanho 20")
    void padroes() {
        var consulta = ConsultaModelos.de(null, null, null, null, null);
        assertNull(consulta.situacao());
        assertNull(consulta.idModelo());
        assertNull(consulta.versao());
        assertEquals(1, consulta.pagina().page());
        assertEquals(20, consulta.pagina().size());
    }

    @Test
    @DisplayName("Parâmetros em branco valem como ausentes")
    void emBranco() {
        var consulta = ConsultaModelos.de("", " ", "", "", "");
        assertNull(consulta.situacao());
        assertNull(consulta.idModelo());
        assertNull(consulta.versao());
        assertEquals(1, consulta.pagina().page());
    }

    @Test
    @DisplayName("Valores válidos são convertidos")
    void validos() {
        var consulta = ConsultaModelos.de("RASCUNHO", "COMPPIX", "2", "3", "100");
        assertEquals(Situacao.RASCUNHO, consulta.situacao());
        assertEquals("COMPPIX", consulta.idModelo());
        assertEquals(2, consulta.versao());
        assertEquals(3, consulta.pagina().page());
        assertEquals(100, consulta.pagina().size());
        assertEquals(200, consulta.pagina().offset());
    }

    @ParameterizedTest
    @ValueSource(strings = {"XYZ", "ativo", "Ativo"})
    @DisplayName("situacao fora do conjunto (inclusive minúscula) é rejeitada")
    void situacaoInvalida(String situacao) {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de(situacao, null, null, null, null));
        assertEquals(List.of("situacao"), parametrosComErro(erro));
    }

    @ParameterizedTest
    @ValueSource(strings = {"comppix", "COMPPIX_LONGO", "COMP-PIX", "COMP PIX"})
    @DisplayName("idModelo fora de ^[A-Z0-9_]{1,10}$ é rejeitado")
    void idModeloInvalido(String id) {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de(null, id, null, null, null));
        assertEquals(List.of("idModelo"), parametrosComErro(erro));
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "1000", "-1", "abc", "1.5"})
    @DisplayName("versao fora de 1 a 999 ou não inteira é rejeitada")
    void versaoInvalida(String versao) {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de(null, null, versao, null, null));
        assertEquals(List.of("versao"), parametrosComErro(erro));
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-3", "x", "99999999999999999999"})
    @DisplayName("page menor que 1 ou não inteiro é rejeitado")
    void pageInvalida(String page) {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de(null, null, null, page, null));
        assertEquals(List.of("page"), parametrosComErro(erro));
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "101", "500", "-1", "x"})
    @DisplayName("size fora de 1 a 100 é rejeitado")
    void sizeInvalido(String size) {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de(null, null, null, null, size));
        assertEquals(List.of("size"), parametrosComErro(erro));
    }

    @Test
    @DisplayName("Todos os erros de uma requisição vêm juntos, na ordem dos parâmetros")
    void variosErros() {
        var erro = assertThrows(ParametrosInvalidosException.class,
                () -> ConsultaModelos.de("XYZ", "abc", "0", "0", "500"));
        assertEquals(List.of("situacao", "idModelo", "versao", "page", "size"), parametrosComErro(erro));
        assertTrue(erro.erros().stream().noneMatch(e -> e.mensagem().isBlank()));
    }

    @Test
    @DisplayName("Limites exatos são aceitos")
    void limites() {
        var consulta = ConsultaModelos.de(null, "A", "999", "1", "1");
        assertEquals(999, consulta.versao());
        assertEquals(0, consulta.pagina().offset());
        assertEquals(1, ConsultaModelos.de(null, "0123456789", "1", "1", "1").versao());
    }
}
