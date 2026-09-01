using System.CommandLine;
using OoBDev.PgPkg.Tool;

namespace OoBDev.PgPkg.Tool.Tests;

public sealed class PublishCommandTests : IDisposable
{
    private readonly List<string> _tempPaths = [];

    [Fact]
    public async Task Publish_ToLocalDirectory_CopiesPackage()
    {
        var pkgPath = Path.Combine(Path.GetTempPath(), $"pub-src-{Guid.NewGuid():N}.pgpkg");
        File.WriteAllText(pkgPath, "not a real zip, just bytes for the copy check");
        _tempPaths.Add(pkgPath);

        var destDir = Path.Combine(Path.GetTempPath(), $"pub-dest-{Guid.NewGuid():N}");
        _tempPaths.Add(destDir);

        var exitCode = await InvokeAsync("publish", pkgPath, "--source", destDir);

        Assert.Equal(0, exitCode);
        var destFile = Path.Combine(destDir, Path.GetFileName(pkgPath));
        Assert.True(File.Exists(destFile));
        Assert.Equal(File.ReadAllText(pkgPath), File.ReadAllText(destFile));
    }

    [Fact]
    public async Task Publish_NonexistentPackage_FailsWithNonZeroExitCode()
    {
        var missingPkg = Path.Combine(Path.GetTempPath(), $"does-not-exist-{Guid.NewGuid():N}.pgpkg");
        var destDir = Path.Combine(Path.GetTempPath(), $"pub-dest-{Guid.NewGuid():N}");
        _tempPaths.Add(destDir);

        var exitCode = await InvokeAsync("publish", missingPkg, "--source", destDir);

        Assert.NotEqual(0, exitCode);
    }

    private static Task<int> InvokeAsync(params string[] args)
    {
        var root = new RootCommand();
        root.AddCommand(PublishCommand.Build());
        return root.InvokeAsync(args);
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
