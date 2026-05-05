using System.CommandLine;
using System.CommandLine.Invocation;

namespace Cadwell.PgPkg.Tool;

/// <summary>
/// pgpkg deploy — extract a .pgpkg and apply it to the target database via pgschema.
/// </summary>
internal static class DeployCommand
{
    internal static Command Build()
    {
        var packageArg = new Argument<FileInfo>("package", "Path to the .pgpkg file") { Arity = ArgumentArity.ExactlyOne };
        var connOption = new Option<string>(["--connection", "-c"], "PostgreSQL connection string") { IsRequired = true };
        var dryRunOption = new Option<bool>(["--dry-run", "-n"], "Show the diff without applying changes");
        var schemaOption = new Option<string?>(["--schema", "-s"], "Override the target schema name");

        var cmd = new Command("deploy", "Apply a .pgpkg package to a PostgreSQL database")
        {
            packageArg, connOption, dryRunOption, schemaOption
        };

        cmd.SetHandler(async (InvocationContext ctx) =>
        {
            var pkg     = ctx.ParseResult.GetValueForArgument(packageArg);
            var conn    = ctx.ParseResult.GetValueForOption(connOption)!;
            var dryRun  = ctx.ParseResult.GetValueForOption(dryRunOption);
            var schema  = ctx.ParseResult.GetValueForOption(schemaOption);
            var ct      = ctx.GetCancellationToken();

            Console.WriteLine($"Extracting {pkg.Name}…");
            var (manifest, extractedPath) = await PgPkgPackage.ExtractAsync(pkg.FullName, ct: ct);

            Console.WriteLine($"Database : {manifest.DatabaseName}  v{manifest.Version}");

            var schemaDir = PgPkgPackage.SchemaDirectory(extractedPath, manifest.DatabaseName);
            if (!Directory.Exists(schemaDir))
                throw new DirectoryNotFoundException($"Schema directory not found inside package: {schemaDir}");

            var pgArgs = new List<string> { "apply", "--dir", schemaDir, "--db", conn };
            if (schema is not null) { pgArgs.Add("--schema"); pgArgs.Add(schema); }
            if (dryRun)               pgArgs.Add("--dry-run");

            Console.WriteLine($"Running pgschema {string.Join(' ', pgArgs)}");
            var exitCode = await PgSchemaRunner.RunAsync(pgArgs, ct);

            try { Directory.Delete(extractedPath, recursive: true); } catch { /* best effort */ }

            if (exitCode != 0)
                throw new Exception($"pgschema exited with code {exitCode}.");

            Console.WriteLine(dryRun ? "Dry run complete." : "Deploy complete.");
        });

        return cmd;
    }
}
