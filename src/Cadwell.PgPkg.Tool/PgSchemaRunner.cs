using System.Diagnostics;
using System.Text.RegularExpressions;

namespace Cadwell.PgPkg.Tool;

/// <summary>
/// Locates and invokes the pgschema binary.
/// </summary>
internal static class PgSchemaRunner
{
    // Minimum supported pgschema release.
    private static readonly Version MinimumVersion = new(1, 0, 0);

    internal static async Task<int> RunAsync(
        IEnumerable<string> arguments,
        CancellationToken ct = default)
    {
        var exe = FindPgSchema();
        await VerifyVersionAsync(exe, ct);

        using var proc = new Process
        {
            StartInfo = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
            }
        };

        foreach (var arg in arguments)
            proc.StartInfo.ArgumentList.Add(arg);

        proc.Start();
        await proc.WaitForExitAsync(ct);
        return proc.ExitCode;
    }

    private static async Task VerifyVersionAsync(string exe, CancellationToken ct)
    {
        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo(exe, "--version")
                {
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                }
            };

            proc.Start();
            var stdout = await proc.StandardOutput.ReadToEndAsync(ct);
            var stderr = await proc.StandardError.ReadToEndAsync(ct);
            await proc.WaitForExitAsync(ct);

            var raw = (stdout + stderr).Trim();
            var match = Regex.Match(raw, @"(\d+\.\d+(?:\.\d+)?)");
            if (!match.Success)
            {
                Console.Error.WriteLine($"Warning: could not parse pgschema version from: {raw}");
                return;
            }

            var found = Version.Parse(match.Groups[1].Value);
            Console.WriteLine($"pgschema {found} found at {exe}");

            if (found < MinimumVersion)
                throw new InvalidOperationException(
                    $"pgschema {found} is below the minimum required version {MinimumVersion}. " +
                    "Please upgrade: https://www.pgschema.com/installation");
        }
        catch (InvalidOperationException) { throw; }
        catch (Exception ex)
        {
            // Non-fatal: if --version fails for any reason, let the main command proceed.
            Console.Error.WriteLine($"Warning: pgschema version check failed ({ex.Message}).");
        }
    }

    private static string FindPgSchema()
    {
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var candidate = Path.Combine(dir, IsWindows ? "pgschema.exe" : "pgschema");
            if (File.Exists(candidate))
                return candidate;
        }

        var env = Environment.GetEnvironmentVariable("PGSCHEMA_PATH");
        if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
            return env;

        throw new FileNotFoundException(
            "pgschema executable not found. Install it and ensure it is on your PATH, " +
            "or set the PGSCHEMA_PATH environment variable. " +
            "See https://www.pgschema.com/installation for instructions.");
    }

    private static bool IsWindows =>
        Environment.OSVersion.Platform == PlatformID.Win32NT;
}
