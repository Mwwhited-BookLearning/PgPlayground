namespace MyApp.Data.Entities;

public class User
{
    public long Id { get; set; }
    public string Email { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; }

    public ICollection<Session> Sessions { get; set; } = [];
}
