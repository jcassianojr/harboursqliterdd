#include "hbclass.ch"
#include "error.ch"
#include "hbsqlit3.ch"

THREAD STATIC t_lLoadMemos := .T.
THREAD STATIC t_lLoadBlobs := .T.

FUNCTION SL3SetLoadBlobs( lLoad )
   LOCAL lOld := t_lLoadBlobs
   IF HB_ISLOGICAL( lLoad )
      t_lLoadBlobs := lLoad
   ENDIF
   RETURN lOld

FUNCTION SL3SetLoadMemos( lLoad )
   LOCAL lOld := t_lLoadMemos
   IF HB_ISLOGICAL( lLoad )
      t_lLoadMemos := lLoad
   ENDIF
   RETURN lOld

// +--------------------------------------------------------------------
// + CLASS TSL3Connection 
// +--------------------------------------------------------------------
CREATE CLASS TSL3Connection

   PROTECTED:
      VAR pDb
      VAR lTrans INIT .F.

   EXPORTED:
      VAR lError INIT .F.
      VAR nError INIT 0
      VAR cError INIT ""

      METHOD New( cDBFile, lCreateIfNotExist )
      METHOD Close()
      METHOD Destroy() INLINE ::Close()

      METHOD StartTransaction()
      METHOD Commit()
      METHOD Rollback()

      METHOD Execute( cSql )
      METHOD Query( cSql )
      
      METHOD CreateTable( cTableName, aStruct, lIncSr )
      
      METHOD CreateStatement( cSql ) 
      METHOD PrepareStatement( cSql ) INLINE ::CreateStatement( cSql )
      
      METHOD GetPointer() INLINE ::pDb
      METHOD NetErr()     INLINE ::lError
      METHOD ErrorMsg()   INLINE ::cError
      METHOD ErrorNo()    INLINE ::nError

   PROTECTED:
      METHOD SetError( nCode, cDesc )

ENDCLASS

METHOD New( cDBFile, lCreateIfNotExist ) CLASS TSL3Connection
   LOCAL nFlags := SQLITE_OPEN_READWRITE
   
   IF hb_defaultValue( lCreateIfNotExist, .F. )
      nFlags += SQLITE_OPEN_CREATE
   ENDIF

   ::pDb := sqlite3_open_v2( cDBFile, nFlags )

   IF Empty( ::pDb ) .OR. sqlite3_errcode( ::pDb ) != SQLITE_OK
      ::SetError( sqlite3_errcode( ::pDb ), "Erro ao conectar SQLite: " + sqlite3_errmsg( ::pDb ) )
   ELSE
      ::lError := .F.
      ::nError := 0
      ::cError := ""
   ENDIF

   RETURN Self

METHOD Close() CLASS TSL3Connection
   IF !Empty( ::pDb )
      sqlite3_close( ::pDb )
      ::pDb := NIL
   ENDIF
   RETURN NIL

METHOD StartTransaction() CLASS TSL3Connection
   RETURN ::Execute( "BEGIN TRANSACTION;" )

METHOD Commit() CLASS TSL3Connection
   RETURN ::Execute( "COMMIT;" )

METHOD Rollback() CLASS TSL3Connection
   RETURN ::Execute( "ROLLBACK;" )

METHOD Execute( cSql ) CLASS TSL3Connection
   LOCAL nRes

   nRes := sqlite3_exec( ::pDb, cSql )
   IF nRes != SQLITE_OK
      ::SetError( nRes, sqlite3_errmsg( ::pDb ) )
      RETURN .F.
   ENDIF

   ::lError := .F.
   RETURN .T.

METHOD Query( cSql ) CLASS TSL3Connection
   LOCAL oStmt := ::CreateStatement( cSql )
   RETURN oStmt:ExecuteQuery()

