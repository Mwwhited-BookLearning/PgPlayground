using Microsoft.EntityFrameworkCore;
using MyApp.Data.Entities;

namespace MyApp.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users { get; set; }
    public DbSet<Session> Sessions { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(e =>
        {
            e.ToTable("users");
            e.HasKey(u => u.Id);
            e.Property(u => u.Id).HasColumnName("id").UseIdentityByDefaultColumn();
            e.Property(u => u.Email).HasColumnName("email").IsRequired();
            e.HasIndex(u => u.Email).IsUnique();
            e.Property(u => u.CreatedAt).HasColumnName("created_at")
                .HasDefaultValueSql("now()");
        });

        modelBuilder.Entity<Session>(e =>
        {
            e.ToTable("sessions");
            e.HasKey(s => s.Id);
            e.Property(s => s.Id).HasColumnName("id").HasDefaultValueSql("gen_random_uuid()");
            e.Property(s => s.UserId).HasColumnName("user_id");
            e.Property(s => s.ExpiresAt).HasColumnName("expires_at");
            e.HasOne(s => s.User)
                .WithMany(u => u.Sessions)
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
