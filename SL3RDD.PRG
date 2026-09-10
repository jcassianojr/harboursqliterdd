#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"
#include "dbinfo.ch"
#include "hbsqlit3.ch"  // <- ESSENCIAL PARA RESOLVER OS AVISOS DO SQLITE

// --- MAPEAMENTO DA ÁREA DE TRABALHO (WORKAREA) ---
#define AREA_CONN         1
#define AREA_TABLE        2
#define AREA_PK           3
#define AREA_CACHE        4
#define AREA_RECNO        5
#define AREA_ROWBUF       6
#define AREA_APPEND       7
#define AREA_EOF          8
#define AREA_BOF          9
#define AREA_FIELDS       10
#define AREA_STRUCT       11
#define AREA_STMT         12  
#define AREA_FETCHED_EOF  13  
#define AREA_TYPES        14  
#define AREA_LEN          14

ANNOUNCE SL3RDD

STATIC s_aConnections := {}
THREAD STATIC t_lLoadMemos := .T.
THREAD STATIC t_lLoadBlobs := .T.

// +--------------------------------------------------------------------
// +    Funcoes de Gerenciamento de Conexao SQLite
// +--------------------------------------------------------------------

FUNCTION DBSL3CONNECTION( cDbName, lCreate )
   LOCAL db
   IF ValType( lCreate ) <> "L"
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
         s_aConnections[ nConn ] := NIL
      ENDIF
   ENDIF
RETURN SUCCESS

PROCEDURE SL3_SetLoadBlobs( lLoad )
   t_lLoadBlobs := lLoad
RETURN

PROCEDURE SL3_SetLoadMemos( lLoad )
   t_lLoadMemos := lLoad
RETURN

FUNCTION DBSL3GETHANDLE( nConn )
   IF nConn > 0 .AND. nConn <= Len( s_aConnections )
      RETURN s_aConnections[ nConn ]
   ENDIF
RETURN NIL

FUNCTION SL3_SETPK( cAlias, cFields )
   LOCAL nWA, aWAData
   
   IF PCount() == 1
      cFields := cAlias
      nWA := Select()
   ELSE
      nWA := Select( cAlias )
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

STATIC FUNCTION SL3_ADDFIELD( nWA, aField )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF aWAData != NIL
      IF aWAData[ AREA_STRUCT ] == NIL
         aWAData[ AREA_STRUCT ] := {}
      ENDIF
      AAdd( aWAData[ AREA_STRUCT ], AClone( aField ) )
   ENDIF
   
RETURN UR_SUPER_ADDFIELD( nWA, aField )


