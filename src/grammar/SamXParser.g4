/*
   Copyright 2020 Florin Iucha

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */

parser grammar SamXParser;

options { tokenVocab = SamXLexer;  }

@header {
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <string>
}

@parser::members
{

private:
   //std::unordered_map<std::string, ParserResult> includedDocuments;
   std::unordered_map<std::string, std::string> includedExceptions;

   std::unordered_map<std::string, std::string> referencePaths;
   std::string basePath;

   int currentHeaderLength = 0;
   bool currentTailColumn = false;

public:
   void setBasePath(std::string aPath)
   {
      basePath = aPath;
   }

   const std::unordered_map<std::string, std::string> getReferencePaths() const
   {
      return referencePaths;
   }

#if 0
   void setIncludeDictionary(std::unordered_map<std::string, ParserResult> aDict)
   {
      includedDocuments = aDict;
   }
#endif

   void setIncludeExceptionsDictionary(std::unordered_map<std::string, std::string> aDict)
   {
      includedExceptions = aDict;
   }

private:
   void parseFile(std::string /* reference */)
   {
#if 0
      java.io.File includeFile = new java.io.File(basePath, reference);

      if (includeFile.exists())
      {
         referencePaths.put(reference, includeFile.getAbsolutePath());

         if (! includedDocuments.containsKey(includeFile.getAbsolutePath()))
         {
            try
            {
               net.signbit.samx.Parser.Result result = net.signbit.samx.Parser.parse(includeFile,
                  includedDocuments,
                  includedExceptions);

               includedDocuments.put(includeFile.getAbsolutePath(), result);
            }
            catch (java.io.IOException ioe)
            {
               includedExceptions.put(includeFile.getAbsolutePath(), ioe);
            }
         }
      }
      else
      {
         includedExceptions.put(includeFile.getAbsolutePath(), new java.io.FileNotFoundException(includeFile.getAbsolutePath()));
      }
#endif
   }

public:
}

nameList : NAME (COMMA NAME) + ;

conditionExpr :
   variable=NAME                                               # BooleanTrueCondition
   | variable=NAME EQUAL KW_TRUE                                # BooleanTrueCondition
   | variable=NAME EQUAL KW_FALSE                              # BooleanFalseCondition
   | BANG variable=NAME                                         # BooleanFalseCondition
   | variable=NAME oper=(EQUAL|NOT_EQ) value=NAME              # ComparisonCondition
   | variable=NAME KW_IN OPEN_PHR nameList CLOSE_PHR            # BelongsToSetCondition
   | variable=NAME KW_NOT KW_IN OPEN_PHR nameList CLOSE_PHR      # NotBelongsToSetCondition
   | OPEN_PAR firstCond=conditionExpr CLOSE_PAR KW_OR OPEN_PAR secondCond=conditionExpr CLOSE_PAR  # AlternativeCondition
   | OPEN_PAR firstCond=conditionExpr CLOSE_PAR KW_AND OPEN_PAR secondCond=conditionExpr CLOSE_PAR  # CombinedCondition
   ;

condition : STT_COND conditionExpr CLOSE_PAR ;

keyValuePair: key=NAME EQ_SGN value=NAME ;

path : (SLASH NAME) * ;

url : SCHEME SLASHSH (authority=NAME ATSGN)? host=NAME (TYPESEP port=INTEGER)? path (QUESTION keyValuePair (AMPERS keyValuePair)* )? (HASH frag=NAME)? ;

escapeSeq : ESCAPE ;

attribute :
   STT_NAME NAME CLOSE_PAR                  # NameAttr
   | STT_ID NAME CLOSE_PAR                  # IdentifierAttr
   | STT_CLASS NAME CLOSE_PAR               # ClassAttr
   | STT_LANG NAME CLOSE_PAR                # LanguageAttr
   | OPEN_SQR text CLOSE_SQR                # CitationAttr
   | STT_REFR NAME CLOSE_SQR                # ReferenceAttr
   ;

declaration: BANG NAME TYPESEP description=flow NEWLINE ;

lessThan : LT ;

greaterThan : GT ;

ampersand : AMPERS ;

quote : QUOT ;

string : STRING ;

literal : NAME | TOKEN | INTEGER | SLASH
   | KW_IN | KW_NOT | KW_OR | KW_AND | KW_TRUE | KW_FALSE
   | PLUS | COMMA | SEMI | PERIOD
   | OPEN_PAR | CLOSE_PAR | BANG | QUESTION | EQ_SGN | DOLLAR
   | BULL_T | HASH_T ;

entity : escapeSeq | lessThan | greaterThan | ampersand | quote ;

text : ( literal | entity | string ) + ;

annotation : STT_ANN flow CLOSE_PAR ;

phrase : OPEN_PHR text CLOSE_PHR annotation* metadata ;

localInsert : STT_LOCIN text CLOSE_PAR ;

inlineCode : APOSTR text APOSTR ;

flow : ( text | phrase | localInsert | url | inlineCode )+ ;

