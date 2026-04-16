using Microsoft.AspNetCore.Mvc;
using MyTestApp.Api.Controllers;
using Xunit;

namespace MyTestApp.Tests;

public class HealthControllerTests
{
    [Fact]
    public void Get_ReturnsOkResult()
    {
        // Arrange
        var controller = new HealthController();

        // Act
        var result = controller.Get();

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public void GetVersion_ReturnsOkResult()
    {
        // Arrange
        var controller = new HealthController();

        // Act
        var result = controller.GetVersion();

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public void Get_ReturnsNonNullValue()
    {
        // Arrange
        var controller = new HealthController();

        // Act
        var result = controller.Get() as OkObjectResult;

        // Assert
        Assert.NotNull(result);
        Assert.NotNull(result.Value);
    }
}
