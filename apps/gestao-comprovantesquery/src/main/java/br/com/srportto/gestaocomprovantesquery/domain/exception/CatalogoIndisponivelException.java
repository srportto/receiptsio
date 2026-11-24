package br.com.srportto.gestaocomprovantesquery.domain.exception;

/** O catálogo não respondeu a tempo ou está fora do ar; o cliente pode tentar de novo (vira 503 na borda). */
public class CatalogoIndisponivelException extends RuntimeException {

    public CatalogoIndisponivelException(Throwable causa) {
        super("Catálogo indisponível", causa);
    }
}
