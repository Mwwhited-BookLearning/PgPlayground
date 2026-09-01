namespace OoBDev.PgPkg.Tool.Tests;

/// <summary>
/// A [Fact] that skips itself when the pgschema executable is not resolvable.
/// pgschema ships Linux/macOS binaries only, so this always skips on native Windows.
/// </summary>
public sealed class PgSchemaFactAttribute : FactAttribute
{
    public PgSchemaFactAttribute()
    {
        if (!TestSupport.IsPgSchemaAvailable())
        {
            Skip = "pgschema not found on PATH or PGSCHEMA_PATH. It has no native Windows build " +
                   "(Linux/macOS only, or run under WSL) — install it to exercise this test: " +
                   "https://github.com/pgplex/pgschema/releases";
        }
    }
}
