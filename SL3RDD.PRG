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
         CASE mFldType == HB_FT_AUTOINC .OR. mFldNm == "SR_RECNO"
            cSql += "INTEGER UNIQUE" 
         CASE mFldType == HB_FT_STRING .OR. mFldType == HB_FT_ANY
            cSql += "TEXT NOT NULL DEFAULT ('')" 
         CASE mFldType == HB_FT_DATE
            cSql += "DATE NOT NULL DEFAULT ('')"
         CASE mFldType == HB_FT_TIMESTAMP .OR. mFldType == HB_FT_TIME
            cSql += "DATETIME"
         CASE mFldType == HB_FT_DOUBLE .OR. mFldType == HB_FT_INTEGER .OR. mFldType == HB_FT_LONG
            IF mFldDec > 0
               cSql += "FLOAT default 0" 
            ELSE
               cSql += "INTEGER default 0"
            ENDIF
         CASE mFldType == HB_FT_CURRENCY
            IF mFldDec > 0
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + "," + hb_ntos( mFldDec ) + ")"
            ELSE
               cSql += "NUMERIC(" + hb_ntos( mFldLen ) + ")"
            ENDIF
         CASE mFldType == HB_FT_LOGICAL
            cSql += "BOOLEAN"
         CASE mFldType == HB_FT_MEMO
            cSql += "TEXT"
         CASE mFldType == HB_FT_BLOB
            cSql += "BLOB"
         OTHERWISE
            cSql += "TEXT"
      ENDCASE
   NEXT
   
   cSql += " )"
   nResult := sqlite3_exec( db, cSql )

   IF sqlite3_errcode( db ) > 0
      oError := ErrorNew()
      oError:GenCode     := EG_CREATE
      oError:Description := "Erro ao criar tabela SQLite: " + sqlite3_errmsg( db )
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

RETURN SUCCESS

STATIC FUNCTION SL3_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL oError, nResult, db, stmt, nCols, i
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
   
   stmt := sqlite3_prepare( db, "SELECT * FROM " + cTableName )
   IF Empty( stmt ) .OR. sqlite3_errcode( db ) > 0
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := "Falha ao preparar leitura da tabela: " + cTableName
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   aWAData[ AREA_CONN ]        := db
   aWAData[ AREA_TABLE ]       := cTableName
   aWAData[ AREA_PK ]          := {}
   aWAData[ AREA_RECNO ]       := 0
   aWAData[ AREA_APPEND ]      := .F.
   aWAData[ AREA_FIELDS ]      := {}
   aWAData[ AREA_TYPES ]       := {}
   aWAData[ AREA_CACHE ]       := {}
   aWAData[ AREA_STMT ]        := stmt
   aWAData[ AREA_FETCHED_EOF ] := .F.

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
      
      IF "INT" $ cBaseType .OR. cBaseType == "I"
         aField[ UR_FI_TYPE ] := HB_FT_LONG
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 10 )
         aField[ UR_FI_DEC ]  := 0
      ELSEIF "REAL" $ cBaseType .OR. "NUM" $ cBaseType .OR. "DOUB" $ cBaseType .OR. cBaseType == "N" .OR. cBaseType == "F"
         aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 18 )
         aField[ UR_FI_DEC ]  := IIf( nPos1 > 0, nDec, 4 )
      ELSEIF "DATE" $ cBaseType .OR. cBaseType == "D"
         aField[ UR_FI_TYPE ] := HB_FT_DATE
         aField[ UR_FI_LEN ]  := 8
         aField[ UR_FI_DEC ]  := 0
      ELSEIF "BOOL" $ cBaseType .OR. cBaseType == "L"
         aField[ UR_FI_TYPE ] := HB_FT_LOGICAL
         aField[ UR_FI_LEN ]  := 1
         aField[ UR_FI_DEC ]  := 0
      ELSEIF cBaseType == "B"
         aField[ UR_FI_TYPE ] := HB_FT_DOUBLE
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 18 )
         aField[ UR_FI_DEC ]  := IIf( nPos1 > 0, nDec, 4 )
      ELSE
         aField[ UR_FI_TYPE ] := HB_FT_STRING
         aField[ UR_FI_LEN ]  := IIf( nFieldLen > 0, nFieldLen, 255 )
         aField[ UR_FI_DEC ]  := 0
      ENDIF
      
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
            ELSE
               aRow[ i ] := NIL
            ENDIF
         ELSEIF nSqlType == SQLITE_INTEGER
            aRow[ i ] := sqlite3_column_int( stmt, i )
            IF nFType == HB_FT_LOGICAL
               aRow[ i ] := ( aRow[ i ] != 0 )
            ENDIF
         ELSEIF nSqlType == SQLITE_FLOAT
            aRow[ i ] := sqlite3_column_double( stmt, i )
         ELSE
            cVal := sqlite3_column_text( stmt, i )
            IF nFType == HB_FT_DATE
               aRow[ i ] := SToD( StrTran( cVal, "-", "" ) )
            ELSEIF nFType == HB_FT_LOGICAL
               aRow[ i ] := ( Lower( cVal ) == "yes" .OR. Lower( cVal ) == "true" .OR. cVal == "1" )
            ELSE
               aRow[ i ] := cVal
            ENDIF
         ENDIF
      NEXT
      
      AAdd( aWAData[ AREA_CACHE ], aRow )
      RETURN .T.
   ELSE
      aWAData[ AREA_FETCHED_EOF ] := .T.
      RETURN .F.
   ENDIF
RETURN .T.  // <- CORRIGIDO: Adicionado o RETURN final que faltava

STATIC FUNCTION SL3_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF !Empty( aWAData[ AREA_STMT ] )
      sqlite3_finalize( aWAData[ AREA_STMT ] )
      aWAData[ AREA_STMT ] := NIL
   ENDIF
   
   aWAData[ AREA_CACHE ]  := {}
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
         sqlite3_bind_text( stmt, nIndex, "0000-00-00" )
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