paragraph : ( flow NEWLINE )+ NEWLINE ;

headerRow
   locals [ int columnCount = 0; bool hasTailColumn = false; ]
   : ( COLSEP NAME { $ctx->columnCount ++; } )+ (trailingBar=COLSEP { $ctx->hasTailColumn = true; } )? NEWLINE
   {
      currentHeaderLength = $ctx->columnCount;
      currentTailColumn = $ctx->hasTailColumn;
   };

optionalFlow : flow? ;

recordData
   locals [ int columnCount = 0; ]
   : condition? ( COLSEP optionalFlow { $ctx->columnCount ++; } )+ NEWLINE
   {
      if (currentHeaderLength != $ctx->columnCount)
      {
         if (((currentHeaderLength + 1) != $ctx->columnCount) || (! currentTailColumn))
         {
            std::ostringstream os;
            os << "line " << $ctx->start->getLine() <<
               ":" << $ctx->start->getCharPositionInLine() <<
               " incorrect number of columns; expected " << currentHeaderLength <<
               " but observed " << $ctx->columnCount;
            throw antlr4::ParseCancellationException(os.str());
         }
      }
   };

recordSep
   locals [ int columnCount = 0; ]
   : (STT_TBL_SEP { $ctx->columnCount ++; })+ NEWLINE
   {
      if (currentHeaderLength < $ctx->columnCount)
      {
         std::ostringstream os;
         os << "line " << $ctx->start->getLine() <<
            ":" << $ctx->start->getCharPositionInLine() <<
            " incorrect number of columns; expected at most " << currentHeaderLength <<
            " but observed " << $ctx->columnCount;
         throw antlr4::ParseCancellationException(os.str());
      }
   };

recordRow : recordData | recordSep | GEN_ROW_SEP ;

gridElement : COLSEP attribute* optionalFlow ;

spanGridElement : MUL_COLSEP attribute* optionalFlow ;

generalGridElement : gridElement | spanGridElement ;

generalGridHeaderSep : STT_HDR_SEP NEWLINE ;

generalGridRowData : metadata generalGridElement+ ;

generalGridRow : (generalGridRowData | GEN_ROW_SEP) NEWLINE ;

generalGridGroup : (generalGridRow | NEWLINE)+ ;

preciseRecordSep : (STT_TBL_SEP)+ PLUS NEWLINE ;

preciseGridRowData : metadata gridElement+ NEWLINE ;

preciseGridRow : preciseGridRowData | preciseRecordSep ;

externalCode : EXTCODE ;

listElement : metadata flow NEWLINE (separator=NEWLINE? INDENT block+ DEDENT)? ;

unorderedList : (BULLET listElement) NEWLINE* ((BULLET listElement) | NEWLINE)* ;

orderedList : (HASH listElement) NEWLINE* ((HASH listElement) | NEWLINE)* ;

codeBlockDef : CODE_MARKER language=text CLOSE_PAR metadata NEWLINE+ INDENT (externalCode? NEWLINE)+ DEDENT ;

block :
     NAME TYPESEP blockMetadata NEWLINE+ INDENT block+ DEDENT                                         # TypedBlock
   | NAME TYPESEP metadata value=flow NEWLINE                                                         # Field
   | condition NEWLINE+ INDENT block+ DEDENT                                                          # ConditionalBlock
   | paragraph                                                                                        # PlainParagraph
   | NAME RECSEP blockMetadata NEWLINE+ INDENT headerRow (recordRow | NEWLINE)+ DEDENT                # RecordSet
   | unorderedList                                                                                    # UnorderedListBlock
   | orderedList                                                                                      # OrderedListBlock
   | STT_RMK text CLOSE_PAR NEWLINE block                                                             # Remark
   | STT_CIT text CLOSE_SQR NEWLINE ( INDENT block+ DEDENT )                                          # CitationBlock
   | STT_INFRG name=NAME CLOSE_PAR metadata                                                           # InsertFragment
   | STT_DEFRG name=NAME CLOSE_PAR metadata NEWLINE+ INDENT block+ DEDENT                             # DefineFragment
   | STT_INCL reference=text CLOSE_PAR metadata    { parseFile($reference.text); }                    # IncludeFile
   | STT_IMAGE text CLOSE_PAR blockMetadata (NEWLINE INDENT NEWLINE? codeBlockDef DEDENT)?            # InsertImage
   | codeBlockDef                                                                                     # CodeBlock
   | STT_GRID blockMetadata NEWLINE+ INDENT
         (header=generalGridGroup? generalGridHeaderSep)?
         body=generalGridGroup
         (generalGridHeaderSep? footer=generalGridGroup)?
     DEDENT                                                                                           # GeneralGrid
   | STT_PREC_GRID blockMetadata NEWLINE+ INDENT (preciseGridRow | NEWLINE) + DEDENT                  # PreciseGrid
   | NEWLINE                                                                                          # Empty
   ;

metadata: attribute* condition? ;

blockMetadata: metadata description=flow? ;

document: declaration* block* EOF ;

