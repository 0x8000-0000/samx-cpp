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

lexer grammar SamXLexer;

@header {
#include <SamXParser.h>

#include <deque>
#include <memory>
#include <stack>
}

channels { WHITESPACE, COMMENTS, INDENTS }

tokens { INDENT, DEDENT, END, INVALID, BOL }

@lexer::members 
{
private:
   std::deque<std::unique_ptr<antlr4::Token>> tokens;
   std::stack<int> indents;

   bool prepareProcessingCode = false;
   bool prepareFreeIndent = false;

   int codeIndentLevel = 0;
   bool allowFreeIndent = false;

   bool ignoreNewLinesInConditions = false;
   int nestedParenthesesLevel = 0;

   bool ignoreNewLinesInPhrases = false;
   int lastTokenPositionColumn = 0;


public:
   void emit(std::unique_ptr<antlr4::Token> t) override
   {
      lastTokenPositionColumn = t->getCharPositionInLine() + t->getText().size() + 1;
      tokens.emplace_back(t.release());
   }

   std::unique_ptr<antlr4::Token> nextToken() override
   {
      auto localToken = antlr4::Lexer::nextToken();

      if (! tokens.empty())
      {
         localToken.reset(tokens.front().release());
         tokens.pop_front();
      }

      return localToken;
   }

private:
   bool atStartOfInput()
   {
      return antlr4::Lexer::getCharPositionInLine() == 0 && antlr4::Lexer::getLine() == 1;
   }

   std::unique_ptr<antlr4::Token> makeToken(int type, const std::string& text)
   {
      const auto start = antlr4::Lexer::getCharIndex() - 1;
      auto _tokenFactorySourcePair = std::pair<antlr4::TokenSource *, antlr4::CharStream *>{this, getInputStream()};
      return _factory->create(
         /* source = */ _tokenFactorySourcePair,
         /* type = */ type,
         /* text = */ text,
         /* channel = */ DEFAULT_TOKEN_CHANNEL,
         /* start = */ start,
         /* stop = */ start,
         /* line = */ tokenStartLine,
         /* charPositionInLine = */ tokenStartCharPositionInLine);
   }

   std::unique_ptr<antlr4::Token> makeToken(int type, const std::string& text, int line, int column)
   {
      const auto start = antlr4::Lexer::getCharIndex() - 1;
      auto _tokenFactorySourcePair = std::pair<antlr4::TokenSource *, antlr4::CharStream *>{this, getInputStream()};
      return _factory->create(
         /* source = */ _tokenFactorySourcePair,
         /* type = */ type,
         /* text = */ text,
         /* channel = */ DEFAULT_TOKEN_CHANNEL,
         /* start = */ start,
         /* stop = */ start,
         /* line = */ line,
         /* charPositionInLine = */ column);
   }

   void addSpace()
   {
      const auto start = antlr4::Lexer::getCharIndex();
      auto _tokenFactorySourcePair = std::pair<antlr4::TokenSource *, antlr4::CharStream *>{this, getInputStream()};
      tokens.emplace_back(_factory->create(_tokenFactorySourcePair, samx::SamXParser::SPACES, " ", WHITESPACE, start, start + 1, tokenStartLine, lastTokenPositionColumn));
   }

   void addNewLine()
   {
      tokens.emplace_back(makeToken(samx::SamXParser::NEWLINE, "\n"));
   }

   void addEndBlock()
   {
      tokens.push_back(makeToken(samx::SamXParser::END, "¶"));
   }

   void addIndent()
   {
      tokens.push_back(makeToken(samx::SamXParser::INDENT, ">>>", tokenStartLine + 1, 0));
   }

   void addInvalid()
   {
      tokens.push_back(makeToken(samx::SamXParser::INVALID, "???"));
   }

   void addDedent()
   {
      tokens.push_back(makeToken(samx::SamXParser::DEDENT, "<<<"));
   }

   void popIndents(int level)
   {
      while ((! indents.empty()) && (indents.top() > level))
      {
         addDedent();
         indents.pop();
      }

      if (indents.empty() || (indents.top() == level))
      {
         // got back to previous level
      }
      else
      {
         // invalid indent; throw exception
         addInvalid();
      }
   }

   void addCodeIndent(int indentLevel)
   {
      std::string builder(/* count = */ indentLevel + 1, /* ch = */ ' ');

      const auto start = getCharIndex();
      auto _tokenFactorySourcePair = std::pair<antlr4::TokenSource *, antlr4::CharStream *>{this, getInputStream()};
      tokens.emplace_back(_factory->create(_tokenFactorySourcePair, samx::SamXParser::BOL, builder, INDENTS, start, start + indentLevel, tokenStartLine + 1, 0));
   }
}

ESCAPE : '\\' . ;

SPACES : [ \t]+ -> channel(WHITESPACE) ;

COMMENT : '%' ~[\r\n\f]* -> channel(COMMENTS) ;

