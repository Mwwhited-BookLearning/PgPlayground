namespace MyApp.Data.Entities;

public class AuditLog
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public string Action { get; set; } = null!;
    public string TableName { get; set; } = null!;
    public string? RecordId { get; set; }
    public DateTimeOffset OccurredAt { get; set; }

    public User User { get; set; } = null!;
}
