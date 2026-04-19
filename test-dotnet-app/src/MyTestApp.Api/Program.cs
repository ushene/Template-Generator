using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

var app = builder.Build();

// ForwardedHeaders is required behind Azure App Service / reverse proxies
// so that UseHttpsRedirection knows the original scheme was HTTPS.
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseHttpsRedirection();

// Map controllers (enables /api/health endpoints)
app.MapControllers();

// Root redirect so browsing to / shows the health status
app.MapGet("/", () => Results.Redirect("/api/health"));

app.Run();