STATIC FUNCTION SL3_CREATE( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db, oError, cSql, n, nResult
   LOCAL cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] )
   LOCAL aStruct    := aWAData[ AREA_STRUCT ]
   LOCAL mFldNm, mFldType, mFldLen, mFldDec

   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ]
   ELSEIF Len( s_aConnections ) > 0
      db := s_aConnections[ Len( s_aConnections ) ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Nenhuma conexao SQLite ativa para dbCreate()."
      oError:FileName    := cTableName
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   cSql := "CREATE TABLE IF NOT EXISTS " + cTableName + " ( "

   FOR n := 1 TO Len( aStruct )
      mFldNm   := aStruct[ n, UR_FI_NAME ]
      mFldType := aStruct[ n, UR_FI_TYPE ]
      mFldLen  := aStruct[ n, UR_FI_LEN ]
      mFldDec  := aStruct[ n, UR_FI_DEC ]

      IF n > 1
         cSql += ", "
      ENDIF

      cSql += AllTrim( mFldNm ) + " "

      DO CASE
         CASE mFldType == HB_FT_AUTOINC
            cSql += "INTEGER PRIMARY KEY AUTOINCREMENT" 
         CASE mFldNm == "SR_RECNO"
            cSql += "INTEGER UNIQUE"
            
         CASE mFldType == HB_FT_STRING .OR. mFldType == HB_FT_ANY .OR. mFldType == HB_FT_VARLENGTH
            cSql += "TEXT NOT NULL DEFAULT ('')"
            
         CASE mFldType == HB_FT_DATE
            cSql += "DATE NOT NULL DEFAULT ('')"
         CASE mFldType == HB_FT_TIMESTAMP .OR. mFldType == HB_FT_TIME
            cSql += "DATETIME"
            
         CASE mFldType == HB_FT_DOUBLE .OR. mFldType == HB_FT_LONG .OR. mFldType == HB_FT_FLOAT
            IF mFldDec > 0
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + "," + hb_ntos( mFldDec ) + ") default 0"
            ELSE
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + ",0) default 0"
            ENDIF
            
         CASE mFldType == HB_FT_CURRENCY .OR. mFldType == HB_FT_CURDOUBLE
            IF mFldDec > 0
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + "," + hb_ntos( mFldDec ) + ")"
            ELSE
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + ")"
            ENDIF
            
         CASE mFldType == HB_FT_INTEGER
            cSql += "INTEGER default 0"
            
         CASE mFldType == HB_FT_LOGICAL
            cSql += "BOOLEAN"
            
         CASE mFldType == HB_FT_MEMO
            cSql += "TEXT"
            
         CASE mFldType == HB_FT_BLOB .OR. mFldType == HB_FT_IMAGE .OR. mFldType == HB_FT_OLE
            cSql += "BLOB"
            
         CASE mFldType == HB_FT_ROWVER
            cSql += "INTEGER DEFAULT 0"
            
         OTHERWISE
            cSql += "TEXT"
      ENDCASE
   NEXT
   
   cSql += " ); "
   
   cSql += "PRAGMA temp_store = MEMORY; "
   cSql += "PRAGMA cache_size = 2000; " 
   cSql += "PRAGMA journal_mode = WAL; " 
   cSql += "PRAGMA synchronous = NORMAL; " 
   cSql += "PRAGMA auto_vacuum = INCREMENTAL; " 
   cSql += "PRAGMA page_size = 4096; " 
   cSql += "PRAGMA mmap_size = 300000000; " 
   cSql += "PRAGMA busy_timeout = 5000; " 

   nResult := sqlite3_exec( db, cSql )

   IF sqlite3_errcode( db ) > 0
      oError := ErrorNew()
      oError:GenCode     := EG_CREATE
      oError:Description := "Erro ao criar tabela/aplicar Pragmas SQLite: " + sqlite3_errmsg( db )
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

RETURN SUCCESS



STATIC FUNCTION SL3_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF !Empty( aWAData[ AREA_STMT ] )
      sqlite3_finalize( aWAData[ AREA_STMT ] )
      aWAData[ AREA_STMT ] := NIL
   ENDIF
   
   aWAData[ AREA_CACHE ]  := {}
   aWAData[ AREA_ROWBUF ] := NIL
RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION SL3_FETCH_NEXT( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL stmt := aWAData[ AREA_STMT ]
   LOCAL nCols, i, aRow, nSqlType, nFType, cVal

   IF aWAData[ AREA_FETCHED_EOF ]
      RETURN .F.
   ENDIF

   IF sqlite3_step( stmt ) == SQLITE_ROW
      nCols := sqlite3_column_count( stmt )
      aRow  := Array( nCols )
      
      FOR i := 1 TO nCols
         nSqlType := sqlite3_column_type( stmt, i )
         nFType   := aWAData[ AREA_TYPES ][ i ]

         IF nSqlType == SQLITE_NULL
            IF nFType == HB_FT_STRING
               aRow[ i ] := ""
            ELSEIF nFType == HB_FT_DOUBLE .OR. nFType == HB_FT_LONG .OR. nFType == HB_FT_INTEGER
               aRow[ i ] := 0
            ELSEIF nFType == HB_FT_LOGICAL
               aRow[ i ] := .F.
            ELSEIF nFType == HB_FT_DATE
               aRow[ i ] := CToD("")
            ELSEIF nFType == HB_FT_TIMESTAMP
               aRow[ i ] := 0
            ELSE
               aRow[ i ] := NIL
            ENDIF
            
         ELSEIF nSqlType == SQLITE_INTEGER
            aRow[ i ] := sqlite3_column_int( stmt, i )
            IF nFType == HB_FT_LOGICAL
               aRow[ i ] := ( aRow[ i ] != 0 )
            ENDIF
            
         ELSEIF nSqlType == SQLITE_FLOAT
            aRow[ i ] := Round( sqlite3_column_double( stmt, i ), aWAData[ AREA_STRUCT ][ i ][ UR_FI_DEC ] )
            
         ELSE
            // --- EXTRAÇÃO NATIVA SEM ON-DEMAND ---
            IF nFType == HB_FT_BLOB .OR. nFType == HB_FT_IMAGE .OR. nFType == HB_FT_OLE
               // Extração binária direta (evita truncamento por \0 no SQLite)[cite: 23]
               aRow[ i ] := sqlite3_column_blob( stmt, i )
            ELSE
               cVal := sqlite3_column_text( stmt, i )
               
               // Conversores Inteligentes[cite: 23]
               IF nFType == HB_FT_DATE .OR. nFType == HB_FT_TIMESTAMP
                  aRow[ i ] := StrDateRdd( cVal )
               ELSEIF nFType == HB_FT_LOGICAL
                  aRow[ i ] := strlogicrdd( cVal, .F. )
               ELSE
                  aRow[ i ] := cVal // Memos e textos normais caem aqui[cite: 23]
               ENDIF
            ENDIF
         ENDIF
      NEXT      
      
      AAdd( aWAData[ AREA_CACHE ], aRow )
      RETURN .T.
   ELSE
      aWAData[ AREA_FETCHED_EOF ] := .T.
      RETURN .F.
   ENDIF
RETURN .T.


STATIC FUNCTION SL3_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cType   := aWAData[ AREA_TYPES ][ nField ]
   
   IF aWAData[ AREA_APPEND ] .AND. !Empty( aWAData[ AREA_ROWBUF ] )
      xValue := aWAData[ AREA_ROWBUF ][ nField ]
   ELSEIF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      xValue := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nField ]
   ENDIF

   // --- MASCARAMENTO DA INFORMAÇÃO VIA PARÂMETROS GLOBAIS ---[cite: 22]
   IF cType == HB_FT_BLOB .OR. cType == HB_FT_IMAGE .OR. cType == HB_FT_OLE
      IF !t_lLoadBlobs
         xValue := "<IMAGEM/BLOB>"
      ENDIF
      
   ELSEIF cType == HB_FT_MEMO
      IF !t_lLoadMemos
         xValue := "<MEMO>"
      ENDIF
   ENDIF

RETURN SUCCESS

STATIC FUNCTION SL3_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cType   := aWAData[ AREA_TYPES ][ nField ]

   // --- SEPARAÇÃO CLARA: BLOB vs MEMO ---
   IF cType == HB_FT_BLOB .OR. cType == HB_FT_IMAGE .OR. cType == HB_FT_OLE
      IF ( ValType( xValue ) == "C" .AND. xValue == "<IMAGEM/BLOB>" ) .OR. !t_lLoadBlobs
         RETURN SUCCESS
      ENDIF
      
   ELSEIF cType == HB_FT_MEMO
      IF ( ValType( xValue ) == "C" .AND. xValue == "<MEMO>" ) .OR. !t_lLoadMemos
         RETURN SUCCESS
      ENDIF
   ENDIF

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
   
   WHILE nNewRec > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      SL3_FETCH_NEXT( nWA )
   ENDDO

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
   
   WHILE !aWAData[ AREA_FETCHED_EOF ]
      SL3_FETCH_NEXT( nWA )
   ENDDO
   
   RETURN SL3_GOTO( nWA, Len( aWAData[ AREA_CACHE ] ) )

STATIC FUNCTION SL3_GOTOID( nWA, nRecord )
   RETURN SL3_GOTO( nWA, nRecord )

STATIC FUNCTION SL3_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] )
      SL3_FLUSH( nWA )
   ENDIF
   
   WHILE nRecord > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      SL3_FETCH_NEXT( nWA )
   ENDDO
   
   IF nRecord >= 1 .AND. nRecord <= Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := nRecord
      aWAData[ AREA_EOF ] := .F.
      aWAData[ AREA_BOF ] := .F.
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL stmt

   // Executa um comando SQL direto para contar todos os registros da tabela
   stmt := sqlite3_prepare( db, "SELECT COUNT(*) FROM " + aWAData[ AREA_TABLE ] )
   
   IF !Empty( stmt )
      // Se a consulta rodar com sucesso, lê a primeira linha
      IF sqlite3_step( stmt ) == SQLITE_ROW
         // No Harbour com SQLite, o índice da coluna começa em 1
         nRecords := sqlite3_column_int( stmt, 1 )
      ELSE
         // Fallback de segurança
         nRecords := Len( aWAData[ AREA_CACHE ] )
      ENDIF
      
      // Finaliza o statement para liberar memória
      sqlite3_finalize( stmt )
   ELSE
      // Fallback de segurança se falhar a instrução SQL
      nRecords := Len( aWAData[ AREA_CACHE ] )
   ENDIF

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
   nRecNo := aWAData[ AREA_RECNO ]
