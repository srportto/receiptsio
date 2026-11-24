package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import br.com.srportto.gestaocomprovantesquery.domain.exception.CatalogoIndisponivelException;
import br.com.srportto.gestaocomprovantesquery.domain.exception.ModeloNaoEncontradoException;
import br.com.srportto.gestaocomprovantesquery.domain.exception.ParametrosInvalidosException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Ponto central de erro HTTP (RFC 9457 Problem Details). Estender {@link ResponseEntityExceptionHandler} cobre 405,
 * 404 de rota e demais erros do Spring MVC no mesmo formato.
 *
 * <p>Nenhuma resposta traz SQL, nome de tabela, pilha ou credencial: a causa vai só para o log.
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ApiExceptionHandler.class);

    /** Segundos sugeridos ao cliente antes de tentar de novo quando o catálogo está indisponível. */
    static final String TENTAR_EM_SEGUNDOS = "5";

    @ExceptionHandler(ParametrosInvalidosException.class)
    public ProblemDetail parametrosInvalidos(ParametrosInvalidosException erro) {
        var problema = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, erro.getMessage());
        problema.setTitle("Requisição inválida");
        problema.setProperty("errors", erro.erros());
        return problema;
    }

    @ExceptionHandler(ModeloNaoEncontradoException.class)
    public ProblemDetail naoEncontrado(ModeloNaoEncontradoException erro) {
        var problema = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, erro.getMessage());
        problema.setTitle("Modelo não encontrado");
        return problema;
    }

    @ExceptionHandler(CatalogoIndisponivelException.class)
    public ResponseEntity<ProblemDetail> indisponivel(CatalogoIndisponivelException erro) {
        LOG.warn("Catálogo indisponível: {}", erro.getCause() == null ? erro.getMessage() : erro.getCause().toString());
        var problema = ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE,
                "Catálogo temporariamente indisponível. Tente novamente em instantes.");
        problema.setTitle("Serviço indisponível");
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .header(HttpHeaders.RETRY_AFTER, TENTAR_EM_SEGUNDOS)
                .body(problema);
    }

    /** Falha não prevista: detalhe genérico para o cliente, causa completa no log. */
    @ExceptionHandler(Exception.class)
    public ProblemDetail inesperado(Exception erro) {
        LOG.error("Falha inesperada", erro);
        var problema = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno");
        problema.setTitle("Erro interno");
        return problema;
    }
}
