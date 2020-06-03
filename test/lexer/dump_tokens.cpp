#include "SamXLexer.h"

#include <ANTLRInputStream.h>
#include <CommonTokenStream.h>
#include <antlr4-runtime.h>

#include <gflags/gflags.h>

#include <fstream>
#include <iostream>

DEFINE_bool(verbose, false, "Verbose information");

int main(int argc, char* argv[])
{
   gflags::ParseCommandLineFlags(&argc, &argv, true);

   if (FLAGS_verbose)
   {
      std::cout << "Tokenize " << argv[1] << std::endl;
   }

   std::ifstream             inputFile(argv[1]);
   antlr4::ANTLRInputStream  input(inputFile);
   samx::SamXLexer           lexer(&input);
   antlr4::CommonTokenStream tokens(&lexer);

   tokens.fill();

#if 0
   for (const auto* token : tokens.getTokens())
   {
      std::cout << token->toString() << std::endl;
   }
#endif

   {
      std::ifstream            inputFile(argv[1]);
      antlr4::ANTLRInputStream input(inputFile);
      samx::SamXLexer          lexer(&input);
      lexer.getInterpreter<antlr4::atn::LexerATNSimulator>()->clearDFA();
   }

   return 0;
}
