antlr_target (SamXGrammarLexer SamXLexer.g4 LEXER PACKAGE samx) 

antlr_target (SamXGrammarParser SamXParser.g4 PARSER PACKAGE samx
   DEPENDS_ANTLR SamXGrammarLexer
   VISITOR COMPILE_FLAGS -lib ${ANTLR_SamXGrammarLexer_OUTPUT_DIR})

add_library (samx ${ANTLR_SamXGrammarLexer_CXX_OUTPUTS}
   ${ANTLR_SamXGrammarParser_CXX_OUTPUTS})

target_link_libraries (samx PUBLIC CONAN_PKG::antlr4)
target_compile_definitions (samx PUBLIC -DANTLR4CPP_STATIC)
target_include_directories (samx PUBLIC ${ANTLR_SamXGrammarLexer_OUTPUT_DIR})
target_include_directories (samx PUBLIC ${ANTLR_SamXGrammarParser_OUTPUT_DIR})