RETURN SUCCESS

STATIC FUNCTION SL3_APPEND( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   HB_SYMBOL_UNUSED( nRecords )
   
   aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_APPEND ] := .T.
   aWAData[ AREA_EOF ]    := .T.
RETURN SUCCESS

STATIC FUNCTION SL3_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cSql, cFields, cValues, cWhere, i, nPosPK, oError
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL stmt, xVal, nBindIdx

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
            cValues += "?" 
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
            cSql += aWAData[ AREA_FIELDS ][ i ] + " = ?"
         NEXT
         
         cWhere := ""
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               IF i > 1
                  cWhere += " AND "
               ENDIF
               cWhere += aWAData[ AREA_PK ][ i ] + " = ?"
            ENDIF
         NEXT
         cSql += " WHERE " + cWhere
      ENDIF

      stmt := sqlite3_prepare( db, cSql )
      IF Empty( stmt )
         oError := ErrorNew()
         oError:GenCode := EG_DATATYPE
         oError:Description := "Erro SQL ao preparar flush: " + sqlite3_errmsg( db )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF

      nBindIdx := 1
      FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
         xVal := aWAData[ AREA_ROWBUF ][ i ]
         SL3_BIND_VAR( stmt, nBindIdx, xVal )
         nBindIdx++
      NEXT

      IF !aWAData[ AREA_APPEND ]
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               xVal := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ]
               SL3_BIND_VAR( stmt, nBindIdx, xVal )
               nBindIdx++
            ENDIF
         NEXT
      ENDIF

      sqlite3_step( stmt )
      sqlite3_finalize( stmt )

      IF aWAData[ AREA_APPEND ]
         AAdd( aWAData[ AREA_CACHE ], AClone( aWAData[ AREA_ROWBUF ] ) )
         aWAData[ AREA_APPEND ] := .F.
         aWAData[ AREA_RECNO ]  := Len( aWAData[ AREA_CACHE ] )
      ELSE
         aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] := AClone( aWAData[ AREA_ROWBUF ] )
      ENDIF
      
      aWAData[ AREA_ROWBUF ] := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_BIND_VAR( stmt, nIndex, xVal )
   LOCAL cType := ValType( xVal )
   IF xVal == NIL
      sqlite3_bind_null( stmt, nIndex )
   ELSEIF cType == "N"
      sqlite3_bind_double( stmt, nIndex, xVal ) 
   ELSEIF cType == "C" .OR. cType == "M"
      sqlite3_bind_text( stmt, nIndex, xVal ) 
   ELSEIF cType == "D"
     IF Empty( xVal )
        sqlite3_bind_null( stmt, nIndex )
     ELSE
        sqlite3_bind_text( stmt, nIndex, StrZero(Year(xVal),4)+"-"+StrZero(Month(xVal),2)+"-"+StrZero(Day(xVal),2) ) 
     ENDIF
   ELSEIF cType == "L"
      sqlite3_bind_text( stmt, nIndex, IIf( xVal, "yes", "no" ) ) 
   ELSE
      sqlite3_bind_null( stmt, nIndex )
   ENDIF