// +--------------------------------------------------------------------
// + Método CreateTable com Afinidades de Tipos Completas (DBUDIALETO / SL3RDD)
// +--------------------------------------------------------------------
METHOD CreateTable( cTableName, aStruct, lIncSr ) CLASS TSL3Connection
   LOCAL cSql, i, fldName, fldType, fldLen, fldDec
   hb_default( @lIncSr, .F. )
   
   ::Execute( "PRAGMA temp_store = MEMORY; PRAGMA cache_size = 2000; PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA auto_vacuum = INCREMENTAL; PRAGMA page_size = 4096; PRAGMA mmap_size = 300000000; PRAGMA busy_timeout = 5000;" )

   cSql := "CREATE TABLE IF NOT EXISTS " + cTableName + " ( "

   IF lIncSr
      AAdd( aStruct, { "SR_RECNO", "N", 15, 0 } )
      AAdd( aStruct, { "SR_DELETED", "C", 1, 0 } )
   ENDIF

   FOR i := 1 TO Len( aStruct )
      fldName := AllTrim( aStruct[i][1] )
      fldType := aStruct[i][2]
      fldLen  := aStruct[i][3]
      fldDec  := aStruct[i][4]

      IF i > 1
         cSql += ", "
      ENDIF
      cSql += '"' + fldName + '" '

      DO CASE
         CASE fldType == "+" .OR. fldName == "SR_RECNO"
            cSql += "INTEGER UNIQUE"
        CASE fldType == "C" .OR. fldType == "V"
            cSql += "VARCHAR(" + hb_ntos(fldLen) + ") NOT NULL DEFAULT ('')"
         CASE fldType == "D"
            cSql += "DATE NOT NULL DEFAULT ('')"
         CASE fldType == "@" .OR. fldType == "T"
            cSql += "DATETIME"
         CASE fldType == "N" .OR. fldType == "Y"
            IF fldDec > 0
               cSql += "NUMERIC(" + hb_ntos(fldLen) + "," + hb_ntos(fldDec) + ") default 0"
            ELSE
               cSql += "NUMERIC(" + hb_ntos(fldLen) + ",0) default 0"
            ENDIF
         CASE fldType == "F"
            cSql += "REAL"
         CASE fldType == "I"
            cSql += "INTEGER default 0"
         CASE fldType == "L"
            cSql += "BOOLEAN"
         CASE fldType == "M"
            cSql += "TEXT"
         CASE fldType == "Q" .OR. fldType == "W" .OR. fldType == "P" .OR. fldType == "G"
            cSql += "BLOB"
         CASE fldType == "Z"
            cSql += "INTEGER DEFAULT 0"
         OTHERWISE
            cSql += "TEXT"
      ENDCASE
   NEXT
   
   cSql += " );"
   RETURN ::Execute( cSql )

METHOD CreateStatement( cSql ) CLASS TSL3Connection
   RETURN TSL3Statement():New( Self, cSql )

METHOD SetError( nCode, cDesc ) CLASS TSL3Connection
   ::lError := .T.
   ::nError := nCode
   ::cError := cDesc
   RETURN .F.


// +--------------------------------------------------------------------
// + CLASS TSL3Statement 
// +--------------------------------------------------------------------
CREATE CLASS TSL3Statement

   PROTECTED:
      VAR oConn
      VAR pStmt
      VAR cSql

   EXPORTED:
      VAR lError INIT .F.
      VAR nError INIT 0
      VAR cError INIT ""

      METHOD New( oConn, cSql )
      
      METHOD Bind( ncParam, xValue, cFldType )
      METHOD SetString( ncParam, cValue )  INLINE ::Bind( ncParam, cValue, "C" )
      METHOD SetNumber( ncParam, nValue )  INLINE ::Bind( ncParam, nValue, "N" )
      METHOD SetDate( ncParam, dValue )    INLINE ::Bind( ncParam, dValue, "D" )
      METHOD SetBoolean( ncParam, lValue ) INLINE ::Bind( ncParam, lValue, "L" )
      METHOD SetBlob( ncParam, cValue )    INLINE ::Bind( ncParam, cValue, "G" )

      METHOD ExecuteQuery()
      METHOD ExecuteUpdate()

      METHOD Clear()
      METHOD Reuse()
      METHOD Close()
      METHOD Destroy() INLINE ::Close()
      
      METHOD GetPointer() INLINE ::pStmt

ENDCLASS

METHOD New( oConn, cSql ) CLASS TSL3Statement
   LOCAL pStmt
   
   ::oConn := oConn
   ::cSql  := cSql
   
   IF sqlite3_complete( cSql )
      pStmt := sqlite3_prepare_v2( ::oConn:GetPointer(), cSql )
      IF Empty( pStmt )
         ::lError := .T.
         ::nError := sqlite3_errcode( ::oConn:GetPointer() )
         ::cError := sqlite3_errmsg( ::oConn:GetPointer() )
      ELSE
         ::pStmt := pStmt
      ENDIF
   ELSE
      ::lError := .T.
      ::cError := "Instrução SQL incompleta."
   ENDIF

   RETURN Self

