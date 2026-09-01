using System.IO.Compression;
using OoBDev.PgPkg.Tool;

namespace OoBDev.PgPkg.Tool.Tests;

public sealed class PgPkgPackageTests : IDisposable
{
    private readonly List<string> _tempPaths = [];

    [Fact]
    public async Task ExtractAsync_ValidPackage_ReturnsManifestAndSchemaFiles()
    {
        var pkgPath = CreatePackage(
            manifestJson: """{"databaseName":"myapp","version":"1.0.0","created":"2026-01-01T00:00:00Z"}""",
            schemaFiles: new Dictionary<string, string>
            {
                ["schema/myapp/001_init.sql"] = "CREATE TABLE foo (id int);",
            });

        var (manifest, extractedPath) = await PgPkgPackage.ExtractAsync(pkgPath);
        _tempPaths.Add(extractedPath);

        Assert.Equal("myapp", manifest.DatabaseName);
        Assert.Equal("1.0.0", manifest.Version);

        var schemaDir = PgPkgPackage.SchemaDirectory(extractedPath, manifest.DatabaseName);
        Assert.True(Directory.Exists(schemaDir));

        var sqlFile = Path.Combine(schemaDir, "001_init.sql");
        Assert.True(File.Exists(sqlFile));
        Assert.Equal("CREATE TABLE foo (id int);", await File.ReadAllTextAsync(sqlFile));
    }

    [Fact]
    public async Task ExtractAsync_MissingManifest_Throws()
    {
        var pkgPath = CreatePackage(manifestJson: null, schemaFiles: new Dictionary<string, string>
        {
            ["schema/myapp/001_init.sql"] = "CREATE TABLE foo (id int);",
        });

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => PgPkgPackage.ExtractAsync(pkgPath));
        Assert.Contains("manifest.json", ex.Message);
    }

    [Fact]
    public void SchemaDirectory_ComposesExpectedPath()
    {
        var result = PgPkgPackage.SchemaDirectory(Path.Combine("C:", "extracted"), "myapp");
        Assert.Equal(Path.Combine("C:", "extracted", "schema", "myapp"), result);
    }

    private string CreatePackage(string? manifestJson, Dictionary<string, string> schemaFiles)
    {
        var pkgPath = Path.Combine(Path.GetTempPath(), $"pgpkg-test-{Guid.NewGuid():N}.pgpkg");
        _tempPaths.Add(pkgPath);

        using (var archive = ZipFile.Open(pkgPath, ZipArchiveMode.Create))
        {
            if (manifestJson is not null)
            {
                var entry = archive.CreateEntry("manifest.json");
                using var writer = new StreamWriter(entry.Open());
                writer.Write(manifestJson);
            }

            foreach (var (path, content) in schemaFiles)
            {
                var entry = archive.CreateEntry(path);
                using var writer = new StreamWriter(entry.Open());
                writer.Write(content);
            }
        }

        return pkgPath;
    }

    public void Dispose()
    {
        foreach (var path in _tempPaths)
        {
            try
            {
                if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
                else if (File.Exists(path)) File.Delete(path);
            }
            catch { /* best effort cleanup */ }
        }
    }
}
