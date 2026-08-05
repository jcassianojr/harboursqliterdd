#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"

#require "hbsqlit3"

#define AREA_CONN     1
#define AREA_TABLE    2
#define AREA_PK       3
#define AREA_CACHE    4
#define AREA_RECNO    5
#define AREA_ROWBUF   6
#define AREA_APPEND   7
#define AREA_EOF      8
#define AREA_BOF      9
#define AREA_FIELDS   10
#define AREA_LEN      10

ANNOUNCE SL3RDD

STATIC s_aConnections := {}

// +--------------------------------------------------------------------
// +    Funcoes de Gerenciamento de Conexao SQLite
// +--------------------------------------------------------------------

FUNCTION DBSL3CONNECTION( cDbName, lCreate )
   LOCAL db
   IF lCreate == NIL
      lCreate := .F.
   ENDIF
   
   db := sqlite3_open( cDbName, lCreate )
   
   IF Empty( db ) .OR. sqlite3_errcode( db ) > 0
      Alert( "Erro ao conectar SQLite: " + sqlite3_errmsg( db ) )
      RETURN 0
   ENDIF

   AAdd( s_aConnections, db )
RETURN Len( s_aConnections )

FUNCTION DBSL3CLEARCONNECTION( nConn )
   LOCAL db
   IF nConn > 0 .AND. nConn <= Len( s_aConnections )
      db := s_aConnections[ nConn ]
      IF !Empty( db )
         // sqlite3_close não é diretamente exposto às vezes, mas exec pode rodar PRAGMAs de encerramento, ou a lib gerencia a coleta. 
         // O Harbour fecha nativamente no GC, mas limpamos o array.
         s_aConnections[ nConn ] := NIL
      ENDIF
   ENDIF
RETURN SUCCESS

FUNCTION DBSL3GETHANDLE( nConn )
   IF nConn > 0 .AND. nConn <= Len( s_aConnections )
      RETURN s_aConnections[ nConn ]
   ENDIF
RETURN NIL

// Define os campos que serao usados como clausula WHERE no UPDATE/DELETE
FUNCTION SL3_SETPK( cAlias, cFields )
   LOCAL nWA, aWAData
   
   // Flexibilidade: se passar apenas 1 parametro, assume a WorkArea atual
   IF PCount() == 1
      cFields := cAlias
      nWA := Select()
   ELSE
      nWA := Select( cAlias )
      // Fallback: se nao achar o Alias, usa a area ativa no momento
      IF nWA == 0
         nWA := Select() 
      ENDIF
   ENDIF
   
   IF nWA > 0
      aWAData := USRRDD_AREADATA( nWA )
      IF aWAData != NIL
         aWAData[ AREA_PK ] := hb_ATokens( StrTran( cFields, " ", "" ), "," )
         RETURN .T.
      ENDIF
   ENDIF
RETURN .F.
// +--------------------------------------------------------------------
// +    Metodos Internos da RDD
// +--------------------------------------------------------------------

STATIC FUNCTION SL3_INIT( nRDD )
   USRRDD_RDDDATA( nRDD )
RETURN SUCCESS

STATIC FUNCTION SL3_NEW( pWA )
   USRRDD_AREADATA( pWA, Array( AREA_LEN ) )
RETURN SUCCESS

// Ajuste o SL3_OPEN para assumir a conexao padrao
STATIC FUNCTION SL3_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL oError, nResult, db, aTableInfo, i, cType
   LOCAL aField, cTableName,cBaseType
   LOCAL nFieldLen, nDec, nPos1, nPos2, nPosComma, cParams

   // Se passou via dbUseArea, usa a conexao informada
   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ]
   ELSEIF Len( s_aConnections ) > 0
      // MAGICA PARA O COMANDO USE PADRÃO: Assume a ultima conexao ativa!
      db := s_aConnections[ Len( s_aConnections ) ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:SubCode     := 1000
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Nenhuma conexao SQLite ativa."
      oError:FileName    := aOpenInfo[ UR_OI_NAME ]
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] )
   
   aWAData[ AREA_CONN ]   := db
   aWAData[ AREA_TABLE ]  := cTableName
   aWAData[ AREA_PK ]     := {}
   aWAData[ AREA_RECNO ]  := 0
   aWAData[ AREA_APPEND ] := .F.
   aWAData[ AREA_FIELDS ] := {}

   // 1. Obtem a estrutura da tabela (PRAGMA table_info)
   aTableInfo := sqlite3_get_table( db, "PRAGMA table_info(" + cTableName + ")" )
   IF sqlite3_errcode( db ) > 0
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := "Tabela nao encontrada no banco SQLite: " + cTableName
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   UR_SUPER_SETFIELDEXTENT( nWA, Len( aTableInfo ) - 1 )

