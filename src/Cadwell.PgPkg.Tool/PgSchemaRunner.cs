using System.Diagnostics;

namespace Cadwell.PgPkg.Tool;

/// <summary>
/// Locates and invokes the pgschema binary.
/// </summary>
internal static class PgSchemaRunner
{
    internal static async Task<int> RunAsync(
        IEnumerable<string> arguments,
        CancellationToken ct = default)
    {
        var exe = FindPgSchema();

        using var proc = new Process
        {
            StartInfo = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
                RedirectStandardOutput = false,
                RedirectStandardError = false,
            }
        };

        foreach (var arg in arguments)
            proc.StartInfo.ArgumentList.Add(arg);

        proc.Start();
        await proc.WaitForExitAsync(ct);
        return proc.ExitCode;
    }

    private static string FindPgSchema()
    {
        // Check PATH first so users can override with their own build
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var candidate = Path.Combine(dir, IsWindows ? "pgschema.exe" : "pgschema");
            if (File.Exists(candidate))
                return candidate;
        }

        // Fallback: check PGSCHEMA_PATH env var
        var env = Environment.GetEnvironmentVariable("PGSCHEMA_PATH");
        if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
            return env;

        throw new FileNotFoundException(
            "pgschema executable not found. Install it and ensure it is on your PATH, " +
            "or set the PGSCHEMA_PATH environment variable.");
    }

    private static bool IsWindows =>
        Environment.OSVersion.Platform == PlatformID.Win32NT;
}
