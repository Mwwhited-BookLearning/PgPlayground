namespace MyApp.Data.Entities;

public class Session
{
    public Guid Id { get; set; }
    public long UserId { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }

    public User User { get; set; } = null!;
}
