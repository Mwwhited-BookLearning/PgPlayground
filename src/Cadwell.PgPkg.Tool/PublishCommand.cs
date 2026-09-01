using System.CommandLine;
using System.CommandLine.Invocation;

namespace Cadwell.PgPkg.Tool;

/// <summary>
/// pgpkg publish — push a .pgpkg to a package feed (NuGet or local directory).
/// </summary>
internal static class PublishCommand
{
    internal static Command Build()
    {
        var packageArg = new Argument<FileInfo>("package", "Path to the .pgpkg file") { Arity = ArgumentArity.ExactlyOne };
        var sourceOption = new Option<string>(["--source", "-s"], "Feed URL or local path") { IsRequired = true };
        var apiKeyOption = new Option<string?>(["--api-key", "-k"], "API key for the feed");

        var cmd = new Command("publish", "Push a .pgpkg to a feed or local directory")
        {
            packageArg, sourceOption, apiKeyOption
        };

        cmd.SetHandler(async (InvocationContext ctx) =>
        {
            var pkg    = ctx.ParseResult.GetValueForArgument(packageArg);
            var source = ctx.ParseResult.GetValueForOption(sourceOption)!;
            var apiKey = ctx.ParseResult.GetValueForOption(apiKeyOption);
            var ct     = ctx.GetCancellationToken();

            if (!pkg.Exists)
                throw new FileNotFoundException($"Package not found: {pkg.FullName}");

            // Local directory feed. A local path (existing or not) still parses as a valid
            // absolute file:// URI, so only http(s) counts as a remote feed.
            var isRemote = Uri.TryCreate(source, UriKind.Absolute, out var sourceUri)
                && (sourceUri.Scheme == Uri.UriSchemeHttp || sourceUri.Scheme == Uri.UriSchemeHttps);

            if (!isRemote)
            {
                var dest = Path.Combine(source, pkg.Name);
                Directory.CreateDirectory(source);
                File.Copy(pkg.FullName, dest, overwrite: true);
                Console.WriteLine($"Published to {dest}");
                return;
            }

            // Remote feed via dotnet nuget push (treats .pgpkg like a .nupkg blob)
            var dotnetArgs = new List<string> { "nuget", "push", pkg.FullName, "--source", source };
            if (apiKey is not null) { dotnetArgs.Add("--api-key"); dotnetArgs.Add(apiKey); }

            using var proc = new System.Diagnostics.Process
            {
                StartInfo = new System.Diagnostics.ProcessStartInfo("dotnet") { UseShellExecute = false }
            };
            foreach (var a in dotnetArgs) proc.StartInfo.ArgumentList.Add(a);
            proc.Start();
            await proc.WaitForExitAsync(ct);

            if (proc.ExitCode != 0)
                throw new Exception($"dotnet nuget push exited with code {proc.ExitCode}.");

            Console.WriteLine("Published.");
        });

        return cmd;
    }
}
