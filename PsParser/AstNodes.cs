using System;
using System.Collections.Generic;

namespace PSParser;

/// <summary>
/// Baza dla wszystkich węzłów AST
/// </summary>
public abstract class AstNode
{
    public int Line { get; set; }
    public int Column { get; set; }
    public abstract void Accept(IAstVisitor visitor);
}

/// <summary>
/// Wyrażenie w AST
/// </summary>
public abstract class Expression : AstNode { }

/// <summary>
/// Statement w AST
/// </summary>
public abstract class Statement : AstNode { }

// Literals
public class StringLiteral : Expression
{
    public string Value { get; set; }
    public bool IsExpandable { get; set; }
    public List<InterpolationSegment> InterpolationSegments { get; set; } = new();

    public override void Accept(IAstVisitor visitor) => visitor.VisitStringLiteral(this);
}

/// <summary>
/// Segment interpolacji w stringach
/// </summary>
public class InterpolationSegment
{
    public string Type { get; set; } // "text", "variable", "expression"
    public string Content { get; set; }
    public string EvaluatedValue { get; set; } = "";
}

public class NumberLiteral : Expression
{
    public string Value { get; set; }
    public override void Accept(IAstVisitor visitor) => visitor.VisitNumberLiteral(this);
}

public class BooleanLiteral : Expression
{
    public bool Value { get; set; }
    public override void Accept(IAstVisitor visitor) => visitor.VisitBooleanLiteral(this);
}

public class VariableReference : Expression
{
    public string Name { get; set; }
    public override void Accept(IAstVisitor visitor) => visitor.VisitVariableReference(this);
}

// Binary Operations
public class BinaryExpression : Expression
{
    public Expression Left { get; set; }
    public Expression Right { get; set; }
    public string Operator { get; set; }

    public override void Accept(IAstVisitor visitor) => visitor.VisitBinaryExpression(this);
}

// Function Calls
public class FunctionCall : Expression
{
    public string FunctionName { get; set; }
    public List<Expression> Arguments { get; set; } = new();
    public Dictionary<string, Expression> NamedParameters { get; set; } = new();

    public override void Accept(IAstVisitor visitor) => visitor.VisitFunctionCall(this);
}

// Pipeline
public class PipelineExpression : Expression
{
    public List<Expression> Segments { get; set; } = new();

    public override void Accept(IAstVisitor visitor) => visitor.VisitPipelineExpression(this);
}

// Statements
public class ExpressionStatement : Statement
{
    public Expression Expression { get; set; }
    public override void Accept(IAstVisitor visitor) => visitor.VisitExpressionStatement(this);
}

public class AssignmentStatement : Statement
{
    public string VariableName { get; set; }
    public Expression Value { get; set; }

    public override void Accept(IAstVisitor visitor) => visitor.VisitAssignmentStatement(this);
}

public class IfStatement : Statement
{
    public Expression Condition { get; set; }
    public List<Statement> ThenBranch { get; set; } = new();
    public List<Statement> ElseBranch { get; set; } = new();

    public override void Accept(IAstVisitor visitor) => visitor.VisitIfStatement(this);
}

public class FunctionDefinition : Statement
{
    public string FunctionName { get; set; }
    public List<string> Parameters { get; set; } = new();
    public List<Statement> Body { get; set; } = new();

    public override void Accept(IAstVisitor visitor) => visitor.VisitFunctionDefinition(this);
}

public class ScriptBlock : AstNode
{
    public List<Statement> Statements { get; set; } = new();
    public override void Accept(IAstVisitor visitor) => visitor.VisitScriptBlock(this);
}

// Visitor pattern
public interface IAstVisitor
{
    void VisitStringLiteral(StringLiteral node);
    void VisitNumberLiteral(NumberLiteral node);
    void VisitBooleanLiteral(BooleanLiteral node);
    void VisitVariableReference(VariableReference node);
    void VisitBinaryExpression(BinaryExpression node);
    void VisitFunctionCall(FunctionCall node);
    void VisitPipelineExpression(PipelineExpression node);
    void VisitExpressionStatement(ExpressionStatement node);
    void VisitAssignmentStatement(AssignmentStatement node);
    void VisitIfStatement(IfStatement node);
    void VisitFunctionDefinition(FunctionDefinition node);
    void VisitScriptBlock(ScriptBlock node);
}
