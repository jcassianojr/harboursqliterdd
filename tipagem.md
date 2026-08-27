# Mapeamento de Tipagem Bidirecional (Ida e Volta) para SQLite no Harbour/SQLMIX

Este documento detalha o fluxo bidirecional de conversão e mapeamento de tipos de dados entre o ecossistema Harbour (RDD/DBStruct) e o banco de dados SQLite, considerando o uso opcional da flag de emulação estrita `HB_SQLT3_MAP_DECLARED_EMULATED` no driver `sddsqlt3`[cite: 1, 5].

---

## 1. Visão Geral do Fluxo Bidirecional

O processo de "ida e volta" (*round-trip*) envolve duas etapas principais:
* **Ida (Harbour para SQLite):** Conversão da estrutura lógica do DBF/Harbour para o comando SQL `CREATE TABLE` através de geradores de dialeto (ex: `SqliteCreateTable`).
* **Volta (SQLite para Harbour):** Leitura dos metadados e dados do SQLite pelo driver `sddsqlt3` para a montagem da matriz de metadados do RDD (`DBStruct()`) e manipulação dos registros[cite: 1, 5].

---

## 2. Tabela de Mapeamento de Tipos (Ida e Volta)

| Tipo Harbour (DBF) | Geração no SQLite (Ida) | Leitura no Driver SQLite (Volta - Padrão) | Leitura no Driver SQLite (Volta - Com Emulação) |
| :--- | :--- | :--- | :--- |
| **C** (Character) | `TEXT NOT NULL DEFAULT ('')` | `HB_FT_STRING` ("C") | `HB_FT_STRING` ("C") |
| **N** (Numeric com Decimais) | `NUMERIC(len, dec)` | `HB_FT_LONG` ("N", 20, 2) | `HB_FT_LONG` ("N", len, dec)[cite: 1, 5] |
| **N** (Numeric Inteiro) | `NUMERIC(len, 0)` | `HB_FT_INTEGER` ("I", 8) | `HB_FT_LONG` ("N", len, 0)[cite: 1, 5] |
| **I** (Integer Nativo) | `INTEGER default 0` | `HB_FT_INTEGER` ("I", 8) | `HB_FT_INTEGER` ("I", 8) |
| **+** (Auto-incremento / PK) | `INTEGER UNIQUE` | `HB_FT_INTEGER` ("I", 8) | `HB_FT_INTEGER` ("I", 8) |
| **D** (Date) | `DATE NOT NULL DEFAULT ('')` | `HB_FT_STRING` ("C") *(como texto)* | `HB_FT_DATE` ("D", 8)[cite: 1, 5] |
| **@** / **T** (Timestamp/Time) | `DATETIME` / `TIMESTAMP` | `HB_FT_STRING` ("C") *(como texto)* | `HB_FT_TIMESTAMP` ("@", 8)[cite: 1, 5] |
| **L** (Logical) | `BOOLEAN` | Varia conforme o dado armazenado | Varia conforme o dado armazenado |
| **M** (Memo) | `TEXT` | `HB_FT_STRING` / `HB_FT_BLOB` | `HB_FT_STRING` / `HB_FT_BLOB` |

---

## 3. Considerações Técnicas e Boas Práticas

* **Afinidade do SQLite:** O SQLite armazena os dados com base em afinidades (TEXT, NUMERIC, INTEGER, REAL, BLOB). Declarar `NUMERIC(len, dec)` garante que a afinidade numérica correta seja aplicada na engine.
* **Papel da Flag `HB_SQLT3_MAP_DECLARED_EMULATED`:** Sem esta flag ativada na compilação do `sddsqlt3`, campos declarados como `DATE` ou `NUMERIC(p,s)` são retornados como strings ou com tamanhos genéricos padrão pelo driver[cite: 1, 5]. Com a flag ativa, o driver interpreta os parênteses do esquema e mapeia rigorosamente para os tipos e tamanhos originais do Harbour[cite: 1, 5].
* **Compatibilidade de Leitura:** A função `geracampodbf` complementa o processo fazendo a conversão reversa dos tipos de colunas vindos do banco de volta para o padrão interpretável pelo `DBStruct()`.