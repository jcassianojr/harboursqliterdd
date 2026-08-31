core\contrib\sddsqlt3\

na estrutura do driver SQLite do Harbour, a comparaá∆o entre o comportamento **sem** a afinidade estrita emulada (`HB_SQLT3_MAP_DECLARED_EMULATED` desativada) e **com** a afinidade/emulaá∆o ativada demonstra diferenáas fundamentais na forma como os dados e as estruturas s∆o interpretados:

* **Tratamento de Datas e Horas**
* **Sem afinidade emulada:** Os campos declarados como `DATE` ou `DATETIME` no banco perdem o tipo nativo do Harbour, sendo mapeados como Caracter (`C`) com tamanhos fixos de 10 (`YYYY-MM-DD`) ou 19 posiá‰es, exigindo convers‰es manuais na leitura.


* **Com afinidade emulada:** O driver mapeia explicitamente declaraá‰es de data para o tipo Data (`D`, tamanho 8) e carimbos de data/hora para o tipo Timestamp (`@`, tamanho 8), permitindo manipulaá∆o direta no formato de datas do Harbour.




* **Precis∆o NumÇrica e Decimais**
* **Sem afinidade emulada:** Campos numÇricos customizados (`NUMERIC(12,2)`) tendem a assumir tamanhos genÇricos padr∆o (como largura 20), ignorando a escala declarada no esquema original.


* **Com afinidade emulada:** O driver là a declaraá∆o de precis∆o e escala do schema SQL e ajusta os metadados do `DBStruct()` para refletir os tamanhos exatos especificados (por exemplo, `N, 13, 2` ou `N, 6, 2`).




* **Comportamento do Tipo Textual**
* **Sem afinidade emulada:** Colunas de texto sem tamanho delimitado expl°cito assumem larguras padr∆o restritivas (como tamanho 10) no buffer do RDD.


* **Com afinidade emulada:** O driver preserva e dimensiona o espaáo do campo de acordo com o tamanho declarado na definiá∆o da tabela (`VARCHAR(40)`, por exemplo).




* **Armazenamento Interno Real**
* **Com e sem afinidade:** Em ambos os cen†rios, o SQLite continua operando internamente com suas regras de afinidade de armazenamento nativas (gravando como `integer`, `text`, `real`, etc.), garantindo que a performance e o motor SQL do banco n∆o sejam alterados. A emulaá∆o atua puramente na camada do driver de metadados (`SDDSQLT3`/`SQLMIX`) para traduzir o comportamento relacional para o padr∆o xBase esperado pela aplicaá∆o.
