using Microsoft.EntityFrameworkCore;
using MyApp.Data;

// Usage: SchemaScript <output-file>
// Generates CREATE TABLE / CREATE INDEX SQL from the AppDbContext model
// without EF migration history — pure desired-state schema.

try
{
    var outputPath = args.Length > 0 ? args[0] : "schema.sql";

    var opts = new DbContextOptionsBuilder<AppDbContext>()
        .UseNpgsql("Host=localhost;Database=design_time_only")
        .Options;

    await using var ctx = new AppDbContext(opts);

    var sql = ctx.Database.GenerateCreateScript();

    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    await File.WriteAllTextAsync(outputPath, sql);

    Console.WriteLine($"Schema written to {outputPath}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: {ex}");
    return 1;
}

return 0;
