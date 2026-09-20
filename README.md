# SQLiterdd

SQLiterdd é uma extensão/adapter para Harbour que expõe o SQLite como um RDD (`Record Data Driver`) com comportamento compatível com o estilo xBase/DBF, mantendo acesso SQL nativo quando necessário.

O projeto é centrado em uma camada customizada chamada `SL3RDD`, que permite abrir tabelas no SQLite usando `USE ... VIA "SL3RDD"`, definir chave primária para operações lógicas de update/delete, gerenciar transações e preservar tipos e metadados em um formato mais amigável ao Harbour.

## Visão geral

O objetivo principal é unir duas abordagens:

- acesso relacional leve e poderoso do SQLite;
- ergonomia e compatibilidade de um RDD do Harbour para aplicações xBase/Clipper-like.

Em outras palavras, o projeto permite que uma aplicação Harbour trabalhe com SQLite sem perder a familiaridade do modelo de navegação, campos, `DBStruct()`, `FieldGet()`, `FieldPut()`, `APPEND BLANK`, `DBCommit()` e operações em registros.

## Principais recursos

- RDD customizado `SL3RDD` para SQLite;
- suporte a `USE`/`CLOSE` em estilo DBF;
- definição de chave primária via `SL3_SETPK()` para atualização e exclusão lógicas;
- controle de conexão e transação com `DBSL3CONNECTION()`, `DBSL3BEGINTRANS()`, `DBSL3COMMIT()` e `DBSL3ROLLBACK()`;
- manipulação de estruturas de campos e metadados em formato Harbour;
- emulação de afinidade de tipos e mapeamento bidirecional para datas, timestamps e numerics;
- suporte a memo/blob quando habilitado;
- compatibilidade com bibliotecas do ecossistema Harbour, especialmente `hbsqlit3`.

## Requisitos

- Harbour;
- `hbsqlit3` / SQLite driver para Harbour;
- compilador e ambiente de build do Harbour (Windows/MinGW/MSYS ou ambiente equivalente).

## Compilação

Há scripts de build no repositório para Windows:

```bat
complibw32.bat
complibw64.bat
```

Também é possível compilar diretamente via Harbour Make:

```bat
hbmk2 sqliterdd.hbp
```

O arquivo `sqliterdd.hbp` define a biblioteca e os módulos incluídos.

## Uso básico

```harbour
REQUEST SL3RDD

PROCEDURE Main()
   LOCAL nConn

   nConn := DBSL3CONNECTION( "teste_sl3.sqlite", .T. )
   IF nConn == 0
      ? "Falha ao conectar ao SQLite."
      RETURN
   ENDIF

   USE CLIENTES VIA "SL3RDD" ALIAS "CLIENTES"
   SL3_SETPK( "CLIENTES", "CODIGO" )

   APPEND BLANK
   FieldPut( 1, 100 )
   FieldPut( 2, "Joao da Silva" )
   FieldPut( 3, 1500.50 )
   FieldPut( 4, Date() )
   DBCommit()

   GO TOP
   DO WHILE !EOF()
      ? FieldGet( 1 ), FieldGet( 2 ), FieldGet( 3 )
      SKIP
   ENDDO

   CLOSE DATABASES
   DBSL3CLEARCONNECTION( nConn )
RETURN
```

O exemplo completo pode ser visto em `teste/sl3rddtest.prg`.

## Estrutura do repositório

- `SL3RDD.PRG` — implementação principal do RDD customizado;
- `sl3class.prg` — suporte e classes auxiliares para metadados/result sets;
- `sqliterdd.hbp` — projeto de build da biblioteca;
- `sqliterdd.hbc` / `sqliterdd.hbx` — configuração de exportação e integração Harbour;
- `teste/` — exemplos de uso e testes de validação;
- `tipagem.md` — documentação detalhada do mapeamento de tipos de dados;
- `afinidade/afinidade.md` — análise da afinidade emulada e do comportamento do SQLite no driver;
- `doacao_pix_paypal.md` — informação de apoio ao projeto.

## Documentação complementar

A suíte de documentação do projeto cobre aspectos importantes da camada de compatibilidade:

- `tipagem.md`: describe a conversão bidirecional entre Harbour e SQLite.
- `afinidade/afinidade.md`: explica como a afinidade/declaração de colunas influencia o comportamento do driver.

## Observações

Este projeto foi desenvolvido dentro do contexto de integrar SQLite ao modelo de programação Harbour/xBase, com foco em compatibilidade de tipos e APIs. O código e a documentação refletem um esforço de emulação de comportamento tradicional de RDD em cima de um banco relacional moderno.

## Licença

O repositório não inclui um arquivo de licença explícito no diretório raiz. Verifique a organização do projeto e os termos do uso antes de distribuir ou redistribuir o código em outros contextos.
