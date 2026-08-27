using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CodeActions;
using Microsoft.CodeAnalysis.CodeFixes;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Diagnostics;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace DiGi.Maintenance.Analyzers.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Validates that single-line parameter lists with 1-7 parameters produce zero diagnostics.
        /// </summary>
        [Fact]
        public async Task ParameterList_LessThanEight_SingleLine_PassesAsync()
        {
            string sourceCode = @"
namespace TestNamespace
{
    public class TestClass
    {
        public void TestMethod(int param1, double param2, string param3)
        {
        }
    }
}";

            IReadOnlyList<Diagnostic> diagnostics = await GetDiagnosticsAsync(sourceCode);
            Assert.Empty(diagnostics);
        }

        /// <summary>
        /// Validates that multi-line parameter lists with 1-7 parameters produce a DIGI0001 diagnostic and code fix reflows onto a single line.
        /// </summary>
        [Fact]
        public async Task ParameterList_LessThanEight_MultiLine_FailsAndFixesAsync()
        {
            string sourceCode = @"
namespace TestNamespace
{
    public class TestClass
    {
        public void TestMethod(
            int param1,
            double param2,
            string param3)
        {
        }
    }
}";

            IReadOnlyList<Diagnostic> diagnostics = await GetDiagnosticsAsync(sourceCode);
            Assert.Single(diagnostics);
            Assert.Equal("DIGI0001", diagnostics[0].Id);

            string fixedCode = await ApplyCodeFixAsync(sourceCode, diagnostics[0]);
            Assert.Contains("public void TestMethod(int param1, double param2, string param3)", fixedCode);
        }

        /// <summary>
        /// Validates that multi-line parameter lists with 8 or more parameters produce zero diagnostics when formatted one parameter per line.
        /// </summary>
        [Fact]
        public async Task ParameterList_EightOrMore_MultiLine_PassesAsync()
        {
            string sourceCode = @"
namespace TestNamespace
{
    public class TestClass
    {
        public void TestMethod(
            int param1,
            int param2,
            int param3,
            int param4,
            int param5,
            int param6,
            int param7,
            int param8)
        {
        }
    }
}";

            IReadOnlyList<Diagnostic> diagnostics = await GetDiagnosticsAsync(sourceCode);
            Assert.Empty(diagnostics);
        }

        /// <summary>
        /// Validates that single-line parameter lists with 8 or more parameters produce a DIGI0001 diagnostic and code fix reflows across multiple lines.
        /// </summary>
        [Fact]
        public async Task ParameterList_EightOrMore_SingleLine_FailsAndFixesAsync()
        {
            string sourceCode = @"
namespace TestNamespace
{
    public class TestClass
    {
        public void TestMethod(int param1, int param2, int param3, int param4, int param5, int param6, int param7, int param8)
        {
        }
    }
}";

            IReadOnlyList<Diagnostic> diagnostics = await GetDiagnosticsAsync(sourceCode);
            Assert.Single(diagnostics);
            Assert.Equal("DIGI0001", diagnostics[0].Id);

            string fixedCode = await ApplyCodeFixAsync(sourceCode, diagnostics[0]);
            Assert.Contains("int param1,", fixedCode);
            Assert.Contains("int param8", fixedCode);
        }

        /// <summary>
        /// Validates that multi-line parameter lists with 8 or more parameters where parameters share lines produce a DIGI0001 diagnostic and code fix reflows to one parameter per line.
        /// </summary>
        [Fact]
        public async Task ParameterList_EightOrMore_MultiplePerLine_FailsAndFixesAsync()
        {
            string sourceCode = @"
namespace TestNamespace
{
    public class TestClass
    {
        public void TestMethod(
            int param1, int param2,
            int param3, int param4,
            int param5, int param6,
            int param7, int param8)
        {
        }
    }
}";

            IReadOnlyList<Diagnostic> diagnostics = await GetDiagnosticsAsync(sourceCode);
            Assert.Single(diagnostics);
            Assert.Equal("DIGI0001", diagnostics[0].Id);

            string fixedCode = await ApplyCodeFixAsync(sourceCode, diagnostics[0]);
            Assert.Contains("int param1,", fixedCode);
            Assert.Contains("int param8", fixedCode);
        }

        private static async Task<IReadOnlyList<Diagnostic>> GetDiagnosticsAsync(string sourceCode)
        {
            SyntaxTree syntaxTree = CSharpSyntaxTree.ParseText(sourceCode);
            CSharpCompilation compilation = CSharpCompilation.Create(
                "TestAssembly",
                [syntaxTree],
                [MetadataReference.CreateFromFile(typeof(object).Assembly.Location)],
                new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

            ParameterListLineBreakAnalyzer analyzer = new();
            CompilationWithAnalyzers compilationWithAnalyzers = compilation.WithAnalyzers(ImmutableArray.Create<DiagnosticAnalyzer>(analyzer));
            ImmutableArray<Diagnostic> diagnostics = await compilationWithAnalyzers.GetAnalyzerDiagnosticsAsync();

            List<Diagnostic> listDiagnostics_Filtered = [];
            foreach (Diagnostic diagnostic in diagnostics)
            {
                if (diagnostic.Id == ParameterListLineBreakAnalyzer.DiagnosticId)
                {
                    listDiagnostics_Filtered.Add(diagnostic);
                }
            }

            return listDiagnostics_Filtered;
        }

        private static async Task<string> ApplyCodeFixAsync(string sourceCode, Diagnostic diagnostic)
        {
            AdhocWorkspace workspace = new();
            Project project = workspace.AddProject("TestProject", LanguageNames.CSharp)
                .AddMetadataReference(MetadataReference.CreateFromFile(typeof(object).Assembly.Location))
                .WithCompilationOptions(new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

            Document document = project.AddDocument("TestFile.cs", sourceCode);
            CodeFixes.ParameterListLineBreakCodeFixProvider codeFixProvider = new();
            List<CodeAction> listCodeActions = [];

            CodeFixContext context = new(
                document,
                diagnostic,
                (action, diags) => listCodeActions.Add(action),
                CancellationToken.None);

            await codeFixProvider.RegisterCodeFixesAsync(context);

            if (listCodeActions.Count == 0)
            {
                return sourceCode;
            }

            ImmutableArray<CodeActionOperation> operations = await listCodeActions[0].GetOperationsAsync(CancellationToken.None);
            ApplyChangesOperation? applyChangesOperation = operations.OfType<ApplyChangesOperation>().FirstOrDefault();
            if (applyChangesOperation == null)
            {
                return sourceCode;
            }

            applyChangesOperation.Apply(workspace, CancellationToken.None);
            Document document_Updated = workspace.CurrentSolution.GetDocument(document.Id)!;
            SyntaxNode? root_Updated = await document_Updated.GetSyntaxRootAsync();
            return root_Updated?.ToFullString() ?? sourceCode;
        }
    }
}