METHOD Bind( ncParam, xValue, cFldType ) CLASS TSL3Statement
   LOCAL nIndex, nRes
   LOCAL cType := ValType( xValue )
   
   IF Empty( ::pStmt ); RETURN .F.; ENDIF

   IF HB_ISNUMERIC( ncParam )
      nIndex := ncParam
   ELSE
      nIndex := sqlite3_bind_parameter_index( ::pStmt, ncParam )
   ENDIF

   IF xValue == NIL
      nRes := sqlite3_bind_null( ::pStmt, nIndex )
   ELSEIF cFldType == "G" .OR. cFldType == "W" .OR. cFldType == "P" .OR. cFldType == "Q"
      nRes := sqlite3_bind_blob( ::pStmt, nIndex, xValue )
   ELSEIF cType == "N"
      IF Int( xValue ) == xValue
         nRes := sqlite3_bind_int64( ::pStmt, nIndex, xValue )
      ELSE
         nRes := sqlite3_bind_double( ::pStmt, nIndex, xValue )
      ENDIF
   ELSEIF cType == "C" .OR. cType == "M"
      nRes := sqlite3_bind_text( ::pStmt, nIndex, xValue )
   ELSEIF cType == "D"
      IF Empty( xValue )
         nRes := sqlite3_bind_null( ::pStmt, nIndex )
      ELSE
         nRes := sqlite3_bind_text( ::pStmt, nIndex, StrZero(Year(xValue),4)+"-"+StrZero(Month(xValue),2)+"-"+StrZero(Day(xValue),2) )
      ENDIF
   ELSEIF cType == "T"
      IF Empty( xValue )
         nRes := sqlite3_bind_null( ::pStmt, nIndex )
      ELSE
         nRes := sqlite3_bind_text( ::pStmt, nIndex, StrTran( hb_TSToStr( xValue ), "T", " " ) )
      ENDIF
   ELSEIF cType == "L"
      nRes := sqlite3_bind_text( ::pStmt, nIndex, iif( xValue, "1", "0" ) )
   ELSE
      nRes := sqlite3_bind_null( ::pStmt, nIndex )
   ENDIF

   IF nRes != SQLITE_OK
      ::lError := .T.
      ::nError := nRes
      ::cError := "Erro no Bind do Parâmetro " + hb_ntos(nIndex)
      RETURN .F.
   ENDIF
   RETURN .T.

METHOD ExecuteQuery() CLASS TSL3Statement
   LOCAL oRS
   IF Empty( ::pStmt ); RETURN NIL; ENDIF
   
   oRS := TSL3ResultSet():New( Self )
   RETURN oRS

METHOD ExecuteUpdate() CLASS TSL3Statement
   LOCAL nRes, nChanges := 0
   IF Empty( ::pStmt ); RETURN 0; ENDIF
   
   nRes := sqlite3_step( ::pStmt )
   IF nRes == SQLITE_DONE .OR. nRes == SQLITE_OK
      nChanges := sqlite3_changes( ::oConn:GetPointer() )
      ::lError := .F.
   ELSE
      ::lError := .T.
      ::nError := nRes
      ::cError := sqlite3_errmsg( ::oConn:GetPointer() )
   ENDIF
   
   ::Reuse() 
   RETURN nChanges

METHOD Reuse() CLASS TSL3Statement
   IF !Empty( ::pStmt )
      sqlite3_reset( ::pStmt )
   ENDIF
   RETURN Self

METHOD Clear() CLASS TSL3Statement
   IF !Empty( ::pStmt )
      sqlite3_clear_bindings( ::pStmt )
   ENDIF
   RETURN Self

METHOD Close() CLASS TSL3Statement
   IF !Empty( ::pStmt )
      sqlite3_finalize( ::pStmt )
      ::pStmt := NIL
   ENDIF
   RETURN NIL


// +--------------------------------------------------------------------
// + CLASS TSL3ResultSet (Com parser robusto de metadados baseado na SL3RDD)
// +--------------------------------------------------------------------
CREATE CLASS TSL3ResultSet

   PROTECTED:
      VAR oStmt
      VAR pStmt
      VAR aStruct
      VAR lEof INIT .F.
      VAR nRecno INIT 0

   EXPORTED:
      VAR nCols INIT 0

      METHOD New( oStmt )
      METHOD Fetch()
      METHOD Next() INLINE ::Fetch()
      
      METHOD FieldGet( nCol )
      METHOD GetRow()
      METHOD GetBlankRow()
      
      METHOD Struct()    INLINE ::aStruct
      METHOD Eof()       INLINE ::lEof
      METHOD FCount()    INLINE ::nCols
      METHOD FieldName( nCol ) 
      METHOD FieldType( nCol )
      METHOD FieldPos( cName )

      METHOD Close()
      METHOD Destroy() INLINE ::Close()

   PROTECTED:
      METHOD LoadMetadata()