RETURN NIL

STATIC FUNCTION SL3_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db := aWAData[ AREA_CONN ]
   LOCAL cSql, cWhere := "", i, nPosPK, oError, stmt, xVal, nBindIdx

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
            cWhere += aWAData[ AREA_PK ][ i ] + " = ?"
         ENDIF
      NEXT
      
      cSql := "DELETE FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
      stmt := sqlite3_prepare( db, cSql )
      
      nBindIdx := 1
      FOR i := 1 TO Len( aWAData[ AREA_PK ] )
         nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
         IF nPosPK > 0
            xVal := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ]
            SL3_BIND_VAR( stmt, nBindIdx, xVal )
            nBindIdx++
         ENDIF
      NEXT
      
      sqlite3_step( stmt )
      sqlite3_finalize( stmt )
      
      ADel( aWAData[ AREA_CACHE ], aWAData[ AREA_RECNO ] )
      ASize( aWAData[ AREA_CACHE ], Len( aWAData[ AREA_CACHE ] ) - 1 )
      
      IF aWAData[ AREA_RECNO ] > Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_EOF ] := .T.
      ENDIF
   ENDIF
RETURN SUCCESS

STATIC FUNCTION SL3_RDDINFO( nIndex, cargo )
   LOCAL xRet := NIL
   DO CASE
      CASE nIndex == RDDI_TABLEEXT
         xRet := ".sqlite" 
      CASE nIndex == RDDI_MEMOEXT
         xRet := "" 
      CASE nIndex == RDDI_ORDBAGEXT
         xRet := "" 
      OTHERWISE
         xRet := UR_SUPER_RDDINFO( nIndex, cargo )
   ENDCASE
