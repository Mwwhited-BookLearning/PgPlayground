using Microsoft.EntityFrameworkCore;
using MyApp.Data.Entities;

namespace MyApp.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users { get; set; }
    public DbSet<Session> Sessions { get; set; }
    public DbSet<AuditLog> AuditLogs { get; set; }

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

        modelBuilder.Entity<AuditLog>(e =>
        {
            e.ToTable("audit_logs");
            e.HasKey(a => a.Id);
            e.Property(a => a.Id).HasColumnName("id").UseIdentityByDefaultColumn();
            e.Property(a => a.UserId).HasColumnName("user_id");
            e.Property(a => a.Action).HasColumnName("action").IsRequired();
            e.Property(a => a.TableName).HasColumnName("table_name").IsRequired();
            e.Property(a => a.RecordId).HasColumnName("record_id");
            e.Property(a => a.OccurredAt).HasColumnName("occurred_at")
                .HasDefaultValueSql("now()");
            e.HasOne(a => a.User)
                .WithMany()
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(a => new { a.TableName, a.RecordId });
            e.HasIndex(a => a.OccurredAt);
        });
    }
}