ENDCLASS

METHOD New( oStmt ) CLASS TSL3ResultSet
   ::oStmt := oStmt
   ::pStmt := oStmt:GetPointer()
   
   ::LoadMetadata()
   RETURN Self

METHOD LoadMetadata() CLASS TSL3ResultSet
   LOCAL i, cName, cDeclType, cBaseType, cParams
   LOCAL nLen, nDec, nPos1, nPos2, nPosComma
   LOCAL cType
   
   ::nCols   := sqlite3_column_count( ::pStmt )
   ::aStruct := Array( ::nCols )
   
   FOR i := 1 TO ::nCols
      cName     := sqlite3_column_name( ::pStmt, i - 1 )
      cDeclType := Upper( AllTrim( sqlite3_column_decltype( ::pStmt, i - 1 ) ) )
      
      IF Empty( cDeclType ); cDeclType := "ANY"; ENDIF
      
      IF At( ":", cDeclType ) > 0
         cDeclType := SubStr( cDeclType, 1, At( ":", cDeclType ) - 1 )
      ENDIF

      nLen := 0; nDec := 0
      nPos1 := At( "(", cDeclType )
      nPos2 := At( ")", cDeclType )

      IF nPos1 > 0 .AND. nPos2 > nPos1
         cParams := SubStr( cDeclType, nPos1 + 1, nPos2 - nPos1 - 1 )
         nPosComma := At( ",", cParams )
         IF nPosComma > 0
            nLen := Val( SubStr( cParams, 1, nPosComma - 1 ) )
            nDec := Val( SubStr( cParams, nPosComma + 1 ) )
         ELSE
            nLen := Val( cParams )
         ENDIF
      ENDIF

      cBaseType := cDeclType
      IF nPos1 > 0
         cBaseType := AllTrim( SubStr( cBaseType, 1, nPos1 - 1 ) )
      ENDIF

      DO CASE
         CASE "NUMERIC" $ cBaseType .OR. "DECIMAL" $ cBaseType .OR. "NUMBER" $ cBaseType
            cType := "N"; nLen := iif( nLen > 0, nLen, 10 )
         CASE "DOUBLE" $ cBaseType .OR. "FLOAT8" $ cBaseType
            cType := "N"; nLen := iif( nLen > 0, nLen, 19 ); nDec := iif( nDec > 0, nDec, 9 )
         CASE "MONEY" $ cBaseType
            cType := "N"; nLen := 14; nDec := 2
         CASE "REAL" $ cBaseType .OR. "FLOAT" $ cBaseType
            cType := "N"; nLen := iif( nLen > 0, nLen, 14 ); nDec := iif( nDec > 0, nDec, 5 )
         CASE "TINYINT" $ cBaseType
            cType := "N"; nLen := 3
         CASE "INT2" $ cBaseType .OR. "SMALLINT" $ cBaseType
            cType := "N"; nLen := 5
         CASE "BIGINT" $ cBaseType .OR. "INT8" $ cBaseType .OR. "OID" $ cBaseType
            cType := "N"; nLen := 19
         CASE "INT" $ cBaseType .OR. "MEDIUMINT" $ cBaseType .OR. "INTEGER" $ cBaseType .OR. "SERIAL" $ cBaseType
            cType := "N"; nLen := iif( nLen > 0, nLen, 10 )
         CASE "TIMESTAMP" $ cBaseType .OR. "DATETIME" $ cBaseType
            cType := "@"; nLen := 8
         CASE "TIME" $ cBaseType
            cType := "C"; nLen := 8
         CASE "DATE" $ cBaseType
            cType := "D"; nLen := 8
         CASE "BOOL" $ cBaseType
            cType := "L"; nLen := 1
         CASE "ROWVERSION" $ cBaseType
            cType := "C"; nLen := 8
         CASE "CLOB" $ cBaseType .OR. "LONGTEXT" $ cBaseType
            cType := "M"; nLen := 10
         CASE "CHAR" $ cBaseType .OR. "TEXT" $ cBaseType .OR. "VARCHAR" $ cBaseType .OR. "BPCHAR" $ cBaseType
            cType := "C"; nLen := iif( nLen == 0, 250, iif( nLen > 250, 250, nLen ) )
         CASE "BYTEA" $ cBaseType .OR. "BLOB" $ cBaseType .OR. "IMAGE" $ cBaseType .OR. "VARBINARY" $ cBaseType
            cType := "G"; nLen := 10
         OTHERWISE
            cType := "C"; nLen := iif( nLen == 0, 10, iif( nLen > 250, 250, nLen ) )
      ENDCASE
      
      ::aStruct[ i ] := { cName, cType, nLen, nDec }
   NEXT
   RETURN NIL

