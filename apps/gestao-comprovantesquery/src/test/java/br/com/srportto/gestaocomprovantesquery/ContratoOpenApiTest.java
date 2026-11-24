package br.com.srportto.gestaocomprovantesquery;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Spike do teste de contrato: prova que o validador entende o OpenAPI 3.1 do contrato, aceita corpo válido
 * (inclusive tipo {@code ["integer","null"]}) e rejeita corpo inválido pelo motivo certo.
 */
class ContratoOpenApiTest {

    private static final String RESUMO = "{\"idModelo\":\"COMPPIX\",\"versao\":2,\"descricao\":\"PIX\","
            + "\"situacao\":\"ATIVO\",\"dataHoraAtualizacao\":\"2026-11-22T15:00:00-03:00\"}";

    private static String pagina(String resumo) {
        return "{\"items\":[" + resumo + "],\"pagination\":{\"page\":1,\"size\":20,\"totalElements\":1,\"totalPages\":1}}";
    }

    @Test
    @DisplayName("Corpo válido de PaginaModelos passa")
    void paginaValida() {
        assertEquals(List.of(), ContratoOpenApi.validar("PaginaModelos", pagina(RESUMO)));
    }

    @Test
    @DisplayName("Página vazia também cumpre o contrato")
    void paginaVazia() {
        var corpo = "{\"items\":[],\"pagination\":{\"page\":1,\"size\":20,\"totalElements\":0,\"totalPages\":0}}";
        assertEquals(List.of(), ContratoOpenApi.validar("PaginaModelos", corpo));
    }

    @Test
    @DisplayName("Campo obrigatório faltando é rejeitado")
    void campoFaltando() {
        var semSituacao = RESUMO.replace("\"situacao\":\"ATIVO\",", "");
        var erros = ContratoOpenApi.validar("PaginaModelos", pagina(semSituacao));
        assertFalse(erros.isEmpty());
        assertTrue(erros.stream().anyMatch(e -> e.contains("situacao")), erros.toString());
    }

    @Test
    @DisplayName("situacao fora do enum é rejeitada")
    void enumInvalido() {
        var erros = ContratoOpenApi.validar("PaginaModelos", pagina(RESUMO.replace("ATIVO", "XYZ")));
        assertFalse(erros.isEmpty());
    }

    @Test
    @DisplayName("Tipo errado é rejeitado (versao como texto)")
    void tipoErrado() {
        var erros = ContratoOpenApi.validar("PaginaModelos", pagina(RESUMO.replace("\"versao\":2", "\"versao\":\"2\"")));
        assertFalse(erros.isEmpty());
    }

    @Test
    @DisplayName("Campo estrutural aceita posicaoIndexador nulo (tipo [integer, null]) e rejeita texto")
    void tipoNuloOpenApi31() {
        var campo = "{\"idCampo\":1,\"nomeCampo\":\"valor\",\"tipoDado\":\"DECIMAL\",\"ordem\":1,"
                + "\"aceitaNuloVazio\":false,\"posicaoIndexador\":%s,\"descricaoCampoTemplate\":null,"
                + "\"descricaoBase\":\"Valor\",\"descricaoEfetiva\":\"Valor\"}";
        assertEquals(List.of(), ContratoOpenApi.validar("CampoEstrutural", campo.formatted("null")));
        assertEquals(List.of(), ContratoOpenApi.validar("CampoEstrutural", campo.formatted("3")));
        assertFalse(ContratoOpenApi.validar("CampoEstrutural", campo.formatted("\"x\"")).isEmpty());
    }

    @Test
    @DisplayName("ProblemDetails com errors[] cumpre o contrato; sem status é rejeitado")
    void problemDetails() {
        var valido = "{\"type\":\"about:blank\",\"title\":\"Requisição inválida\",\"status\":400,"
                + "\"errors\":[{\"parametro\":\"size\",\"mensagem\":\"deve ser no máximo 100\"}]}";
        assertEquals(List.of(), ContratoOpenApi.validar("ProblemDetails", valido));
        assertFalse(ContratoOpenApi.validar("ProblemDetails", "{\"type\":\"about:blank\",\"title\":\"x\"}").isEmpty());
    }
}