NEWLINE
 : ( {atStartOfInput()}?   SPACES
   | ( '\r'? '\n' | '\r' | '\f' ) SPACES?
   )
   {
      {
         if (ignoreNewLinesInConditions)
         {
            skip();
            return;
         }

         if (ignoreNewLinesInPhrases)
         {
            addSpace();
            skip();
            return;
         }

         const auto& tokenText = getText();

         int thisIndent = 0;
         for (char ch: tokenText)
         {
            if (ch == ' ')
            {
               thisIndent ++;
            }
         }

         const auto next = _input->LA(1);
         if ((next == '\n') || (next == '\r'))
         {
            // this is an empty line, ignore
            return;
         }

         if (next == EOF)
         {
            // add an extra new line at the end of the file, to close out any pending paragraphs
            addNewLine();
         }

         const auto currentIndent = indents.empty() ? 0 : indents.top();

         if (thisIndent == currentIndent)
         {
            addNewLine();

            if (allowFreeIndent)
            {
               addDedent();

               allowFreeIndent = false;
               mode = Lexer::DEFAULT_MODE;
            }
         }
         else if (thisIndent > currentIndent)
         {
            addNewLine();

            if (prepareProcessingCode)
            {
               prepareProcessingCode = false;
               codeIndentLevel = currentIndent;
               mode = EXTERNAL_CODE;
               indents.push(thisIndent);
               addIndent();
            }
            else
            {
               if (prepareFreeIndent)
               {
                  prepareFreeIndent = false;
                  allowFreeIndent = true;

                  /* Add indent token here to indicate the contained elements
                  * but do not record this particular indent since it might be
                  * deep inside the table due to the column alignment and
                  * conditions.
                  *
                  * Instead, record a level just after the table level.
                  */
                  indents.push(currentIndent + 1);
                  addIndent();
               }

               if (! allowFreeIndent)
               {
                  indents.push(thisIndent);
                  addIndent();
               }
            }
         }
         else
         {
            addNewLine();
            popIndents(thisIndent);

            allowFreeIndent = false;
         }

         skip();

         addCodeIndent(thisIndent);
      }
   } ;

KW_NOT : 'not' ;

KW_IN : 'in' ;

KW_OR : 'or' ;

KW_AND : 'and' ;

KW_TRUE : 'true' ;

KW_FALSE : 'false' ;

STT_COND : '(?' { ignoreNewLinesInConditions = true; nestedParenthesesLevel = 1; } ;

STT_NAME : '(*' ;

STT_CLASS : '(.' ;

STT_ID : '(#' ;

STT_LANG : '(!' ;

STT_ANN : '(:' { ignoreNewLinesInConditions = true; nestedParenthesesLevel = 1; } ;

STT_REFR : '[*' ;

MUL_COLSEP : ('||' '|'* '-'* ) | ( '|-' '-'*  );

NAME : [-a-zA-Z_] [-a-zA-Z0-9_.]+ ;

INTEGER : [1-9] [0-9]+ ;

SCHEME : 'http' 's'? ':' ;

COMMA : ',' ;

SEMI : ';' ;

PERIOD : '.' ;

DOLLAR : '$' ;

TOKEN : [-a-zA-Z0-9_]+ ;

LT : '<' ;

GT : '>' ;

TYPESEP : ':' ;

RECSEP : '::' { prepareFreeIndent = true; };

COLSEP : '|' ;

BULLET : '*' ;

STT_PREC_GRID : '###' { prepareFreeIndent = true; };

HASH : '#' ;

OPEN_PHR : '{' { ignoreNewLinesInPhrases = true; };

CLOSE_PHR : '}' { ignoreNewLinesInPhrases = false; };

QUOT : '\'' ;

STRING : '"' ( '\\' . | ~[\\\r\n\f"] )* '"' ;

APOSTR : '`' ;

CODE_MARKER : '```(' { prepareProcessingCode = true; prepareFreeIndent = true; } ;

UNICODE_BOM: (UTF8_BOM
    | UTF16_BOM
    | UTF32_BOM
    ) -> skip
    ;

UTF8_BOM: '\uEFBBBF';
UTF16_BOM: '\uFEFF';
UTF32_BOM: '\u0000FEFF';

CLOSE_PAR : ')'
   {
      if (ignoreNewLinesInConditions)
      {
         nestedParenthesesLevel --;

         if (nestedParenthesesLevel == 0)
         {
            ignoreNewLinesInConditions = false;
         }
      }
   } ;

OPEN_PAR : '(' { if ( ignoreNewLinesInConditions) { nestedParenthesesLevel ++; } } ;

OPEN_SQR : '[' ;

CLOSE_SQR : ']' ;

EQ_SGN : '=' ;

EQUAL : '==' ;

NOT_EQ : '!=' ;

SLASH : '/' ;

SLASHSH : '//' ;

ATSGN : '@' ;

QUESTION : '?' ;

AMPERS : '&' ;

BANG : '!' ;

STT_GRID: '+++' { prepareFreeIndent = true; } ;

STT_GEN_GRID: '-+-' { prepareFreeIndent = true; } ;

PLUS : '+' ;

STT_LOCIN : '>($' ;

STT_RMK : '!!!(' ;

STT_CIT : '"""[' ;

STT_INFRG : '>>>(*' ;

STT_IMAGE : '>>>(image' ;

STT_DEFRG : '~~~(*' ;

STT_INCL : '<<<(' ;

STT_TBL_SEP : '+' '-'+ ;

STT_HDR_SEP : '+' ('='| '+' )+ '+' ;

GEN_ROW_SEP : '+' ('+' | '-' | ' ')+ ;

mode EXTERNAL_CODE ;

EXTCODE : (~'\n')+ ;

EXTCODE_NEWLINE
   : ( '\r'? '\n' | '\r' | '\f' ) SPACES?
   {
      {
         const auto& tokenText = getText();

         int thisIndent = 0;
         for (char ch: tokenText)
         {
            if (ch == ' ')
            {
               thisIndent ++;
            }
         }

         if (thisIndent > codeIndentLevel)
         {
            addNewLine();
            addCodeIndent(thisIndent);
         }
         else
         {
            addNewLine();

            mode = Lexer::DEFAULT_MODE;
         }

         skip();
      }
   } ;