METHOD Fetch() CLASS TSL3ResultSet
   LOCAL nRes, lRet
   nRes := sqlite3_step( ::pStmt )
   
   IF nRes == SQLITE_ROW
      ::lEof := .F.
      ::nRecno++
      lRet := .T.
   ELSE
      ::lEof := .T.
      lRet := .F.
   ENDIF
   
   RETURN lRet

METHOD FieldGet( nCol ) CLASS TSL3ResultSet
   LOCAL cType, nSqlType, xVal, cVal

   IF nCol < 1 .OR. nCol > ::nCols; RETURN NIL; ENDIF

   cType    := ::aStruct[ nCol ][ 2 ]
   nSqlType := sqlite3_column_type( ::pStmt, nCol - 1 )

   IF nSqlType == SQLITE_NULL
      IF cType == "C" .OR. cType == "M"; RETURN ""; ENDIF
      IF cType == "N"; RETURN 0; ENDIF
      IF cType == "L"; RETURN .F.; ENDIF
      IF cType == "D"; RETURN CToD(""); ENDIF
      IF cType == "@"; RETURN hb_SToT(""); ENDIF
      RETURN NIL
   ENDIF

   DO CASE
      CASE cType == "N"
         IF nSqlType == SQLITE_FLOAT
            xVal := Round( sqlite3_column_double( ::pStmt, nCol - 1 ), ::aStruct[ nCol ][ 4 ] )
         ELSE
            xVal := sqlite3_column_int64( ::pStmt, nCol - 1 )
         ENDIF

      CASE cType == "L"
         cVal := sqlite3_column_text( ::pStmt, nCol - 1 )
         xVal := strlogicClasse( cVal, .F. )

      CASE cType == "D"
         cVal := sqlite3_column_text( ::pStmt, nCol - 1 )
         xVal := StrDateClass( cVal )

    CASE cType == "@" .OR. cType == "T"
         cVal := sqlite3_column_text( ::pStmt, nCol - 1 )
         xVal := UniversalDateTime( cVal ) // <-- INJEÇÃO: Conversor Universal de Data e Hora
     
      CASE cType == "G" .OR. cType == "W"
         IF !t_lLoadBlobs
            xVal := "<IMAGEM/BLOB>"
         ELSE
            xVal := sqlite3_column_blob( ::pStmt, nCol - 1 )
         ENDIF

      CASE cType == "C" .OR. cType == "M"
         IF cType == "M" .AND. !t_lLoadMemos
            xVal := "<MEMO>"
         ELSE
            xVal := sqlite3_column_text( ::pStmt, nCol - 1 )
         ENDIF

      OTHERWISE
         xVal := sqlite3_column_text( ::pStmt, nCol - 1 )
   ENDCASE

   RETURN xVal

METHOD GetRow() CLASS TSL3ResultSet
   LOCAL aRow, aOld, i
   
   IF ::lEof; RETURN ::GetBlankRow(); ENDIF
   
   aRow := Array( ::nCols )
   aOld := Array( ::nCols )
   
   FOR i := 1 TO ::nCols
      aRow[ i ] := ::FieldGet( i )
      aOld[ i ] := aRow[ i ]
   NEXT
   
   RETURN TSL3Row():New( aRow, aOld, ::aStruct )

