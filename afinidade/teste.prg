#include "dbinfo.ch"
#include "error.ch"
#include "simpleio.ch"
#include "BOX.CH"
#include "dbstruct.ch"


REQUEST SQLMIX
REQUEST SDDSQLITE3

PROCEDURE Main()
   LOCAL aStruct, aField
   LOCAL cDbFile := "teste_afinidade.sqlite"
   LOCAL nConn

   // Remove a base anterior se existir
   IF File( cDbFile )
      FErase( cDbFile )
   ENDIF

   CLS
   ? "=== TESTE DE EMULACAO E AFINIDADE SQLITE VIA SQLMIX/SDDSQLT3 ==="
   
   // 1. Configura o RDD padrão para SQLMIX
   rddSetDefault( "SQLMIX" )

   // 2. Conecta ao SQLite utilizando a infraestrutura do SDDSQLT3 via rddInfo
   // Equivalente à rotina do mix_open() no seu dbumix.prg
   nConn := rddInfo( RDDI_CONNECT, { "SQLITE3", cDbFile } )
   
   IF !( nConn > 0 )
      ? "Erro ao conectar ao banco SQLite via SDDSQLT3."
      RETURN
   ENDIF
   ? "Conexão estabelecida com sucesso! Handle:", nConn
   ?

   // 3. Cria a tabela usando comandos SQL diretos via rddInfo (RDDI_EXECUTE)
   rddInfo( RDDI_EXECUTE, "CREATE TABLE clientes (" + ;
                          "id INTEGER PRIMARY KEY AUTOINCREMENT, " + ;
                          "nome TEXT NOT NULL, " + ;
                          "salario NUMERIC(12,2) DEFAULT 0, " + ;
                          "nascimento DATE);" )

   // Insere um registro de teste via SQL
   rddInfo( RDDI_EXECUTE, "INSERT INTO clientes (nome, salario, nascimento) VALUES ('JOAO SILVA', 15432.50, '2026-06-06');" )
   ? "Tabela criada e populada via SQL!"
   ?

   // 4. Abre a tabela usando o conceito de query / workarea do SQLMIX/SDDSQLT3
   // O SQLMIX permite abrir um SELECT diretamente como uma tabela navegável
   //if  ! file(cDbFile)
   //    IF !DBCreate( "clientes", {;
   //          { "ID",     "N", 10, 0 }, ;
   //          { "NOME",   "C", 30, 0 }, ;
   //          { "SALARIO","N", 12, 2 }, ;
   //          { "NASC",   "D",  8, 0 }  ;
   //       }, "SDDSQLT3", .T., "CLI" )
          
          // Se a tabela já existir no arquivo, abre via SELECT correspondente
          //dbUseArea( .T., "SDDSQLT3", "SELECT * FROM clientes", "CLI", .T., .F. )
    //   ENDIF
   // endif   
   
   // 4. Como a tabela já foi criada via SQL, abrimos diretamente via SELECT usando o SQLMIX/SDDSQLT3
   //dbUseArea( .T., "SDDSQLT3", "SELECT * FROM clientes", "CLI", .T., .F. )
   //dbUseArea( .T., "SQLMIX", "clientes", "CLI", .T., .F. )
   // Abre a tabela via SQLMIX passando a query e o handle da conexão no 8º parâmetro
   dbUseArea( .T., "SQLMIX", "SELECT * FROM clientes", "CLI", .T., .F.,, nConn )

   IF NetErr()
      ? "Erro ao abrir a tabela via SDDSQLT3."
      rddInfo( RDDI_DISCONNECT, nConn )
      WAIT
      RETURN
   ENDIF

   IF NetErr()
      ? "Erro ao abrir a tabela via SDDSQLT3."
      rddInfo( RDDI_DISCONNECT, nConn )
      WAIT
      RETURN
   ENDIF

   // 5. Exibe a estrutura retornada pelo DBStruct() para verificar a emulação de tipos
   ? "--- ESTRUTURA RETORNADA PELO DBSTRUCT() ---"
   aStruct := DBStruct()
   FOR EACH aField IN aStruct
       ? "Campo:", PadR( HB_EnumIndex(), 2 ), ;
         "| Nome:", PadR( aField[1], 10 ), ;
         "| Tipo:", aField[2], ;
         "| Tam:",  Str(aField[3], 4), ;
         "| Dec:",  Str(aField[4], 2)
   NEXT
   ?

   // 6. Exibe os dados lidos da tabela
   ? "--- DADOS LIDOS DA TABELA ---"
   GO TOP
   DO WHILE !EOF()
      ? "ID:", CLI->id, ;
        "| Nome:", CLI->nome, ;
        "| Salario (Tipo:", ValType(CLI->salario), "):", CLI->salario, ;
        "| Nasc (Tipo:", ValType(CLI->nascimento), "):", CLI->nascimento
      SKIP
   ENDDO

   // Fecha a área de trabalho
   USE

   // Desconecta do banco
   rddInfo( RDDI_DISCONNECT, nConn )

   ?
   ? "Fim do teste. Pressione qualquer tecla para sair."
   WAIT
RETURN