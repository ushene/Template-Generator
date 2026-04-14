# Example Dockerfiles for Container Deployments

This directory contains sample Dockerfiles for different languages. These can be used as starting points for containerized deployments to AKS or Azure Container Apps.

## Usage

1. Copy the appropriate Dockerfile to your project root
2. Customize the Dockerfile based on your application requirements
3. The generated CD template will automatically use the Dockerfile for AKS deployments

## .NET Dockerfile

```dockerfile
# Use the official .NET SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files and restore dependencies
COPY ["YourProject.csproj", "./"]
RUN dotnet restore "YourProject.csproj"

# Copy remaining source code and build
COPY . .
RUN dotnet build "YourProject.csproj" -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish "YourProject.csproj" -c Release -o /app/publish

# Use the runtime image for the final container
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Copy published application
COPY --from=publish /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:80

# Expose port
EXPOSE 80

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Run the application
ENTRYPOINT ["dotnet", "YourProject.dll"]
```

## Python Dockerfile

```dockerfile
# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run the application
# For Flask:
# CMD ["python", "app.py"]
# For FastAPI:
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
# For Django:
# CMD ["gunicorn", "--bind", "0.0.0.0:8000", "project.wsgi:application"]
```

## Node.js Dockerfile

```dockerfile
# Use official Node.js runtime as base image
FROM node:20-alpine AS base

# Install dependencies only
FROM base AS dependencies
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Build stage
FROM base AS build
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY . .

# Build the application (if using TypeScript or build step)
RUN npm run build || echo "No build step required"

# Final production stage
FROM base AS final
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Copy production dependencies
COPY --from=dependencies --chown=appuser:appuser /app/node_modules ./node_modules

# Copy built application
COPY --from=build --chown=appuser:appuser /app/dist ./dist
COPY --from=build --chown=appuser:appuser /app/package*.json ./

# Switch to non-root user
USER appuser

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Run the application
CMD ["node", "dist/index.js"]
# Or for non-TypeScript: CMD ["node", "index.js"]
```

## Multi-Stage Build Benefits

All these Dockerfiles use multi-stage builds to:
- Reduce final image size
- Improve security by not including build tools in production
- Separate build and runtime dependencies
- Create reproducible builds

## Security Best Practices

1. **Use official base images**: Start with official images from trusted sources
2. **Non-root user**: Run application as non-root user
3. **Minimal base images**: Use slim or alpine variants where possible
4. **Layer caching**: Order instructions to maximize cache usage
5. **Health checks**: Always include health check endpoints
6. **Security scanning**: Scan images for vulnerabilities before deployment

## Customization Tips

### Port Configuration
- Change `EXPOSE` and application port based on your app
- Ensure the port matches your Kubernetes service configuration

### Health Checks
- Update health check paths to match your application's health endpoint
- Adjust intervals and timeouts based on application startup time

### Environment Variables
- Add application-specific environment variables
- Use Kubernetes ConfigMaps and Secrets for sensitive data

### Dependencies
- Update base image versions to match your requirements
- Add any additional system packages needed by your application

## Using with Generated Templates

The generated CD templates for AKS deployments automatically:
1. Build Docker image using this Dockerfile
2. Push to Azure Container Registry
3. Deploy to AKS cluster
4. Monitor health checks

Make sure your Dockerfile is in the repository root before running the CD pipeline.
