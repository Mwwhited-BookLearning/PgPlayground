using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace OoBDev.PgPkg.Tool.Tests;

internal static class TestSupport
{
    internal static readonly string RepoRoot = GetRepoRoot();

    internal static async Task RunAsync(string exe, IEnumerable<string> args)
    {
        using var proc = new Process
        {
            StartInfo = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            }
        };
        foreach (var a in args) proc.StartInfo.ArgumentList.Add(a);

        proc.Start();
        var stdout = await proc.StandardOutput.ReadToEndAsync();
        var stderr = await proc.StandardError.ReadToEndAsync();
        await proc.WaitForExitAsync();

        if (proc.ExitCode != 0)
            throw new InvalidOperationException(
                $"'{exe} {string.Join(' ', args)}' failed ({proc.ExitCode}):\n{stdout}\n{stderr}");
    }

    internal static bool IsPgSchemaAvailable()
    {
        var exeName = OperatingSystem.IsWindows() ? "pgschema.exe" : "pgschema";
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (dir.Length > 0 && File.Exists(Path.Combine(dir, exeName)))
                return true;
        }

        var env = Environment.GetEnvironmentVariable("PGSCHEMA_PATH");
        return !string.IsNullOrWhiteSpace(env) && File.Exists(env);
    }

    private static string GetRepoRoot([CallerFilePath] string here = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(here)!, "..", ".."));
}
