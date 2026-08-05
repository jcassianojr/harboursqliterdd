REQUEST SL3RDD

PROCEDURE Main()
   LOCAL nConn, dbPtr, cDbName := "teste_sl3.sqlite"
   LOCAL cCreateSql
   
   ? "================================================="
   ? " Teste Nativo - SQLite via RDD Customizada (SL3) "
   ? "================================================="

   // 1. Abre a conexao com a RDD e pega o ponteiro para comandos diretos
   nConn := DBSL3CONNECTION( cDbName, .T. )
   
   IF nConn == 0
      ? "Falha ao conectar/criar o banco SQLite."
      RETURN
   ENDIF

   dbPtr := DBSL3GETHANDLE( nConn ) // Pega o ponteiro C nativo da base

   // Prepara tabela inicial para o teste nativamente
   cCreateSql := "CREATE TABLE IF NOT EXISTS CLIENTES ( " + ;
                 "CODIGO INTEGER PRIMARY KEY, " + ;
                 "NOME TEXT NOT NULL, " + ;
                 "SALDO REAL, " + ;
                 "CADASTRO DATE )"
                 
   sqlite3_exec( dbPtr, cCreateSql )
   sqlite3_exec( dbPtr, "DELETE FROM CLIENTES" )

   ? "Banco e Tabela criados. Iniciando Teste RDD..."
   ? "-------------------------------------------------"

   // 2. Abre usando DBF-Style via RDD de forma nativa e limpa!
   USE CLIENTES VIA "SL3RDD" ALIAS "CLIENTES"
   
   // 3. Essencial: Define a Chave Primaria para habilitar Update/Delete logico
   SL3_SETPK( "CLIENTES", "CODIGO" )  //SL3_SETPK( "CODIGO" )

   ? "Tabela Aberta:", Alias()
   ? "Injetando 3 registros nativamente via dbAppend()..."

   // Insert 1
   APPEND BLANK
   FieldPut( 1, 100 )
   FieldPut( 2, "Joao da Silva" )
   FieldPut( 3, 1500.50 )
   FieldPut( 4, Date() )
   DBCommit()

   // Insert 2
   APPEND BLANK
   FieldPut( 1, 101 )
   FieldPut( 2, "Maria Oliveira" )
   FieldPut( 3, 300.00 )
   FieldPut( 4, Date() - 5 )
   DBCommit()
   
   // Insert 3
   APPEND BLANK
   FieldPut( 1, 102 )
   FieldPut( 2, "Carlos Souza" )
   FieldPut( 3, 50.00 )
   FieldPut( 4, Date() - 10 )
   DBCommit()

   ? "Registros Atuais na Tabela:", LastRec()
   
   ? "-------------------------------------------------"
   ? "Listando o banco via RDD..."
   GO TOP
   DO WHILE !EOF()
      ? "Registro:", RecNo(), "| Codigo:", FieldGet(1), "| Nome:", FieldGet(2), "| Saldo:", FieldGet(3)
      SKIP
   ENDDO

   ? "-------------------------------------------------"
   ? "Alterando (Update) o Codigo 101 via Replace..."
   GO TOP
   SKIP 1  
   
   FieldPut( 3, 5000.99 ) // Atualiza Saldo
   DBCommit()
   
   ? "Novo Saldo Maria:", FieldGet( 3 )

   ? "-------------------------------------------------"
   ? "Apagando (Delete) o Codigo 102..."
   GO BOTTOM
   DbDelete()

   ? "Registros Restantes:", LastRec()
   
   ? hb_valtoexp(dbstruct())

   // 4. Fechamento global e limpeza
   CLOSE DATABASES
   DBSL3CLEARCONNECTION( nConn )
   
   ? "Teste encerrado com sucesso."

RETURN