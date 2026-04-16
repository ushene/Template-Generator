using Microsoft.AspNetCore.Mvc;

namespace MyTestApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new 
        { 
            status = "healthy",
            timestamp = DateTime.UtcNow,
            version = "1.0.0",
            service = "MyTestApp.Api"
        });
    }

    [HttpGet("version")]
    public IActionResult GetVersion()
    {
        return Ok(new 
        { 
            version = "1.0.0",
            buildNumber = Environment.GetEnvironmentVariable("BUILD_NUMBER") ?? "local"
        });
    }
}
