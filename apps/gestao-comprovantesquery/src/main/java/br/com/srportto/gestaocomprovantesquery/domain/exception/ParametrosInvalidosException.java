package br.com.srportto.gestaocomprovantesquery.domain.exception;

import br.com.srportto.gestaocomprovantesquery.domain.model.ErroParametro;
import java.util.List;

/** Um ou mais parâmetros inválidos; carrega todos os erros da requisição de uma vez (vira 400 na borda). */
public class ParametrosInvalidosException extends RuntimeException {

    private final List<ErroParametro> erros;

    public ParametrosInvalidosException(List<ErroParametro> erros) {
        super("Um ou mais parâmetros são inválidos.");
        this.erros = List.copyOf(erros);
    }

    public List<ErroParametro> erros() {
        return erros;
    }
}