RETURN xRet

STATIC FUNCTION SL3_INFO( nWA, nIndex, cargo )
   LOCAL xRet := NIL
   DO CASE
      CASE nIndex == DBI_ISDBF
         xRet := .F.
      CASE nIndex == DBI_CANPUTREC
         xRet := .T.
      OTHERWISE
         xRet := UR_SUPER_INFO( nWA, nIndex, cargo )
   ENDCASE
RETURN xRet

// +--------------------------------------------------------------------
// +    Tabela de Roteamento de Metodos 
// +--------------------------------------------------------------------

FUNCTION SL3RDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID )
   LOCAL cSuperRDD := NIL
   LOCAL aMyFunc[ UR_METHODCOUNT ]

   aMyFunc[ UR_INIT ]     := ( @SL3_INIT() )
   aMyFunc[ UR_NEW ]      := ( @SL3_NEW() )
   aMyFunc[ UR_ADDFIELD ] := ( @SL3_ADDFIELD() ) 
   aMyFunc[ UR_CREATE ]   := ( @SL3_CREATE() ) 
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
   aMyFunc[ UR_RDDINFO ]  := ( @SL3_RDDINFO() )
   aMyFunc[ UR_INFO ]     := ( @SL3_INFO() )

   RETURN USRRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID, cSuperRDD, aMyFunc )

INIT PROC SL3_INIT_REGISTER()
   rddRegister( "SL3RDD", RDT_FULL )
RETURN

