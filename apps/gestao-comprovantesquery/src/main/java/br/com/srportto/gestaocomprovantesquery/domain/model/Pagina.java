package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.util.List;

/** Página de resultados com o objeto {@link Pagination}. */
public record Pagina<T>(List<T> items, Pagination pagination) {

    public static <T> Pagina<T> de(List<T> items, PageRequest pedido, long totalElements) {
        long paginas = (totalElements + pedido.size() - 1) / pedido.size();
        int totalPages = (int) Math.min(paginas, Integer.MAX_VALUE);
        return new Pagina<>(List.copyOf(items),
                new Pagination(pedido.page(), pedido.size(), totalElements, totalPages));
    }
}
