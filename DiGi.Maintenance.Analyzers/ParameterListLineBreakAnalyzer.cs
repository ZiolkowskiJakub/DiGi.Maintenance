using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;
using System.Collections.Immutable;

namespace DiGi.Maintenance.Analyzers
{
    /// <summary>
    /// Roslyn DiagnosticAnalyzer that enforces the parameter line-break rule on method, constructor, and delegate parameter lists.
    /// <para>Parameter lists with 1–7 parameters must remain on a single line regardless of length; parameter lists with 8 or more parameters must be split across multiple lines (one parameter per line).</para>
    /// </summary>
    [DiagnosticAnalyzer(LanguageNames.CSharp)]
    public class ParameterListLineBreakAnalyzer : DiagnosticAnalyzer
    {
        /// <summary>
        /// Diagnostic ID for parameter line-break rule violations.
        /// </summary>
        public const string DiagnosticId = "DIGI0001";

        private static readonly LocalizableString Title = "Parameter list line-break rule violation";
        private static readonly LocalizableString MessageFormat = "Parameter list declaration has {0} parameters ({1}) and must be formatted {2}";
        private static readonly LocalizableString Description = "Enforces that parameter lists with 1-7 parameters stay on a single line, and parameter lists with 8+ parameters are split across multiple lines (one per line).";
        private const string Category = "Style";

        private static readonly DiagnosticDescriptor Rule = new(
            DiagnosticId,
            Title,
            MessageFormat,
            Category,
            DiagnosticSeverity.Warning,
            isEnabledByDefault: true,
            description: Description);

        /// <summary>
        /// Gets the set of descriptors for diagnostics supported by this analyzer.
        /// </summary>
        public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics
        {
            get
            {
                return ImmutableArray.Create(Rule);
            }
        }

        /// <summary>
        /// Initializes the analyzer by registering actions for syntax node analysis.
        /// </summary>
        /// <param name="context">The analysis context to register actions with.</param>
        public override void Initialize(AnalysisContext context)
        {
            if (context == null)
            {
                return;
            }

            context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
            context.EnableConcurrentExecution();
            context.RegisterSyntaxNodeAction(AnalyzeParameterList, SyntaxKind.ParameterList);
        }

        private static void AnalyzeParameterList(SyntaxNodeAnalysisContext context)
        {
            if (context.Node is not ParameterListSyntax parameterListSyntax)
            {
                return;
            }

            int parameterCount = parameterListSyntax.Parameters.Count;
            FileLinePositionSpan fileLineSpan = parameterListSyntax.SyntaxTree.GetLineSpan(parameterListSyntax.Span);
            int startLine = fileLineSpan.StartLinePosition.Line;
            int endLine = fileLineSpan.EndLinePosition.Line;
            bool isMultiLine = startLine != endLine;

            if (parameterCount <= 7 && isMultiLine)
            {
                Diagnostic diagnostic = Diagnostic.Create(
                    Rule,
                    parameterListSyntax.GetLocation(),
                    parameterCount,
                    "<= 7",
                    "on a single line");
                context.ReportDiagnostic(diagnostic);
            }
            else if (parameterCount >= 8)
            {
                bool isOnePerLine = true;
                if (!isMultiLine)
                {
                    isOnePerLine = false;
                }
                else
                {
                    int lastParamLine = -1;
                    foreach (ParameterSyntax parameter in parameterListSyntax.Parameters)
                    {
                        FileLinePositionSpan paramSpan = parameter.SyntaxTree.GetLineSpan(parameter.Span);
                        int paramLine = paramSpan.StartLinePosition.Line;
                        if (paramLine == lastParamLine)
                        {
                            isOnePerLine = false;
                            break;
                        }
                        lastParamLine = paramLine;
                    }
                }

                if (!isOnePerLine)
                {
                    Diagnostic diagnostic = Diagnostic.Create(
                        Rule,
                        parameterListSyntax.GetLocation(),
                        parameterCount,
                        ">= 8",
                        "across multiple lines (one parameter per line)");
                    context.ReportDiagnostic(diagnostic);
                }
            }
        }
    }
}