STATIC FUNCTION SL3_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL oError, nResult, db, stmt, stmtPk, nCols, i
   LOCAL aField, cTableName, cBaseType, cType
   LOCAL nFieldLen, nDec, nPos1, nPos2, nPosComma, cParams

   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ]
   ELSEIF Len( s_aConnections ) > 0
      db := s_aConnections[ Len( s_aConnections ) ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Nenhuma conexao SQLite ativa."
      oError:FileName    := aOpenInfo[ UR_OI_NAME ]
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] )
   
   aWAData[ AREA_CONN ]        := db
   aWAData[ AREA_TABLE ]       := cTableName
   aWAData[ AREA_PK ]          := {}
   aWAData[ AREA_RECNO ]       := 0
   aWAData[ AREA_APPEND ]      := .F.
   aWAData[ AREA_FIELDS ]      := {}
   aWAData[ AREA_TYPES ]       := {}
   aWAData[ AREA_CACHE ]       := {}
   aWAData[ AREA_FETCHED_EOF ] := .F.

   // Auto-Discovery da Primary Key via PRAGMA
   stmtPk := sqlite3_prepare( db, "PRAGMA table_info(" + cTableName + ")" )
   IF !Empty( stmtPk )
      WHILE sqlite3_step( stmtPk ) == SQLITE_ROW
         IF sqlite3_column_int( stmtPk, 6 ) > 0
            AAdd( aWAData[ AREA_PK ], sqlite3_column_text( stmtPk, 2 ) )
         ENDIF
      ENDDO
      sqlite3_finalize( stmtPk )
   ENDIF
   
   stmt := sqlite3_prepare( db, "SELECT * FROM " + cTableName )
   IF Empty( stmt ) .OR. sqlite3_errcode( db ) > 0
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := "Falha ao preparar leitura da tabela: " + cTableName
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   aWAData[ AREA_STMT ]        := stmt

   nCols := sqlite3_column_count( stmt )
   UR_SUPER_SETFIELDEXTENT( nWA, nCols )

   FOR i := 1 TO nCols
      cType := sqlite3_column_decltype( stmt, i )
      IF Empty( cType )
         cType := "ANY"
      ELSE
         cType := Upper( AllTrim( cType ) )
         IF At( ":", cType ) > 0
            cType := SubStr( cType, 1, At( ":", cType ) - 1 )
         ENDIF
      ENDIF

      aField := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ] := sqlite3_column_name( stmt, i )

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

      cBaseType := cType
      IF At( "(", cBaseType ) > 0
         cBaseType := SubStr( cBaseType, 1, At( "(", cBaseType ) - 1 )
      ENDIF
      cBaseType := AllTrim( cBaseType )
      
      // --- MAPEAMENTO DE TIPOS BASEADO EM GERACAMPODBF ---
      DO CASE
         // --- Números com Suporte a Decimais ---
         CASE "NUMERIC" $ cBaseType .OR. "DECIMAL" $ cBaseType .OR. "NUMBER" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
            aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 10 )
            aField[ UR_FI_DEC ]  := IIf( nPosComma > 0, nDec, 0 )

         CASE "DOUBLE" $ cBaseType .OR. "FLOAT8" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
            aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 19 )
            aField[ UR_FI_DEC ]  := IIf( nPosComma > 0, nDec, 9 )

         CASE "MONEY" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
            aField[ UR_FI_LEN ]  := 14
            aField[ UR_FI_DEC ]  := 2

         CASE "REAL" $ cBaseType .OR. "FLOAT" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
            aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 14 )
            aField[ UR_FI_DEC ]  := IIf( nPosComma > 0, nDec, 5 )

         // --- Inteiros ---
         CASE "TINYINT" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_LONG
            aField[ UR_FI_LEN ]  := 3
            aField[ UR_FI_DEC ]  := 0

         CASE "INT2" $ cBaseType .OR. "SMALLINT" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_LONG
            aField[ UR_FI_LEN ]  := 5
            aField[ UR_FI_DEC ]  := 0

         CASE "BIGINT" $ cBaseType .OR. "INT8" $ cBaseType .OR. "OID" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_LONG
            aField[ UR_FI_LEN ]  := 19
            aField[ UR_FI_DEC ]  := 0

         CASE "INT" $ cBaseType .OR. "MEDIUMINT" $ cBaseType .OR. "INTEGER" $ cBaseType .OR. "SERIAL" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_LONG
            aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 10 )
            aField[ UR_FI_DEC ]  := 0

         // --- Datas e Horas ---
         CASE "DATE" $ cBaseType .OR. "TIME" $ cBaseType .OR. "TIMESTAMP" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_DATE
            aField[ UR_FI_LEN ]  := 8
            aField[ UR_FI_DEC ]  := 0

         // --- Lógicos ---
         CASE "BOOL" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_LOGICAL
            aField[ UR_FI_LEN ]  := 1
            aField[ UR_FI_DEC ]  := 0

         // --- RowVersion ---
         CASE "ROWVERSION" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_STRING
            aField[ UR_FI_LEN ]  := 8
            aField[ UR_FI_DEC ]  := 0

         // --- Textos e Memos ---
         CASE "CLOB" $ cBaseType .OR. "LONGTEXT" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_MEMO
            aField[ UR_FI_LEN ]  := 10
            aField[ UR_FI_DEC ]  := 0

         CASE "CHAR" $ cBaseType .OR. "TEXT" $ cBaseType .OR. "VARCHAR" $ cBaseType .OR. "BPCHAR" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_STRING
            // Trunca em 250 se exceder o limite seguro ou se não for especificado
            aField[ UR_FI_LEN ]  := IIf( nFieldLen == 0, 250, IIf( nFieldLen > 250, 250, nFieldLen ) )
            aField[ UR_FI_DEC ]  := 0

         // --- Binários ---
         CASE "BYTEA" $ cBaseType .OR. "BLOB" $ cBaseType .OR. "IMAGE" $ cBaseType .OR. "VARBINARY" $ cBaseType
            aField[ UR_FI_TYPE ] := HB_FT_BLOB
            aField[ UR_FI_LEN ]  := 10
            aField[ UR_FI_DEC ]  := 0

         OTHERWISE
            aField[ UR_FI_TYPE ] := HB_FT_STRING
            aField[ UR_FI_LEN ]  := IIf( nFieldLen == 0, 10, IIf( nFieldLen > 250, 250, nFieldLen ) )
            aField[ UR_FI_DEC ]  := 0
      ENDCASE
      
      AAdd( aWAData[ AREA_FIELDS ], aField[ UR_FI_NAME ] )
      AAdd( aWAData[ AREA_TYPES ],  aField[ UR_FI_TYPE ] )
      UR_SUPER_ADDFIELD( nWA, aField )
   NEXT
    
   SL3_FETCH_NEXT( nWA )
   
   IF Len( aWAData[ AREA_CACHE ] ) > 0
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
   ELSE
      aWAData[ AREA_RECNO ] := 0
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .T.
   ENDIF

   nResult := UR_SUPER_OPEN( nWA, aOpenInfo )
