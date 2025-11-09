%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>

FILE *token_file;
FILE *error_file;
int line_no = 1;
int total_tokens = 0;
int total_errors = 0;

int in_comment = 0;

int is_keyword(const char *s) {
    const char *keywords[] = {
        "hum", "tum", "Wapas", "Agar", "Adadi", "Mantiqi", "shuru", "khatam",
        "jabtak", "warna", "magar", "ucp", "socho", "dalo", "rahko", "pakka",
        "aur", "keliye", "lo", "sahi", "galat", "ya", "nahi", "kaam", "wapis", "hatao",
        "output<-", NULL
    };
    for (int i = 0; keywords[i] != NULL; i++)
        if (strcmp(s, keywords[i]) == 0)
            return 1;
    return 0;
}

const char* get_operator_name(const char *s) {
    if (strcmp(s, "+") == 0) return "PLUS";
    if (strcmp(s, "-") == 0) return "MINUS";
    if (strcmp(s, "*") == 0) return "MULTIPLY";
    if (strcmp(s, "/") == 0) return "DIVIDE";
    if (strcmp(s, "%") == 0) return "MODULO";
    if (strcmp(s, "++") == 0) return "INCREMENT";
    if (strcmp(s, "--") == 0) return "DECREMENT";
    
    if (strcmp(s, "=") == 0) return "ASSIGN";
    if (strcmp(s, "+=") == 0) return "PLUS_ASSIGN";
    if (strcmp(s, "-=") == 0) return "MINUS_ASSIGN";
    if (strcmp(s, "*=") == 0) return "MULTIPLY_ASSIGN";
    if (strcmp(s, "/=") == 0) return "DIVIDE_ASSIGN";
    if (strcmp(s, "%=") == 0) return "MODULO_ASSIGN";
    if (strcmp(s, "<<=") == 0) return "LEFT_SHIFT_ASSIGN";
    if (strcmp(s, ">>=") == 0) return "RIGHT_SHIFT_ASSIGN";
    if (strcmp(s, "&=") == 0) return "BITWISE_AND_ASSIGN";
    if (strcmp(s, "^=") == 0) return "BITWISE_XOR_ASSIGN";
    if (strcmp(s, "|=") == 0) return "BITWISE_OR_ASSIGN";
    
    if (strcmp(s, "==") == 0) return "EQUAL";
    if (strcmp(s, "!=") == 0) return "NOT_EQUAL";
    if (strcmp(s, ">") == 0) return "GREATER";
    if (strcmp(s, "<") == 0) return "LESS";
    if (strcmp(s, ">=") == 0) return "GREATER_EQUAL";
    if (strcmp(s, "<=") == 0) return "LESS_EQUAL";

    if (strcmp(s, "&&") == 0) return "AND";
    if (strcmp(s, "||") == 0) return "OR";
    if (strcmp(s, "!") == 0) return "NOT";
 
    if (strcmp(s, "&") == 0) return "BITWISE_AND";
    if (strcmp(s, "|") == 0) return "BITWISE_OR";
    if (strcmp(s, "^") == 0) return "BITWISE_XOR";
    if (strcmp(s, "~") == 0) return "BITWISE_NOT";
    if (strcmp(s, "<<") == 0) return "LEFT_SHIFT";
    if (strcmp(s, ">>") == 0) return "RIGHT_SHIFT";

    if (strcmp(s, "->") == 0) return "ARROW";
    if (strcmp(s, ".") == 0) return "DOT";
    if (strcmp(s, "?:") == 0) return "TERNARY";
    if (strcmp(s, "::") == 0) return "SCOPE";
    if (strcmp(s, "<-") == 0) return "ASSIGN_LEFT";
    if (strcmp(s, "=~") == 0) return "PATTERN_MATCH";
    
    return "OPERATOR";
}

