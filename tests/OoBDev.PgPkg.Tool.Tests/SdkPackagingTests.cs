using System.IO.Compression;
using System.Text.Json;

namespace OoBDev.PgPkg.Tool.Tests;

/// <summary>
/// Builds the real sample .pgpkgproj through MSBuild and inspects the resulting
/// .pgpkg, exercising the SDK end-to-end the same way a consumer would.
/// </summary>
public sealed class SdkPackagingTests
{
    [Fact]
    public async Task Build_SampleDatabaseProject_ProducesPgPkgWithManifestAndSchema()
    {
        await TestSupport.RunAsync("dotnet", [
            "pack",
            Path.Combine(TestSupport.RepoRoot, "src", "OoBDev.PgPkg.Sdk", "OoBDev.PgPkg.Sdk.csproj"),
            "-o", Path.Combine(TestSupport.RepoRoot, "local-feed"),
        ]);

        var dbProject = Path.Combine(TestSupport.RepoRoot, "samples", "MyApp.Database", "MyApp.Database.pgpkgproj");
        await TestSupport.RunAsync("dotnet", ["build", dbProject]);

        var pkgPath = Path.Combine(TestSupport.RepoRoot, "samples", "MyApp.Database", "bin", "Debug", "MyApp.Database-1.0.0.pgpkg");
        Assert.True(File.Exists(pkgPath), $"Expected package at {pkgPath}");

        var extractDir = Path.Combine(Path.GetTempPath(), $"sdk-pack-check-{Guid.NewGuid():N}");
        ZipFile.ExtractToDirectory(pkgPath, extractDir);
        try
        {
            var manifestPath = Path.Combine(extractDir, "manifest.json");
            Assert.True(File.Exists(manifestPath));

            using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(manifestPath));
            Assert.Equal("myapp", doc.RootElement.GetProperty("databaseName").GetString());
            Assert.Equal("1.0.0", doc.RootElement.GetProperty("version").GetString());

            var schemaDir = Path.Combine(extractDir, "schema", "myapp");
            Assert.True(Directory.Exists(schemaDir));

            var sqlFiles = Directory.GetFiles(schemaDir, "*.sql");
            Assert.NotEmpty(sqlFiles);
            var combinedSql = string.Concat(await Task.WhenAll(sqlFiles.Select(f => File.ReadAllTextAsync(f))));
            Assert.Contains("CREATE TABLE", combinedSql, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            try { Directory.Delete(extractDir, recursive: true); } catch { /* best effort */ }
        }
    }
}
