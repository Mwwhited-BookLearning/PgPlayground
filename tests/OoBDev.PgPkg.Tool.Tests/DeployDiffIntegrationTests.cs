using System.CommandLine;
using Npgsql;
using Testcontainers.PostgreSql;

namespace OoBDev.PgPkg.Tool.Tests;

/// <summary>
/// End-to-end: deploy a built .pgpkg into a real Postgres container via pgschema,
/// then confirm diff reports it clean. Requires Docker and a pgschema executable
/// on PATH/PGSCHEMA_PATH (see PgSchemaFactAttribute) — pgschema has no Windows build.
/// </summary>
public sealed class DeployDiffIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:18-alpine")
        .WithDatabase("myapp")
        .WithUsername("myapp")
        .WithPassword("myapp")
        .Build();

    private string _pkgPath = "";

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        await TestSupport.RunAsync("dotnet", [
            "pack",
            Path.Combine(TestSupport.RepoRoot, "src", "OoBDev.PgPkg.Sdk", "OoBDev.PgPkg.Sdk.csproj"),
            "-o", Path.Combine(TestSupport.RepoRoot, "local-feed"),
        ]);

        var dbProject = Path.Combine(TestSupport.RepoRoot, "samples", "MyApp.Database", "MyApp.Database.pgpkgproj");
        await TestSupport.RunAsync("dotnet", ["build", dbProject]);

        _pkgPath = Path.Combine(TestSupport.RepoRoot, "samples", "MyApp.Database", "bin", "Debug", "MyApp.Database-1.0.0.pgpkg");
    }

    public Task DisposeAsync() => _postgres.DisposeAsync().AsTask();

    [PgSchemaFact]
    public async Task Deploy_ThenDiff_AppliesSchemaAndReportsClean()
    {
        var connString = _postgres.GetConnectionString();

        var deployExit = await RunPgPkgAsync("deploy", _pkgPath, "--connection", connString);
        Assert.Equal(0, deployExit);

        await using var conn = new NpgsqlConnection(connString);
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand(
            "select count(*) from information_schema.tables where table_schema = 'public'", conn);
        var tableCount = (long)(await cmd.ExecuteScalarAsync())!;
        Assert.True(tableCount > 0, "Expected deploy to create at least one table.");

        var diffExit = await RunPgPkgAsync("diff", _pkgPath, "--connection", connString);
        Assert.Equal(0, diffExit);
    }

    private static Task<int> RunPgPkgAsync(params string[] args)
    {
        var root = new RootCommand();
        root.AddCommand(DeployCommand.Build());
        root.AddCommand(DiffCommand.Build());
        return root.InvokeAsync(args);
    }
}