const char* get_punctuation_name(const char *s) {
    if (strcmp(s, ";") == 0) return "SEMICOLON";
    if (strcmp(s, ",") == 0) return "COMMA";
    if (strcmp(s, "(") == 0) return "LEFT_PAREN";
    if (strcmp(s, ")") == 0) return "RIGHT_PAREN";
    if (strcmp(s, "{") == 0) return "LEFT_BRACE";
    if (strcmp(s, "}") == 0) return "RIGHT_BRACE";
    if (strcmp(s, "[") == 0) return "LEFT_BRACKET";
    if (strcmp(s, "]") == 0) return "RIGHT_BRACKET";
    if (strcmp(s, ":") == 0) return "COLON";
    if (strcmp(s, "?") == 0) return "QUESTION";
    if (strcmp(s, ".") == 0) return "DOT";
    
    return "PUNCTUATION";
}

int is_integer(const char *s) {
    int i = 0;
    if (s[i] == '+' || s[i] == '-') i++;
    if (!isdigit(s[i])) return 0;
    for (; s[i]; i++)
        if (!isdigit(s[i])) return 0;
    return 1;
}

int is_float(const char *s) {
    int i = 0, dot = 0;
    if (s[i] == '+' || s[i] == '-') i++;
    int digits_before = 0, digits_after = 0;
    
    while (isdigit(s[i])) {
        digits_before++;
        i++;
    }
    
    if (s[i] == '.') {
        dot = 1;
        i++;
    }
  
    while (isdigit(s[i])) {
        digits_after++;
        i++;
    }
    
    return (digits_before > 0 || digits_after > 0) && dot == 1 && s[i] == '\0';
}

int is_exponential(const char *s) {
    int i = 0, dot = 0, e_seen = 0, digits_before_e = 0, digits_after_e = 0;
    
    if (s[i] == '+' || s[i] == '-') i++;
    
    while (isdigit(s[i])) {
        digits_before_e++;
        i++;
    }

    if (s[i] == '.') {
        dot = 1;
        i++;
        while (isdigit(s[i])) {
            digits_before_e++;
            i++;
        }
    }
    
    if (s[i] == 'e' || s[i] == 'E') {
        e_seen = 1;
        i++;
        
        if (s[i] == '+' || s[i] == '-') i++;

        while (isdigit(s[i])) {
            digits_after_e++;
            i++;
        }
    }
    
    return digits_before_e > 0 && (e_seen == 0 || digits_after_e > 0) && s[i] == '\0';
}

int is_valid_identifier(const char *s) {
    if (!isalpha(s[0]) && s[0] != '_')
        return 0;
    for (int i = 1; s[i]; i++)
        if (!isalnum(s[i]) && s[i] != '_')
            return 0;
    return 1;
}

int is_special_identifier(const char *s) {
    if (s[0] == '@' || s[0] == '#' || s[0] == '$' || s[0] == '%' || 
        s[0] == '^' || s[0] == '&' || s[0] == '*') {
        return 1;
    }
    return 0;
}

const char* get_special_identifier_type(const char *s) {
    if (isdigit(s[1])) {
        return "INVALID_NUMBER";
    } else if (isalpha(s[1]) || s[1] == '_') {
        return "INVALID_IDENTIFIER";
    } else {
        return "UNKNOWN_TOKEN";
    }
}

int is_operator(const char *s) {
    const char *ops[] = {
        "+", "-", "*", "/", "%", "++", "--",
        "=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "^=", "|=",
        "==", "!=", ">", "<", ">=", "<=",
        "&&", "||", "!",
        "&", "|", "^", "~", "<<", ">>",
        "->", ".", "?:", "::", "<-", "=~",
        NULL
    };
    for (int i = 0; ops[i] != NULL; i++)
        if (strcmp(s, ops[i]) == 0)
            return 1;
    return 0;
}