METHOD GetBlankRow() CLASS TSL3ResultSet
   LOCAL aRow := Array( ::nCols )
   LOCAL aOld := Array( ::nCols )
   LOCAL i, cType
   
   FOR i := 1 TO ::nCols
      cType := ::aStruct[ i ][ 2 ]
      DO CASE
         CASE cType == "C" .OR. cType == "M" .OR. cType == "G"
            aRow[ i ] := ""
         CASE cType == "N" .OR. cType == "F"
            aRow[ i ] := 0
         CASE cType == "L"
            aRow[ i ] := .F.
         CASE cType == "D"
            aRow[ i ] := hb_SToD()
         CASE cType == "@" .OR. cType == "T"
            aRow[ i ] := hb_SToT()
         OTHERWISE
            aRow[ i ] := NIL
      ENDCASE
      aOld[ i ] := aRow[ i ]
   NEXT
   
   RETURN TSL3Row():New( aRow, aOld, ::aStruct )

METHOD FieldName( nCol ) CLASS TSL3ResultSet
   IF nCol >= 1 .AND. nCol <= ::nCols
      RETURN ::aStruct[ nCol ][ 1 ]
   ENDIF
   RETURN ""

METHOD FieldType( nCol ) CLASS TSL3ResultSet
   IF nCol >= 1 .AND. nCol <= ::nCols
      RETURN ::aStruct[ nCol ][ 2 ]
   ENDIF
   RETURN "U"

METHOD FieldPos( cName ) CLASS TSL3ResultSet
   RETURN AScan( ::aStruct, {| x | Upper( x[ 1 ] ) == Upper( RTrim( cName ) ) } )

METHOD Close() CLASS TSL3ResultSet
   ::oStmt:Reuse() 
   RETURN NIL


// +--------------------------------------------------------------------
// + CLASS TSL3Row 
// +--------------------------------------------------------------------
CREATE CLASS TSL3Row

   VAR aRow
   VAR aOld
   VAR aStruct

   METHOD New( row, old, struct )

   METHOD FCount()              INLINE Len( ::aRow )
   METHOD FieldGet( nField, lOld )
   METHOD FieldPut( nField, Value )
   METHOD FieldName( nField )
   METHOD FieldPos( cField )
   METHOD FieldType( nField )
   METHOD Changed( nField )     INLINE ! ( ::aRow[ nField ] == ::aOld[ nField ] )

ENDCLASS

METHOD New( row, old, struct ) CLASS TSL3Row
   ::aRow    := row
   ::aOld    := old
   ::aStruct := struct
   RETURN Self

METHOD FieldGet( nField, lOld ) CLASS TSL3Row
   IF HB_ISSTRING( nField )
      nField := ::FieldPos( nField )
   ENDIF

   IF HB_ISLOGICAL( lOld ) .AND. lOld
      IF nField >= 1 .AND. nField <= Len( ::aOld )
         RETURN ::aOld[ nField ]
      ENDIF
   ELSE
      IF nField >= 1 .AND. nField <= Len( ::aRow )
         RETURN ::aRow[ nField ]
      ENDIF
   ENDIF
   RETURN NIL

METHOD FieldPut( nField, Value ) CLASS TSL3Row
   LOCAL cType

   IF HB_ISSTRING( nField )
      nField := ::FieldPos( nField )
   ENDIF

   IF nField >= 1 .AND. nField <= Len( ::aRow )
      cType := ::FieldType( nField )
      
      IF cType == "G" .AND. ( ( ValType( Value ) == "C" .AND. Value == "<IMAGEM/BLOB>" ) .OR. !t_lLoadBlobs )
         RETURN Value
      ENDIF
      IF cType == "M" .AND. ( ( ValType( Value ) == "C" .AND. Value == "<MEMO>" ) .OR. !t_lLoadMemos )
         RETURN Value
      ENDIF
      
      RETURN ::aRow[ nField ] := Value
   ENDIF
   RETURN NIL

METHOD FieldName( nField ) CLASS TSL3Row
   IF HB_ISSTRING( nField )
      nField := ::FieldPos( nField )
   ENDIF
   IF nField >= 1 .AND. nField <= Len( ::aStruct )
      RETURN ::aStruct[ nField ][ 1 ]
   ENDIF
   RETURN NIL

METHOD FieldPos( cField ) CLASS TSL3Row
   cField := RTrim( Upper( cField ) )
   RETURN AScan( ::aStruct, {| x | Upper( x[ 1 ] ) == cField } )

METHOD FieldType( nField ) CLASS TSL3Row
   IF HB_ISSTRING( nField )
      nField := ::FieldPos( nField )
   ENDIF
   IF nField >= 1 .AND. Len( ::aStruct ) >= nField
      RETURN ::aStruct[ nField ][ 2 ]
   ENDIF
   RETURN NIL


