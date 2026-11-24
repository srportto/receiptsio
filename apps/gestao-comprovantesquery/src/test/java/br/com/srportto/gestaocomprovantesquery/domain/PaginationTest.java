package br.com.srportto.gestaocomprovantesquery.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;

import br.com.srportto.gestaocomprovantesquery.domain.model.PageRequest;
import br.com.srportto.gestaocomprovantesquery.domain.model.Pagina;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Objeto Pagination: totalPages arredonda para cima e vale 0 sem itens. */
class PaginationTest {

    @Test
    @DisplayName("Nenhum item: totalElements 0 e totalPages 0")
    void vazia() {
        var pagina = Pagina.de(List.<String>of(), new PageRequest(1, 20), 0);
        assertEquals(0, pagina.pagination().totalElements());
        assertEquals(0, pagina.pagination().totalPages());
        assertEquals(1, pagina.pagination().page());
        assertEquals(20, pagina.pagination().size());
    }

    @Test
    @DisplayName("3 itens com size 2: 2 páginas")
    void arredondaParaCima() {
        var pagina = Pagina.de(List.of("a", "b"), new PageRequest(1, 2), 3);
        assertEquals(2, pagina.pagination().totalPages());
        assertEquals(2, pagina.items().size());
    }

    @Test
    @DisplayName("Divisão exata não cria página extra")
    void exata() {
        assertEquals(2, Pagina.de(List.of("a", "b"), new PageRequest(1, 2), 4).pagination().totalPages());
    }

    @Test
    @DisplayName("Página além da última: items vazio e total real preservado")
    void alemDaUltima() {
        var pagina = Pagina.de(List.<String>of(), new PageRequest(99, 20), 3);
        assertEquals(3, pagina.pagination().totalElements());
        assertEquals(1, pagina.pagination().totalPages());
        assertEquals(99, pagina.pagination().page());
    }

    @Test
    @DisplayName("Offset usa long: página enorme não estoura")
    void offsetLong() {
        assertEquals(2_147_483_646L * 100, new PageRequest(Integer.MAX_VALUE, 100).offset());
    }
}