int is_punctuation(const char *s) {
    const char *puncs[] = {
        ";", ",", "(", ")", "{", "}", "[", "]", ":", "?", ".",
        NULL
    };
    for (int i = 0; puncs[i] != NULL; i++)
        if (strcmp(s, puncs[i]) == 0)
            return 1;
    return 0;
}

int is_string_literal(const char *s) {
    int len = strlen(s);
    if (len < 2 || s[0] != '"' || s[len-1] != '"') return 0;
    
    for (int i = 1; i < len-1; i++) {
        if (s[i] == '\\') {
            i++;
            if (i >= len-1) return 0;
            char next = s[i];
            if (next != 'n' && next != 't' && next != 'r' && next != '\\' && 
                next != '"' && next != '0' && next != 'a' && next != 'b' && next != 'f' &&
                next != 'v' && next != '\'') {
                return 0;
            }
        }
    }
    return 1;
}

int is_char_literal(const char *s) {
    int len = strlen(s);
    if (len < 3 || s[0] != '\'' || s[len-1] != '\'') return 0;
    
    if (len == 2) return 0;
    
    if (len == 3) return 1;

    if (len == 4 && s[1] == '\\') {
        char esc = s[2];
        if (esc != 'n' && esc != 't' && esc != 'r' && esc != '\\' && 
            esc != '\'' && esc != '0' && esc != 'a' && esc != 'b' && esc != 'f' &&
            esc != 'v') {
            return 1;
        }
        return 0;
    }
    
    return 0;
}

int has_multiple_dots(const char *s) {
    int dot_count = 0;
    for (int i = 0; s[i]; i++) {
        if (s[i] == '.') dot_count++;
    }
    return dot_count > 1;
}

int has_multiple_exponents(const char *s) {
    int e_count = 0;
    for (int i = 0; s[i]; i++) {
        if (s[i] == 'e' || s[i] == 'E') e_count++;
    }
    return e_count > 1;
}

int has_consecutive_operators(const char *s) {
    return strstr(s, "+++") || strstr(s, "---") || strstr(s, "***") || 
           strstr(s, "///") || strstr(s, "\\\\\\\\");
}

int is_mixed_alphanumeric(const char *s) {
    int has_alpha = 0, has_digit = 0;
    for (int i = 0; s[i]; i++) {
        if (isalpha(s[i])) has_alpha = 1;
        if (isdigit(s[i])) has_digit = 1;
        if (has_alpha && has_digit) return 1;
    }
    return 0;
}

const char* detect_token_type(const char *tok) {
    if (has_multiple_dots(tok) && (isdigit(tok[0]) || tok[0] == '.')) 
        return "INVALID_NUMBER_MULTIPLE_DOTS";
    
    if (has_multiple_exponents(tok)) 
        return "INVALID_NUMBER_MULTIPLE_EXPONENTS";
    
    if (has_consecutive_operators(tok)) 
        return "INVALID_OPERATOR_COMBINATION";
    
    if (is_string_literal(tok)) return "STRING";
    if (is_char_literal(tok)) return "CHAR";
    if (is_exponential(tok)) return "NUMBER_EXP";
    if (is_float(tok)) return "NUMBER_FLOAT";
    if (is_integer(tok)) return "NUMBER_INT";
    if (is_keyword(tok)) return "KEYWORD";
    if (is_operator(tok)) return get_operator_name(tok);
    if (is_punctuation(tok)) return get_punctuation_name(tok);
    if (is_valid_identifier(tok)) return "IDENTIFIER";
    
    if (is_special_identifier(tok)) {
        return get_special_identifier_type(tok);
    }
    
    if (isdigit(tok[0]) || tok[0] == '+' || tok[0] == '-' || tok[0] == '.') {
        return "INVALID_NUMBER";
    }
    
    if (tok[0] == '"') return "INVALID_STRING";
    if (tok[0] == '\'') return "INVALID_CHAR";
    
    if (strstr(tok, "+++") || strstr(tok, "---") || strstr(tok, "***") || 
        strstr(tok, "///") || strstr(tok, "\\\\\\\\")) {
        return "INVALID_OPERATOR";
    }
    
    if (isdigit(tok[0]) && is_mixed_alphanumeric(tok)) {
        return "INVALID_NUMBER_FORMAT";
    }
    
    return "UNKNOWN_TOKEN";
}

