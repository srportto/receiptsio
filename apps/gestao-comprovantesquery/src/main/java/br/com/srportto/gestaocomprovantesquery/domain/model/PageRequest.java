package br.com.srportto.gestaocomprovantesquery.domain.model;

/** Página pedida: {@code page} a partir de 1 e {@code size} de 1 a {@value #TAMANHO_MAXIMO}. */
public record PageRequest(int page, int size) {

    public static final int TAMANHO_PADRAO = 20;
    public static final int TAMANHO_MAXIMO = 100;

    public PageRequest {
        if (page < 1 || size < 1 || size > TAMANHO_MAXIMO) {
            throw new IllegalArgumentException("page deve ser >= 1 e size de 1 a " + TAMANHO_MAXIMO);
        }
    }

    /** Linhas a descartar antes da página; long porque page * size pode passar de int. */
    public long offset() {
        return (long) (page - 1) * size;
    }
}