// Pula a primeira linha que e o cabecalho
   FOR i := 2 TO Len( aTableInfo )
      cType := Upper( AllTrim( aTableInfo[ i, 3 ] ) )
      aField := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ] := aTableInfo[ i, 2 ]

      // --- 1. Extrai tamanho e decimais (n) e (n,n) usando a string original cType ---
      nFieldLen := 0
      nDec      := 0
      nPos1     := At( "(", cType )
      nPos2     := At( ")", cType )

      IF nPos1 > 0 .AND. nPos2 > nPos1
         cParams   := SubStr( cType, nPos1 + 1, nPos2 - nPos1 - 1 )
         nPosComma := At( ",", cParams )

         IF nPosComma > 0
            nFieldLen := Val( SubStr( cParams, 1, nPosComma - 1 ) )
            nDec      := Val( SubStr( cParams, nPosComma + 1 ) )
         ELSE
            nFieldLen := Val( cParams )
            nDec      := 0
         ENDIF
      ENDIF

      // --- 2. Extrai o tipo base limpo (removendo :BZEU e parênteses para a validação) ---
// --- 2. Extrai o tipo base limpo (removendo :BZ e parênteses para a validação) ---
      cBaseType := cType
      IF At( ":", cBaseType ) > 0
         cBaseType := SubStr( cBaseType, 1, At( ":", cBaseType ) - 1 )
      ENDIF
      IF At( "(", cBaseType ) > 0
         cBaseType := SubStr( cBaseType, 1, At( "(", cBaseType ) - 1 )
      ENDIF
      cBaseType := AllTrim( cBaseType )
      
      // --- 3. Aplica a tipagem validando o cBaseType ---
      IF "INT" $ cBaseType
         aField[ UR_FI_TYPE ] := HB_FT_LONG
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 10 )
         aField[ UR_FI_DEC ]  := 0
      ELSEIF "REAL" $ cBaseType .OR. "NUM" $ cBaseType .OR. "DOUB" $ cBaseType
         aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 18 )
         aField[ UR_FI_DEC ]  := IIf( nPos1 > 0, nDec, 4 )
      ELSEIF "DATE" $ cBaseType
         aField[ UR_FI_TYPE ] := HB_FT_DATE
         aField[ UR_FI_LEN ]  := 8
         aField[ UR_FI_DEC ]  := 0
      ELSEIF "BOOL" $ cBaseType
         aField[ UR_FI_TYPE ] := HB_FT_LOGICAL
         aField[ UR_FI_LEN ]  := 1
         aField[ UR_FI_DEC ]  := 0
      ELSE
         aField[ UR_FI_TYPE ] := HB_FT_STRING
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 255 )
         aField[ UR_FI_DEC ]  := 0
      ENDIF
      
      AAdd( aWAData[ AREA_FIELDS ], aField[ UR_FI_NAME ] )
      UR_SUPER_ADDFIELD( nWA, aField )
    NEXT
    
   // 2. Carrega o Cache em Memoria
   SL3_LOADCACHE( aWAData )

   nResult := UR_SUPER_OPEN( nWA, aOpenInfo )
RETURN nResult

STATIC FUNCTION SL3_LOADCACHE( aWAData )
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL aResult, i, j
   
   aResult := sqlite3_get_table( db, "SELECT * FROM " + aWAData[ AREA_TABLE ] )
   
   aWAData[ AREA_CACHE ] := {}
   IF Len( aResult ) > 1
      // Remove o cabeçalho e carrega apenas os dados reais da tabela
      FOR i := 2 TO Len( aResult )
         AAdd( aWAData[ AREA_CACHE ], aResult[ i ] )
      NEXT
   ENDIF

   IF Len( aWAData[ AREA_CACHE ] ) > 0
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
   ELSE
      aWAData[ AREA_RECNO ] := 0
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .T.
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   aWAData[ AREA_CACHE ] := {}
   aWAData[ AREA_ROWBUF ] := NIL
RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION SL3_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ AREA_APPEND ] .AND. !Empty( aWAData[ AREA_ROWBUF ] )
      xValue := aWAData[ AREA_ROWBUF ][ nField ]
   ELSEIF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      xValue := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nField ]
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_ROWBUF ] := AClone( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] )
      ELSE
         aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
      ENDIF
   ENDIF
   aWAData[ AREA_ROWBUF ][ nField ] := xValue
RETURN SUCCESS

STATIC FUNCTION SL3_SKIP( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL nNewRec
   
   IF !Empty( aWAData[ AREA_ROWBUF ] )
      SL3_FLUSH( nWA )
   ENDIF

   nNewRec := aWAData[ AREA_RECNO ] + nRecords
   IF Len( aWAData[ AREA_CACHE ] ) == 0
      aWAData[ AREA_BOF ] := .T.
      aWAData[ AREA_EOF ] := .T.
   ELSEIF nNewRec > Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := Len( aWAData[ AREA_CACHE ] ) + 1
      aWAData[ AREA_EOF ]   := .T.
      aWAData[ AREA_BOF ]   := .F.
   ELSEIF nNewRec < 1
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .F.
   ELSE
      aWAData[ AREA_RECNO ] := nNewRec
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_GOTOP( nWA )
   RETURN SL3_GOTO( nWA, 1 )

STATIC FUNCTION SL3_GOBOTTOM( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   RETURN SL3_GOTO( nWA, Len( aWAData[ AREA_CACHE ] ) )

STATIC FUNCTION SL3_GOTOID( nWA, nRecord )
   RETURN SL3_GOTO( nWA, nRecord )

STATIC FUNCTION SL3_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] )
      SL3_FLUSH( nWA )
   ENDIF
   
   IF nRecord >= 1 .AND. nRecord <= Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := nRecord
      aWAData[ AREA_EOF ] := .F.
      aWAData[ AREA_BOF ] := .F.
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecords := Len( aWAData[ AREA_CACHE ] )
RETURN SUCCESS

