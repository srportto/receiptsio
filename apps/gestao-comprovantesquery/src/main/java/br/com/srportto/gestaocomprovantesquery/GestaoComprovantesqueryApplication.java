package br.com.srportto.gestaocomprovantesquery;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Classe principal da API de consulta do catálogo de modelos de comprovante (somente leitura). */
@SpringBootApplication
public class GestaoComprovantesqueryApplication {

    // main clássico: o plugin do Spring Boot 4.0.7 não reconhece o "void main()" instance-main do JDK 25.
    public static void main(String[] args) {
        SpringApplication.run(GestaoComprovantesqueryApplication.class, args);
    }
}
