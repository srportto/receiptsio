package br.com.srportto.gestaocomprovantesquery.domain.model;

/** Objeto de paginação devolvido ao cliente (offset): página atual, tamanho pedido e totais do filtro. */
public record Pagination(int page, int size, long totalElements, int totalPages) {
}