STATIC FUNCTION SL3_BOF( nWA, lBof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lBof := aWAData[ AREA_BOF ]
RETURN SUCCESS

STATIC FUNCTION SL3_EOF( nWA, lEof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lEof := aWAData[ AREA_EOF ]
RETURN SUCCESS

STATIC FUNCTION SL3_RECID( nWA, nRecNo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecno := aWAData[ AREA_RECNO ]
RETURN SUCCESS

STATIC FUNCTION SL3_APPEND( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_APPEND ] := .T.
   aWAData[ AREA_EOF ]    := .T.
RETURN SUCCESS

STATIC FUNCTION SL3_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cSql, cFields, cValues, cWhere, i, nPosPK
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL oError

   IF !Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_APPEND ]
         cFields := ""
         cValues := ""
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF i > 1
               cFields += ", "
               cValues += ", "
            ENDIF
            cFields += aWAData[ AREA_FIELDS ][ i ]
            cValues += SL3_VALTOSQL( aWAData[ AREA_ROWBUF ][ i ] )
         NEXT
         cSql := "INSERT INTO " + aWAData[ AREA_TABLE ] + " (" + cFields + ") VALUES (" + cValues + ")"
      ELSE
         IF Empty( aWAData[ AREA_PK ] )
            oError := ErrorNew()
            oError:GenCode := EG_DATATYPE
            oError:Description := "SL3RDD: Operação UPDATE abortada. Defina a Primary Key usando SL3_SETPK() primeiro."
            UR_SUPER_ERROR( nWA, oError )
            RETURN FAILURE
         ENDIF
         
         cSql := "UPDATE " + aWAData[ AREA_TABLE ] + " SET "
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF i > 1
               cSql += ", "
            ENDIF
            cSql += aWAData[ AREA_FIELDS ][ i ] + " = " + SL3_VALTOSQL( aWAData[ AREA_ROWBUF ][ i ] )
         NEXT
         
         cWhere := ""
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               IF i > 1
                  cWhere += " AND "
               ENDIF
               cWhere += aWAData[ AREA_PK ][ i ] + " = " + SL3_VALTOSQL( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
            ENDIF
         NEXT
         cSql += " WHERE " + cWhere
      ENDIF

      sqlite3_exec( db, cSql )
      
      IF sqlite3_errcode( db ) > 0
         oError := ErrorNew()
         oError:GenCode := EG_DATATYPE
         oError:Description := "Erro SQL: " + sqlite3_errmsg( db ) + " | Query: " + cSql
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF

      // Recarrega o cache atualizado
      SL3_LOADCACHE( aWAData )

      IF aWAData[ AREA_APPEND ]
         aWAData[ AREA_APPEND ] := .F.
         aWAData[ AREA_RECNO ]  := Len( aWAData[ AREA_CACHE ] )
      ENDIF
      aWAData[ AREA_ROWBUF ] := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL cSql, cWhere := "", i, nPosPK, oError

   IF Empty( aWAData[ AREA_PK ] )
      oError := ErrorNew()
      oError:GenCode := EG_DATATYPE
      oError:Description := "SL3RDD: Operação DELETE abortada. Defina a Primary Key usando SL3_SETPK() primeiro."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      FOR i := 1 TO Len( aWAData[ AREA_PK ] )
         nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
         IF nPosPK > 0
            IF i > 1
               cWhere += " AND "
            ENDIF
            cWhere += aWAData[ AREA_PK ][ i ] + " = " + SL3_VALTOSQL( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
         ENDIF
      NEXT
      
      cSql := "DELETE FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
      sqlite3_exec( db, cSql )
      
      IF sqlite3_errcode( db ) > 0
         oError := ErrorNew()
         oError:GenCode := EG_DATATYPE
         oError:Description := "Erro SQL no Delete: " + sqlite3_errmsg( db )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
      
      SL3_LOADCACHE( aWAData )
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_VALTOSQL( xVal )
   LOCAL cType := ValType( xVal )
   IF cType == "N"
      RETURN AllTrim( Str( xVal ) )
   ELSEIF cType == "D"
      RETURN IF( Empty( xVal ), "''", "'" + SubStr( DToS( xVal ), 1, 4 ) + "-" + SubStr( DToS( xVal ), 5, 2 ) + "-" + SubStr( DToS( xVal ), 7, 2 ) + "'" )
   ELSEIF cType == "L"
      RETURN IF( xVal, "1", "0" )
   ELSEIF cType $ "CM"
      IF Empty( xVal )
         RETURN "''"
      ENDIF
      RETURN "'" + StrTran( xVal, "'", "''" ) + "'"
   ENDIF
RETURN "NULL"

// +--------------------------------------------------------------------
// +    Tabela de Roteamento de Metodos 
// +--------------------------------------------------------------------

FUNCTION SL3RDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID )
   LOCAL cSuperRDD := NIL
   LOCAL aMyFunc[ UR_METHODCOUNT ]

   aMyFunc[ UR_INIT ]     := ( @SL3_INIT() )
   aMyFunc[ UR_NEW ]      := ( @SL3_NEW() )
   aMyFunc[ UR_OPEN ]     := ( @SL3_OPEN() )
   aMyFunc[ UR_CLOSE ]    := ( @SL3_CLOSE() )
   aMyFunc[ UR_GETVALUE ] := ( @SL3_GETVALUE() )
   aMyFunc[ UR_PUTVALUE ] := ( @SL3_PUTVALUE() )
   aMyFunc[ UR_SKIP ]     := ( @SL3_SKIP() )
   aMyFunc[ UR_GOTO ]     := ( @SL3_GOTO() )
   aMyFunc[ UR_GOTOID ]   := ( @SL3_GOTOID() )
   aMyFunc[ UR_GOTOP ]    := ( @SL3_GOTOP() )
   aMyFunc[ UR_GOBOTTOM ] := ( @SL3_GOBOTTOM() )
   aMyFunc[ UR_RECCOUNT ] := ( @SL3_RECCOUNT() )
   aMyFunc[ UR_RECID ]    := ( @SL3_RECID() )
   aMyFunc[ UR_BOF ]      := ( @SL3_BOF() )
   aMyFunc[ UR_EOF ]      := ( @SL3_EOF() )
   aMyFunc[ UR_FLUSH ]    := ( @SL3_FLUSH() )
   aMyFunc[ UR_APPEND ]   := ( @SL3_APPEND() )
   aMyFunc[ UR_DELETE ]   := ( @SL3_DELETE() )

   RETURN USRRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID, cSuperRDD, aMyFunc )

INIT PROC SL3_INIT_REGISTER()
   rddRegister( "SL3RDD", RDT_FULL )
RETURN