const char* detect_error_reason(const char *tok) {
    int len = strlen(tok);
    
    if (has_multiple_dots(tok)) 
        return "invalid number - multiple decimal points";
    
    if (has_multiple_exponents(tok)) 
        return "invalid number - multiple exponents";
    
    if (has_consecutive_operators(tok)) 
        return "invalid operator - consecutive operators not allowed";
    
    if (is_special_identifier(tok)) {
        if (isdigit(tok[1])) {
            return "invalid number - cannot start with special character";
        } else if (isalpha(tok[1]) || tok[1] == '_') {
            return "identifier cannot start with special character";
        } else {
            return "invalid token starting with special character";
        }
    }
    
    if (isdigit(tok[0]) && !is_integer(tok) && !is_float(tok) && !is_exponential(tok)) {
        for (int i = 0; tok[i]; i++) {
            if (isalpha(tok[i]) || tok[i] == '_') {
                return "identifier cannot start with digit";
            }
        }
    }
    
    if (isdigit(tok[0]) || tok[0] == '+' || tok[0] == '-' || tok[0] == '.') {
        int dot_count = 0, e_count = 0, digit_count = 0;
        
        for (int i = 0; tok[i]; i++) {
            if (isdigit(tok[i])) digit_count++;
            else if (tok[i] == '.') dot_count++;
            else if (tok[i] == 'e' || tok[i] == 'E') e_count++;
            else if (tok[i] == '+' || tok[i] == '-') {
                if (i > 0 && (tok[i-1] != 'e' && tok[i-1] != 'E')) {
                    return "invalid number format - sign not allowed here";
                }
            }
            else if (isalpha(tok[i])) {
                return "invalid number - contains letters";
            }
            else {
                return "invalid number - contains illegal characters";
            }
        }
        
        if (dot_count > 1) return "invalid number - multiple decimal points";
        if (e_count > 1) return "invalid number - multiple exponents";
        if (digit_count == 0) return "invalid number - no digits found";
        
        return "invalid number format";
    }
    
    if (tok[0] == '"') {
        if (tok[len-1] != '"') return "unterminated string literal";
        
        for (int i = 1; i < len-1; i++) {
            if (tok[i] == '\\') {
                i++;
                if (i >= len-1) return "incomplete escape sequence";
                char esc = tok[i];
                if (esc != 'n' && esc != 't' && esc != 'r' && esc != '\\' && 
                    esc != '"' && esc != '0' && esc != 'a' && esc != 'b' && esc != 'f' &&
                    esc != 'v' && esc != '\'') {
                    return "invalid escape sequence";
                }
            }
        }
        return "invalid string format";
    }
    
    if (tok[0] == '\'') {
        if (tok[len-1] != '\'') return "unterminated character literal";
        if (len == 2) return "empty character literal";
        if (len > 4) return "character literal too long";
        
        if (len == 4 && tok[1] == '\\') {
            char esc = tok[2];
            if (esc != 'n' && esc != 't' && esc != 'r' && esc != '\\' && 
                esc != '\'' && esc != '0' && esc != 'a' && esc != 'b' && esc != 'f' &&
                esc != 'v') {
                return "invalid escape sequence in character";
            }
        }
        
        if (len > 3 && tok[1] != '\\') return "character literal too long";
        return "invalid character format";
    }
    
    if (strstr(tok, "+++") || strstr(tok, "---") || strstr(tok, "***") || 
        strstr(tok, "///") || strstr(tok, "\\\\\\\\")) {
        return "invalid operator combination";
    }
    
    if (!is_valid_identifier(tok) && (isalpha(tok[0]) || tok[0] == '_')) {
        for (int i = 0; tok[i]; i++) {
            if (!isalnum(tok[i]) && tok[i] != '_') {
                return "identifier contains invalid characters";
            }
        }
    }
    
    if (len == 1 && !isalnum(tok[0]) && tok[0] != '_') {
        if (!is_operator(tok) && !is_punctuation(tok)) {
            return "unknown symbol";
        }
    }

    if (len > 1 && !is_operator(tok) && !is_keyword(tok) && !is_valid_identifier(tok)) {
        return "unrecognized token";
    }
    
    return "invalid token format";
}

