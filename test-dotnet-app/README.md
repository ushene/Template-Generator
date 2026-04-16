# MyTestApp - .NET Test Application

This is a simple .NET Web API application created to test GitHub Actions CI/CD templates.

## Project Structure

```
test-dotnet-app/
├── src/
│   └── MyTestApp.Api/          # Main Web API project
│       └── Controllers/
│           └── HealthController.cs
├── tests/
│   └── MyTestApp.Tests/        # Unit tests
│       └── HealthControllerTests.cs
└── MyTestApp.sln               # Solution file
```

## Features

- ✅ ASP.NET Core Web API (.NET 8.0)
- ✅ Health check endpoint: `GET /api/health`
- ✅ Version endpoint: `GET /api/health/version`
- ✅ Unit tests with xUnit
- ✅ Ready for CI/CD with GitHub Actions

## Running Locally

### Build the application
```powershell
dotnet build
```

### Run tests
```powershell
dotnet test
```

### Run the API
```powershell
cd src/MyTestApp.Api
dotnet run
```

Then visit: `http://localhost:5000/api/health`

## Endpoints

### GET /api/health
Returns health status of the application.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-04-15T12:00:00Z",
  "version": "1.0.0",
  "service": "MyTestApp.Api"
}
```

### GET /api/health/version
Returns version information.

**Response:**
```json
{
  "version": "1.0.0",
  "buildNumber": "123"
}
```

## Using with GitHub Actions

This app is designed to work with the generated CI/CD templates:

1. Copy the `generated/.github` folder to this project root
2. Update the `APP_NAME` in `build.yml` to `"MyTestApp"`
3. Configure GitHub secrets (JFROG_*, AZURE_*)
4. Push to GitHub and watch the workflow run!

## Testing the CI Pipeline

The CI pipeline will:
- ✅ Checkout code
- ✅ Setup .NET SDK
- ✅ Restore dependencies
- ✅ Build the solution
- ✅ Run unit tests (3 tests should pass)
- ✅ Package the application
- ✅ Publish to JFrog Artifactory

## Testing the CD Pipeline

The CD pipeline will:
- ✅ Download artifacts from JFrog
- ✅ Deploy to Azure App Service
- ✅ Run health check against `/api/health`
- ✅ Verify deployment success
