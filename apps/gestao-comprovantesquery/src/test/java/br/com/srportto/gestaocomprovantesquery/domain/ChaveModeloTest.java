package br.com.srportto.gestaocomprovantesquery.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import br.com.srportto.gestaocomprovantesquery.domain.exception.ParametrosInvalidosException;
import br.com.srportto.gestaocomprovantesquery.domain.model.ChaveModelo;
import br.com.srportto.gestaocomprovantesquery.domain.model.ErroParametro;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Chave (idModelo, versao) do detalhe: obrigatória e validada junta. */
class ChaveModeloTest {

    @Test
    @DisplayName("Chave válida")
    void valida() {
        var chave = ChaveModelo.de("COMPPIX", "2");
        assertEquals("COMPPIX", chave.idModelo());
        assertEquals(2, chave.versao());
    }

    @Test
    @DisplayName("idModelo e versao inválidos vêm juntos")
    void invalidos() {
        var erro = assertThrows(ParametrosInvalidosException.class, () -> ChaveModelo.de("comppix", "0"));
        assertEquals(List.of("idModelo", "versao"), erro.erros().stream().map(ErroParametro::parametro).toList());
    }

    @Test
    @DisplayName("Ausente ou em branco é inválido (no path são obrigatórios)")
    void ausentes() {
        var erro = assertThrows(ParametrosInvalidosException.class, () -> ChaveModelo.de(null, " "));
        assertEquals(2, erro.erros().size());
    }
}