RETURN nResult



// +--------------------------------------------------------------------
// +    Static Function strlogicrdd( cVAL, lDEFAULT )
// +    Conversor universal de retornos textuais/numéricos para Booleano
// +--------------------------------------------------------------------
STATIC FUNCTION strlogicrdd( cVAL, lDEFAULT )

   IF ValType( lDEFAULT ) <> "L"
      lDEFAULT := .F.
   ENDIF
   
   IF ValType( cVAL ) != "C"
      cVAL := hb_ValToStr( cVAL )
   ENDIF

   SWITCH Upper( AllTrim( cVal ) )
   CASE ".T."
   CASE "TRUE"
   CASE "YES"
   CASE "SIM"
   CASE "ON"
   CASE "Y"
   CASE "1"
   CASE "T"
   CASE "S"
      RETURN .T.
   CASE ".F."
   CASE "FALSE"
   CASE "NO"
   CASE "NAO"
   CASE "OFF"
   CASE "N"
   CASE "0"
   CASE "F"
   CASE "<NULL>"
   CASE "NULL"
   CASE "NUL"
   CASE "NIL"
      RETURN .F.
   ENDSWITCH

   RETURN lDEFAULT

// +--------------------------------------------------------------------
// +    Static Function StrDateRdd( xData )
// +    Conversor inteligente de datas universal para o RDD
// +--------------------------------------------------------------------
STATIC FUNCTION StrDateRdd( xData )
   LOCAL dRet := CToD( "" )
   LOCAL cTemp, aParts, cAno, cMes, cDia, nAno,npos,cMesStr

   IF ValType( xData ) == "D"
      RETURN xData
   ENDIF

   IF ValType( xData ) <> "C" .OR. Empty( xData ) .OR. xData == "NULL"
      RETURN dRet
   ENDIF

   xData := AllTrim( xData )
   
    // -------------------------------------------------------------------------
   // NOVO BLOCO: Trata formatos HTTP/Extensos (ex: "Fri, 05 Jun 2026..." ou "05 Junho 2026...")
   // -------------------------------------------------------------------------
   cTemp := xData
   nPos  := At( ",", cTemp )
   
   // Se tiver vírgula (ex: "Fri,"), removemos ela e o dia da semana
   IF nPos > 0
      cTemp := AllTrim( SubStr( cTemp, nPos + 1 ) )
   ENDIF
   
   // Quebra pelos espaços
   aParts := hb_ATokens( cTemp, " " )
   
   // Se tem pelo menos 3 partes (Dia, Mês, Ano), tentamos validar
   IF Len( aParts ) >= 3
      cMesStr := Upper( Left( aParts[ 2 ], 3 ) ) // Pega os 3 primeiros caracteres (JUN)
      cMes    := "00"
      
      DO CASE
         CASE cMesStr == "JAN"; cMes := "01"
         CASE cMesStr == "FEB" .OR. cMesStr == "FEV"; cMes := "02"
         CASE cMesStr == "MAR"; cMes := "03"
         CASE cMesStr == "APR" .OR. cMesStr == "ABR"; cMes := "04"
         CASE cMesStr == "MAY" .OR. cMesStr == "MAI"; cMes := "05"
         CASE cMesStr == "JUN"; cMes := "06" // Atende Jun e Junho
         CASE cMesStr == "JUL"; cMes := "07" // Atende Jul e Julho
         CASE cMesStr == "AUG" .OR. cMesStr == "AGO"; cMes := "08"
         CASE cMesStr == "SEP" .OR. cMesStr == "SET"; cMes := "09"
         CASE cMesStr == "OCT" .OR. cMesStr == "OUT"; cMes := "10"
         CASE cMesStr == "NOV"; cMes := "11"
         CASE cMesStr == "DEC" .OR. cMesStr == "DEZ"; cMes := "12"
      ENDCASE
      
      // Se encontrou um mês válido e o ano tem 4 dígitos, retorna direto
      IF cMes != "00" .AND. Len( aParts[ 3 ] ) == 4
         cDia := StrZero( Val( aParts[ 1 ] ), 2 )
         cAno := aParts[ 3 ]
         RETURN SToD( cAno + cMes + cDia )
      ENDIF
   ENDIF
   // -------------------------------------------------------------------------
  

   cTemp := StrTran( xData, "-", "/" )
   cTemp := StrTran( cTemp, ".", "/" )

   aParts := hb_ATokens( cTemp, "/" )

   IF Len( aParts ) >= 3
      IF Len( aParts[ 1 ] ) == 4
         cAno := aParts[ 1 ]
         cMes := StrZero( Val( aParts[ 2 ] ), 2 )
         cDia := StrZero( Val( Left( aParts[ 3 ], 2 ) ), 2 )
      ELSE
         cDia := StrZero( Val( aParts[ 1 ] ), 2 )
         cMes := StrZero( Val( aParts[ 2 ] ), 2 )
         cAno := Left( aParts[ 3 ], 4 )
         
         IF Len( cAno ) == 2
            nAno := Val( cAno )
            IF nAno < 50
               cAno := "20" + cAno
            ELSE
               cAno := "19" + cAno
            ENDIF
         ENDIF
      ENDIF
      
      IF cAno + cMes + cDia == "00000000"
         RETURN dRet
      ENDIF
      
      RETURN SToD( cAno + cMes + cDia )
   ELSE
      IF Len( cTemp ) == 8
         IF Val( Left( cTemp, 4 ) ) > 1900
            dRet := SToD( cTemp )
         ELSE
            dRet := SToD( Right( cTemp, 4 ) + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) )
         ENDIF
      ELSEIF Len( cTemp ) == 6
         nAno := Val( Right( cTemp, 2 ) )
         IF nAno < 50
            cAno := "20" + Right( cTemp, 2 )
         ELSE
            cAno := "19" + Right( cTemp, 2 )
         ENDIF
         dRet := SToD( cAno + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) )
      ELSE
         dRet := CToD( xData )
      ENDIF
   ENDIF

   RETURN dRet


