namespace PSParser;

/// <summary>
/// Reprezentuje typ tokenu w PowerShelu
/// </summary>
public enum TokenType
{
    // Literals
    String,
    ExpandableString,  // String z $variables lub expressions
    Number,
    Boolean,
    Variable,
    
    // Keywords
    If,
    Else,
    ElseIf,
    For,
    ForEach,
    While,
    Do,
    Try,
    Catch,
    Finally,
    Function,
    Filter,
    Param,
    Return,
    Break,
    Continue,
    Throw,
    
    // Operators
    Pipe,               // |
    Plus,               // +
    Minus,              // -
    Multiply,           // *
    Divide,             // /
    Modulo,             // %
    Equals,             // =
    EqualTo,            // -eq
    NotEqualTo,         // -ne
    LessThan,           // -lt
    GreaterThan,        // -gt
    LessThanOrEqual,    // -le
    GreaterThanOrEqual, // -ge
    Match,              // -match
    NotMatch,           // -notmatch
    Like,               // -like
    NotLike,            // -notlike
    Contains,           // -contains
    NotContains,        // -notcontains
    In,                 // -in
    NotIn,              // -notin
    And,                // -and
    Or,                 // -or
    Not,                // -not
    BitwiseAnd,         // -band
    BitwiseOr,          // -bor
    BitwiseXor,         // -bxor
    BitwiseNot,         // -bnot
    LeftShift,          // -shl
    RightShift,         // -shr
    
    // Delimiters
    LeftParen,          // (
    RightParen,         // )
    LeftBrace,          // {
    RightBrace,         // }
    LeftBracket,        // [
    RightBracket,       // ]
    Semicolon,          // ;
    Comma,              // ,
    Dot,                // .
    DoubleColon,        // ::
    Dollar,             // $
    At,                 // @
    Question,           // ?
    Colon,              // :
    
    // Special
    Identifier,
    Comment,
    Newline,
    Whitespace,
    EndOfFile,
    Unknown
}

/// <summary>
/// Reprezentuje pojedynczy token z kodu PowerShela
/// </summary>
public class Token
{
    public TokenType Type { get; set; }
    public string Value { get; set; }
    public int Line { get; set; }
    public int Column { get; set; }
    public int Position { get; set; }
    public int Length { get; set; }

    public Token(TokenType type, string value, int line, int column, int position, int length)
    {
        Type = type;
        Value = value;
        Line = line;
        Column = column;
        Position = position;
        Length = length;
    }

    public override string ToString() => $"{Type}({Value}) @ {Line}:{Column}";
}
