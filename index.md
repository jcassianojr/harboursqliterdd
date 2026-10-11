# 📘 Harbour Documentation

**Generated:** 10/11/2026
**Total symbols:** 119

## 📑 Table of Contents

- [SL3SetLoadBlobs](#sl3setloadblobs) `[function]`
- [SL3SetLoadMemos](#sl3setloadmemos) `[function]`
- [New](#new) `[method]`
- [Close](#close) `[method]`
- [Destroy](#destroy) `[method]`
- [StartTransaction](#starttransaction) `[method]`
- [Commit](#commit) `[method]`
- [Rollback](#rollback) `[method]`
- [Execute](#execute) `[method]`
- [Query](#query) `[method]`
- [CreateTable](#createtable) `[method]`
- [CreateStatement](#createstatement) `[method]`
- [PrepareStatement](#preparestatement) `[method]`
- [GetPointer](#getpointer) `[method]`
- [NetErr](#neterr) `[method]`
- [ErrorMsg](#errormsg) `[method]`
- [ErrorNo](#errorno) `[method]`
- [SetError](#seterror) `[method]`
- [New](#new) `[method]`
- [Close](#close) `[method]`
- [StartTransaction](#starttransaction) `[method]`
- [Commit](#commit) `[method]`
- [Rollback](#rollback) `[method]`
- [Execute](#execute) `[method]`
- [Query](#query) `[method]`
- [CreateTable](#createtable) `[method]`
- [CreateStatement](#createstatement) `[method]`
- [SetError](#seterror) `[method]`
- [New](#new) `[method]`
- [Bind](#bind) `[method]`
- [SetString](#setstring) `[method]`
- [SetNumber](#setnumber) `[method]`
- [SetDate](#setdate) `[method]`
- [SetBoolean](#setboolean) `[method]`
- [SetBlob](#setblob) `[method]`
- [ExecuteQuery](#executequery) `[method]`
- [ExecuteUpdate](#executeupdate) `[method]`
- [Clear](#clear) `[method]`
- [Reuse](#reuse) `[method]`
- [Close](#close) `[method]`
- [Destroy](#destroy) `[method]`
- [GetPointer](#getpointer) `[method]`
- [New](#new) `[method]`
- [Bind](#bind) `[method]`
- [ExecuteQuery](#executequery) `[method]`
- [ExecuteUpdate](#executeupdate) `[method]`
- [Reuse](#reuse) `[method]`
- [Clear](#clear) `[method]`
- [Close](#close) `[method]`
- [New](#new) `[method]`
- [Fetch](#fetch) `[method]`
- [Next](#next) `[method]`
- [FieldGet](#fieldget) `[method]`
- [GetRow](#getrow) `[method]`
- [GetBlankRow](#getblankrow) `[method]`
- [Struct](#struct) `[method]`
- [Eof](#eof) `[method]`
- [FCount](#fcount) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldType](#fieldtype) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [Close](#close) `[method]`
- [Destroy](#destroy) `[method]`
- [LoadMetadata](#loadmetadata) `[method]`
- [New](#new) `[method]`
- [LoadMetadata](#loadmetadata) `[method]`
- [Fetch](#fetch) `[method]`
- [FieldGet](#fieldget) `[method]`
- [GetRow](#getrow) `[method]`
- [GetBlankRow](#getblankrow) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldType](#fieldtype) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [Close](#close) `[method]`
- [New](#new) `[method]`
- [FCount](#fcount) `[method]`
- [FieldGet](#fieldget) `[method]`
- [FieldPut](#fieldput) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldType](#fieldtype) `[method]`
- [Changed](#changed) `[method]`
- [New](#new) `[method]`
- [FieldGet](#fieldget) `[method]`
- [FieldPut](#fieldput) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldType](#fieldtype) `[method]`
- [AREA_CONN](#area_conn) `[constant]`
- [AREA_TABLE](#area_table) `[constant]`
- [AREA_PK](#area_pk) `[constant]`
- [AREA_CACHE](#area_cache) `[constant]`
- [AREA_RECNO](#area_recno) `[constant]`
- [AREA_ROWBUF](#area_rowbuf) `[constant]`
- [AREA_APPEND](#area_append) `[constant]`
- [AREA_EOF](#area_eof) `[constant]`
- [AREA_BOF](#area_bof) `[constant]`
- [AREA_FIELDS](#area_fields) `[constant]`
- [AREA_STRUCT](#area_struct) `[constant]`
- [AREA_STMT](#area_stmt) `[constant]`
- [AREA_FETCHED_EOF](#area_fetched_eof) `[constant]`
- [AREA_TYPES](#area_types) `[constant]`
- [AREA_STMT_UPDATE](#area_stmt_update) `[constant]`
- [AREA_STMT_DELETE](#area_stmt_delete) `[constant]`
- [AREA_LEN](#area_len) `[constant]`
- [DBSL3CONNECTION](#dbsl3connection) `[function]`
- [DBSL3CLEARCONNECTION](#dbsl3clearconnection) `[function]`
- [DBSL3BEGINTRANS](#dbsl3begintrans) `[function]`
- [DBSL3COMMIT](#dbsl3commit) `[function]`
- [DBSL3ROLLBACK](#dbsl3rollback) `[function]`
- [SL3_SetLoadBlobs](#sl3_setloadblobs) `[function]`
- [SL3_SetLoadMemos](#sl3_setloadmemos) `[function]`
- [DBSL3GETHANDLE](#dbsl3gethandle) `[function]`
- [SL3_SETPK](#sl3_setpk) `[function]`
- [SL3RDD_GETFUNCTABLE](#sl3rdd_getfunctable) `[function]`
- [SL3_PegarMemo](#sl3_pegarmemo) `[function]`
- [SL3_GravarMemo](#sl3_gravarmemo) `[function]`
- [SL3_PegarBlobJpg](#sl3_pegarblobjpg) `[function]`
- [SL3_GravarBlobJpg](#sl3_gravarblobjpg) `[function]`

---

## SL3SetLoadBlobs
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 8)

---

## SL3SetLoadMemos
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 15)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 36)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 37)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 38)

---

## StartTransaction
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 40)

---

## Commit
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 41)

---

## Rollback
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 42)

---

## Execute
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 44)

---

## Query
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 45)

---

## CreateTable
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 47)

---

## CreateStatement
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 49)

---

## PrepareStatement
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 50)

---

## GetPointer
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 52)

---

## NetErr
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 53)

---

## ErrorMsg
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 54)

---

## ErrorNo
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 55)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 58)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 62)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 81)

---

## StartTransaction
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 88)

---

## Commit
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 91)

---

## Rollback
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 94)

---

## Execute
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 97)

---

## Query
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 109)

---

## CreateTable
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 116)

---

## CreateStatement
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 175)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 178)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 200)

---

## Bind
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 202)

---

## SetString
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 203)

---

## SetNumber
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 204)

---

## SetDate
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 205)

---

## SetBoolean
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 206)

---

## SetBlob
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 207)

---

## ExecuteQuery
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 209)

---

## ExecuteUpdate
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 210)

---

## Clear
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 212)

---

## Reuse
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 213)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 214)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 215)

---

## GetPointer
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 217)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 221)

---

## Bind
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 243)

---

## ExecuteQuery
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 293)

---

## ExecuteUpdate
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 300)

---

## Reuse
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 317)

---

## Clear
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 323)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 329)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 352)

---

## Fetch
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 353)

---

## Next
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 354)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 356)

---

## GetRow
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 357)

---

## GetBlankRow
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 358)

---

## Struct
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 360)

---

## Eof
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 361)

---

## FCount
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 362)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 363)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 364)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 365)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 367)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 368)

---

## LoadMetadata
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 371)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 375)

---

## LoadMetadata
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 382)

---

## Fetch
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 461)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 476)

---

## GetRow
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 533)

---

## GetBlankRow
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 548)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 574)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 580)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 586)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 589)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 603)

---

## FCount
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 605)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 606)

---

## FieldPut
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 607)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 608)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 609)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 610)

---

## Changed
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 611)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 615)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 621)

---

## FieldPut
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 637)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 658)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 667)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\sqliterdd\sl3class.prg` (line 671)

---

## AREA_CONN
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 9)

### 💎 Value
```harbour
"1"
```

---

## AREA_TABLE
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 10)

### 💎 Value
```harbour
"2"
```

---

## AREA_PK
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 11)

### 💎 Value
```harbour
"3"
```

---

## AREA_CACHE
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 12)

### 💎 Value
```harbour
"4"
```

---

## AREA_RECNO
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 13)

### 💎 Value
```harbour
"5"
```

---

## AREA_ROWBUF
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 14)

### 💎 Value
```harbour
"6"
```

---

## AREA_APPEND
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 15)

### 💎 Value
```harbour
"7"
```

---

## AREA_EOF
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 16)

### 💎 Value
```harbour
"8"
```

---

## AREA_BOF
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 17)

### 💎 Value
```harbour
"9"
```

---

## AREA_FIELDS
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 18)

### 💎 Value
```harbour
"10"
```

---

## AREA_STRUCT
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 19)

### 💎 Value
```harbour
"11"
```

---

## AREA_STMT
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 20)

### 💎 Value
```harbour
"12  "
```

---

## AREA_FETCHED_EOF
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 21)

### 💎 Value
```harbour
"13  "
```

---

## AREA_TYPES
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 22)

### 💎 Value
```harbour
"14"
```

---

## AREA_STMT_UPDATE
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 23)

### 💎 Value
```harbour
"15 // Melhoria: Cache de statement para UPDATE"
```

---

## AREA_STMT_DELETE
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 24)

### 💎 Value
```harbour
"16 // Melhoria: Cache de statement para DELETE"
```

---

## AREA_LEN
**Type:** `constant`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 25)

### 💎 Value
```harbour
"16"
```

---

## DBSL3CONNECTION
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 37)

---

## DBSL3CLEARCONNECTION
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 52)

---

## DBSL3BEGINTRANS
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 64)

---

## DBSL3COMMIT
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 71)

---

## DBSL3ROLLBACK
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 78)

---

## SL3_SetLoadBlobs
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 85)

---

## SL3_SetLoadMemos
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 89)

---

## DBSL3GETHANDLE
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 93)

---

## SL3_SETPK
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 99)

---

## SL3RDD_GETFUNCTABLE
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 754)

---

## SL3_PegarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 1104)

---

## SL3_GravarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 1111)

---

## SL3_PegarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 1119)

---

## SL3_GravarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\sqliterdd\SL3RDD.PRG` (line 1127)

---

