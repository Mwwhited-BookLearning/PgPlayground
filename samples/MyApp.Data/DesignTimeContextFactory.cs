using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace MyApp.Data;

// Used only by dotnet-ef at design time (migrations add, dbcontext script, etc.)
public class DesignTimeContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var opts = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=localhost;Database=myapp_design_time")
            .Options;
        return new AppDbContext(opts);
    }
}