// +--------------------------------------------------------------------
// +    Funções de Manipulação Direta de Memo/Blob
// +--------------------------------------------------------------------
FUNCTION SL3_PegarMemo( cCampo )
   LOCAL cTxt, lAnt := t_lLoadMemos
   SL3_SetLoadMemos( .T. )
   cTxt := FieldGet( FieldPos( cCampo ) )
   SL3_SetLoadMemos( lAnt )
   RETURN iif( Empty( cTxt ) .OR. cTxt == "<MEMO>", "", cTxt )
   
FUNCTION SL3_GravarMemo( cCampo, cTxt )
   LOCAL lAnt := t_lLoadMemos
   IF ValType( cTxt ) != "C"; RETURN .F.; ENDIF
   SL3_SetLoadMemos( .T. )
   FieldPut( FieldPos( cCampo ), cTxt )
   SL3_SetLoadMemos( lAnt )
   RETURN .T. 

FUNCTION SL3_PegarBlobJpg( cCampo, cDir )
   LOCAL cBin, lAnt := t_lLoadBlobs
   SL3_SetLoadBlobs( .T. )
   cBin := FieldGet( FieldPos( cCampo ) )
   SL3_SetLoadBlobs( lAnt )
   IF Empty( cBin ) .OR. cBin == "<IMAGEM/BLOB>"; RETURN .F.; ENDIF
   RETURN hb_memowrit( cDir, cBin )
   
FUNCTION SL3_GravarBlobJpg( cCampo, cDir )
   LOCAL cBin, lAnt := t_lLoadBlobs
   IF !hb_FileExists( cDir ); RETURN .F.; ENDIF
   cBin := hb_memoread( cDir )
   SL3_SetLoadBlobs( .T. )
   FieldPut( FieldPos( cCampo ), cBin )
   SL3_SetLoadBlobs( lAnt )
   RETURN .T.