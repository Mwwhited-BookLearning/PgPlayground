using System.IO.Compression;
using System.Text.Json;

namespace Cadwell.PgPkg.Tool;

internal sealed record PgPkgManifest(string DatabaseName, string Version, string Created);

internal static class PgPkgPackage
{
    internal static async Task<(PgPkgManifest Manifest, string ExtractedPath)> ExtractAsync(
        string packagePath, string? targetDir = null, CancellationToken ct = default)
    {
        var extractTo = targetDir ?? Path.Combine(Path.GetTempPath(), $"pgpkg-{Guid.NewGuid():N}");
        Directory.CreateDirectory(extractTo);

        ZipFile.ExtractToDirectory(packagePath, extractTo, overwriteFiles: true);

        var manifestPath = Path.Combine(extractTo, "manifest.json");
        if (!File.Exists(manifestPath))
            throw new InvalidOperationException($"Package '{packagePath}' is missing manifest.json.");

        var json = await File.ReadAllTextAsync(manifestPath, ct);
        var manifest = JsonSerializer.Deserialize<PgPkgManifest>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("Could not deserialize manifest.json.");

        return (manifest, extractTo);
    }

    internal static string SchemaDirectory(string extractedPath, string databaseName) =>
        Path.Combine(extractedPath, "schema", databaseName);
}
