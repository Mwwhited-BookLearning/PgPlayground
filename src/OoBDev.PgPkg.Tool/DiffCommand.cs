using System.CommandLine;
using System.CommandLine.Invocation;

namespace OoBDev.PgPkg.Tool;

/// <summary>
/// pgpkg diff — show the schema diff between a .pgpkg and a live database without applying.
/// </summary>
internal static class DiffCommand
{
    internal static Command Build()
    {
        var packageArg = new Argument<FileInfo>("package", "Path to the .pgpkg file") { Arity = ArgumentArity.ExactlyOne };
        var connOption = new Option<string>(["--connection", "-c"], "PostgreSQL connection string") { IsRequired = true };

        var cmd = new Command("diff", "Show schema differences between a .pgpkg and a live database")
        {
            packageArg, connOption
        };

        cmd.SetHandler(async (InvocationContext ctx) =>
        {
            var pkg  = ctx.ParseResult.GetValueForArgument(packageArg);
            var conn = ctx.ParseResult.GetValueForOption(connOption)!;
            var ct   = ctx.GetCancellationToken();

            var (manifest, extractedPath) = await PgPkgPackage.ExtractAsync(pkg.FullName, ct: ct);
            Console.WriteLine($"Database : {manifest.DatabaseName}  v{manifest.Version}");

            var schemaDir = PgPkgPackage.SchemaDirectory(extractedPath, manifest.DatabaseName);
            var pgArgs = new[] { "diff", "--dir", schemaDir, "--db", conn };

            Console.WriteLine($"Running pgschema {string.Join(' ', pgArgs)}");
            var exitCode = await PgSchemaRunner.RunAsync(pgArgs, ct);

            try { Directory.Delete(extractedPath, recursive: true); } catch { /* best effort */ }

            if (exitCode != 0)
                throw new Exception($"pgschema exited with code {exitCode}.");
        });

        return cmd;
    }
}