void print_token(const char *type, const char *val) {
    printf("Line %d: %s -> %s\n", line_no, type, val);
    fprintf(token_file, "Line %d: %s -> %s\n", line_no, type, val);
    total_tokens++;
}

void print_error_with_type(const char *type, const char *val, const char *msg) {
    printf("Line %d: %s -> %s (ERROR: %s)\n", line_no, type, val, msg);
    fprintf(error_file, "Line %d: %s -> %s (ERROR: %s)\n", line_no, type, val, msg);
    total_errors++;
    total_tokens++;
}

void handle_token(const char *tok) {
    if (tok[0] == '\0') return;
    
    const char *token_type = detect_token_type(tok);
    
    if (strcmp(token_type, "UNKNOWN_TOKEN") != 0 && 
        strstr(token_type, "INVALID_") == NULL) {
        print_token(token_type, tok);
    } else {
        const char *reason = detect_error_reason(tok);
        print_error_with_type(token_type, tok, reason);
    }
}
%}

%option noyywrap

%x COMMENT SINGLE_COMMENT

%%

\"[^"\n]*\"      { handle_token(yytext); }
\"[^"\n]*        { 
    fprintf(error_file, "Line %d: INVALID_STRING -> %s (ERROR: unterminated string literal)\n", line_no, yytext);
    printf("Line %d: INVALID_STRING -> %s (ERROR: unterminated string literal)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

'[^'\\\n]'       { handle_token(yytext); }
'\\[nrt0abfv\\'\"]' { handle_token(yytext); }
'\\[^nrt0abfv\\'\"]' { 
    fprintf(error_file, "Line %d: INVALID_CHAR -> %s (ERROR: invalid escape sequence in character)\n", line_no, yytext);
    printf("Line %d: INVALID_CHAR -> %s (ERROR: invalid escape sequence in character)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}
'[^'\n]*'        { 
    fprintf(error_file, "Line %d: INVALID_CHAR -> %s (ERROR: character literal too long)\n", line_no, yytext);
    printf("Line %d: INVALID_CHAR -> %s (ERROR: character literal too long)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}
'[^'\n]*         { 
    fprintf(error_file, "Line %d: INVALID_CHAR -> %s (ERROR: unterminated character literal)\n", line_no, yytext);
    printf("Line %d: INVALID_CHAR -> %s (ERROR: unterminated character literal)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

"//"            { BEGIN(SINGLE_COMMENT); }
"/*"            { BEGIN(COMMENT); }

<SINGLE_COMMENT>[^\n]*    { /* ignore single-line comment */ }
<SINGLE_COMMENT>\n        { BEGIN(INITIAL); line_no++; }

<COMMENT>"*/"   { BEGIN(INITIAL); }
<COMMENT>\n     { line_no++; }
<COMMENT>.      { /* ignore comment content */ }
<COMMENT><<EOF>> { 
    fprintf(error_file, "Line %d: ERROR -> Unterminated multi-line comment\n", line_no);
    printf("Line %d: ERROR -> Unterminated multi-line comment\n", line_no);
    BEGIN(INITIAL); 
    total_errors++;
}

"+++"|"---"|"***"|"///"|"\\\\\\\\" { 
    fprintf(error_file, "Line %d: INVALID_OPERATOR_COMBINATION -> %s (ERROR: invalid operator - consecutive operators not allowed)\n", line_no, yytext);
    printf("Line %d: INVALID_OPERATOR_COMBINATION -> %s (ERROR: invalid operator - consecutive operators not allowed)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

"///"           { 
    fprintf(error_file, "Line %d: INVALID_OPERATOR -> %s (ERROR: invalid operator combination)\n", line_no, yytext);
    printf("Line %d: INVALID_OPERATOR -> %s (ERROR: invalid operator combination)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[0-9]+(\.[0-9]+){2,}        { 
    fprintf(error_file, "Line %d: INVALID_NUMBER_MULTIPLE_DOTS -> %s (ERROR: invalid number - multiple decimal points)\n", line_no, yytext);
    printf("Line %d: INVALID_NUMBER_MULTIPLE_DOTS -> %s (ERROR: invalid number - multiple decimal points)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[0-9]+([Ee][+-]?[0-9]+){2,} { 
    fprintf(error_file, "Line %d: INVALID_NUMBER_MULTIPLE_EXPONENTS -> %s (ERROR: invalid number - multiple exponents)\n", line_no, yytext);
    printf("Line %d: INVALID_NUMBER_MULTIPLE_EXPONENTS -> %s (ERROR: invalid number - multiple exponents)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[0-9]+[a-zA-Z_]+[a-zA-Z0-9_]* { 
    fprintf(error_file, "Line %d: INVALID_NUMBER_FORMAT -> %s (ERROR: identifier cannot start with digit)\n", line_no, yytext);
    printf("Line %d: INVALID_NUMBER_FORMAT -> %s (ERROR: identifier cannot start with digit)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[0-9]+(\.[0-9]+)*[a-zA-Z_]+ { 
    fprintf(error_file, "Line %d: INVALID_NUMBER_FORMAT -> %s (ERROR: invalid number format - mixed digits and letters)\n", line_no, yytext);
    printf("Line %d: INVALID_NUMBER_FORMAT -> %s (ERROR: invalid number format - mixed digits and letters)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

\.{3,}                      { 
    fprintf(error_file, "Line %d: INVALID_OPERATOR_COMBINATION -> %s (ERROR: invalid operator - multiple dots)\n", line_no, yytext);
    printf("Line %d: INVALID_OPERATOR_COMBINATION -> %s (ERROR: invalid operator - multiple dots)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[@#$%^&*]{2,}               { 
    fprintf(error_file, "Line %d: INVALID_SYMBOL_COMBINATION -> %s (ERROR: invalid symbol combination)\n", line_no, yytext);
    printf("Line %d: INVALID_SYMBOL_COMBINATION -> %s (ERROR: invalid symbol combination)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

"++"            { handle_token(yytext); }
"--"            { handle_token(yytext); }
"+="            { handle_token(yytext); }
"-="            { handle_token(yytext); }
"*="            { handle_token(yytext); }
"/="            { handle_token(yytext); }
"%="            { handle_token(yytext); }
"<<="           { handle_token(yytext); }
">>="           { handle_token(yytext); }
"&="            { handle_token(yytext); }
"^="            { handle_token(yytext); }
"|="            { handle_token(yytext); }
"=="            { handle_token(yytext); }
"!="            { handle_token(yytext); }
">="            { handle_token(yytext); }
"<="            { handle_token(yytext); }
"&&"            { handle_token(yytext); }
"||"            { handle_token(yytext); }
"->"            { handle_token(yytext); }
"::"            { handle_token(yytext); }
"<-"            { handle_token(yytext); }
"=~"            { handle_token(yytext); }
"?"             { handle_token(yytext); }
":"             { handle_token(yytext); }

";"             { handle_token(yytext); }
","             { handle_token(yytext); }
"("             { handle_token(yytext); }
")"             { handle_token(yytext); }
"{"             { handle_token(yytext); }
"}"             { handle_token(yytext); }
"["             { handle_token(yytext); }
"]"             { handle_token(yytext); }
"."             { handle_token(yytext); }

"/"             { handle_token(yytext); }
"+"             { handle_token(yytext); }
"-"             { handle_token(yytext); }
"*"             { handle_token(yytext); }
"%"             { handle_token(yytext); }
"="             { handle_token(yytext); }
"!"             { handle_token(yytext); }
"&"             { handle_token(yytext); }
"|"             { handle_token(yytext); }
"^"             { handle_token(yytext); }
"~"             { handle_token(yytext); }
"<"             { handle_token(yytext); }
">"             { handle_token(yytext); }

[0-9]+([Ee][+-]?[0-9]+)  { handle_token(yytext); }
[0-9]*\.[0-9]+([Ee][+-]?[0-9]+)? { handle_token(yytext); }
[0-9]+\.([Ee][+-]?[0-9]+)? { handle_token(yytext); }
[+-]?[0-9]+      { handle_token(yytext); }

[@#$%^&*][a-zA-Z_][a-zA-Z0-9_]*     { 
    fprintf(error_file, "Line %d: INVALID_IDENTIFIER -> %s (ERROR: identifier cannot start with special character)\n", line_no, yytext);
    printf("Line %d: INVALID_IDENTIFIER -> %s (ERROR: identifier cannot start with special character)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[@#$%^&*][0-9]+[a-zA-Z_]*          { 
    fprintf(error_file, "Line %d: INVALID_NUMBER -> %s (ERROR: invalid number - cannot start with special character)\n", line_no, yytext);
    printf("Line %d: INVALID_NUMBER -> %s (ERROR: invalid number - cannot start with special character)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[@#$%^&*]       { 
    fprintf(error_file, "Line %d: INVALID_SYMBOL -> %s (ERROR: invalid standalone symbol)\n", line_no, yytext);
    printf("Line %d: INVALID_SYMBOL -> %s (ERROR: invalid standalone symbol)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

[a-zA-Z_][a-zA-Z0-9_]* { handle_token(yytext); }

[ \t]+          { /* ignore whitespace */ }
\r\n|\n|\r      { line_no++; }

.               { 
    fprintf(error_file, "Line %d: UNKNOWN_TOKEN -> %s (ERROR: unknown symbol)\n", line_no, yytext);
    printf("Line %d: UNKNOWN_TOKEN -> %s (ERROR: unknown symbol)\n", line_no, yytext);
    total_errors++;
    total_tokens++;
}

%%

int main(int argc, char *argv[]) {
    token_file = fopen("token.txt", "w");
    error_file = fopen("error.txt", "w");
    
    if (token_file == NULL || error_file == NULL) {
        printf("Error: Could not create output files!\n");
        return 1;
    }
    
    printf("=== Urdu Script Lexical Analyzer ===\n");
    printf("Output files: token.txt, error.txt\n");
    
    if (argc > 1) {
        printf("Reading from file: %s\n\n", argv[1]);
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            printf("Error: Could not open input file %s\n", argv[1]);
            fclose(token_file);
            fclose(error_file);
            return 1;
        }
    } else {
        printf("Enter your code (Press Ctrl+D to end):\n\n");
    }
    
    yylex();
    
    fclose(token_file);
    fclose(error_file);
    
    printf("\n=== Lexical Analysis Completed ===\n");
    printf("Total tokens: %d\n", total_tokens);
    printf("Total errors: %d\n", total_errors);
    printf("Check token.txt for all tokens\n");
    printf("Check error.txt for all errors\n");
    
    if (total_errors == 0) {
        printf("\n🎉 SUCCESS: No lexical errors found!\n");
    } else {
        printf("\n⚠️  Found %d error(s) that need to be fixed.\n", total_errors);
    }
    
    return 0;
}