// +--------------------------------------------------------------------
// + Funções Auxiliares Universais
// +--------------------------------------------------------------------
STATIC FUNCTION strlogicClasse( cVAL, lDEFAULT )
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

STATIC FUNCTION StrDateClass( xData ) 
   LOCAL dRet := CToD( "" )
   LOCAL cTemp, aParts, cAno, cMes, cDia, nAno

   IF ValType( xData ) == "D"
      RETURN xData
   ENDIF

   IF ValType( xData ) <> "C" .OR. Empty( xData ) .OR. xData == "NULL"
      RETURN dRet
   ENDIF

   cTemp := StrTran( AllTrim( xData ), "-", "/" )
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
            cAno := iif( nAno < 50, "20" + cAno, "19" + cAno )
         ENDIF
      ENDIF
      IF cAno + cMes + cDia == "00000000"
         RETURN dRet
      ENDIF
      RETURN SToD( cAno + cMes + cDia )
   ELSE
      IF Len( cTemp ) == 8
         dRet := iif( Val( Left( cTemp, 4 ) ) > 1900, SToD( cTemp ), SToD( Right( cTemp, 4 ) + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) ) )
      ELSEIF Len( cTemp ) == 6
         nAno := Val( Right( cTemp, 2 ) )
         cAno := iif( nAno < 50, "20" + Right( cTemp, 2 ), "19" + Right( cTemp, 2 ) )
         dRet := SToD( cAno + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) )
      ELSE
         dRet := CToD( xData )
      ENDIF
   ENDIF
   RETURN dRet
   
    // +--------------------------------------------------------------------
// +  Função: UniversalDateTime
// +  Objetivo: Tratar datas complexas mantendo e corrigindo o horário
// +  Retorna: Timestamp nativo (T) de alta precisão
// +--------------------------------------------------------------------
STATIC FUNCTION UniversalDateTime( xData )

   LOCAL cStr, cDataLimpa, aParts, i, dData
   LOCAL cTime := "00:00:00"
   LOCAL nHour := 0, nMin := 0, nSec := 0

   // 1. Já é Data ou Timestamp? Trata a conversão direta
   IF ValType( xData ) == "T"
      RETURN xData
   ELSEIF ValType( xData ) == "D"
      RETURN hb_DateTime( Year(xData), Month(xData), Day(xData) )
   ENDIF

   // 2. Barreira para nulos ou variáveis não suportadas
   IF ValType( xData ) <> "C" .OR. Empty( xData )
      RETURN hb_DateTime( 0, 0, 0 )
   ENDIF

   // 3. Limpa espaços e conserta erros como ";" ou tags ISO "T"
   cStr := AllTrim( xData )
   cStr := StrTran( cStr, ";", ":" )
   cStr := StrTran( cStr, "T", " " )

   aParts := hb_ATokens( cStr, " " )
   cDataLimpa := ""

   // 4. Caçador de Horários
   FOR i := 1 TO Len( aParts )
      IF ":" $ aParts[i] .AND. Val( StrTran( aParts[i], ":", "" ) ) >= 0
         cTime := aParts[i] // Isola apenas a hora encontrada
      ELSE
         cDataLimpa += aParts[i] + " " // Reconstrói string base só da data
      ENDIF
   NEXT

   cDataLimpa := AllTrim( cDataLimpa )
   
   // 5. Utiliza o motor otimizado para extrair o calendário válido
   dData := StrDateClass( cDataLimpa )

   // Fallback se a rotina retornar vazio, checa direto via Harbour CToD
   IF Empty( dData ) .AND. !Empty( CToD( cDataLimpa ) )
      dData := CToD( cDataLimpa )
   ENDIF

   IF Empty( dData )
      RETURN hb_DateTime( 0, 0, 0 )
   ENDIF

   // 6. Separa e converte as partes do Horário
   aParts := hb_ATokens( cTime, ":" )
   IF Len( aParts ) >= 1; nHour := Val( aParts[1] ); ENDIF
   IF Len( aParts ) >= 2; nMin  := Val( aParts[2] ); ENDIF
   IF Len( aParts ) >= 3; nSec  := Val( aParts[3] ); ENDIF

   // 7. Retorna o Objeto Timestamp Oficial
   RETURN hb_DateTime( Year( dData ), Month( dData ), Day( dData ), nHour, nMin, nSec ) 
   