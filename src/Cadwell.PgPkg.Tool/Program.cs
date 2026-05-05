using System.CommandLine;
using Cadwell.PgPkg.Tool;

var rootCommand = new RootCommand("pgpkg — PostgreSQL desired-state package deployer");

rootCommand.AddCommand(DeployCommand.Build());
rootCommand.AddCommand(PublishCommand.Build());
rootCommand.AddCommand(DiffCommand.Build());

return await rootCommand.InvokeAsync(args);
