# Changelog

All notable changes to the Template Generator Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-13

### Added
- Initial release of Template Generator Tool
- GitHub Actions workflow with interactive UI for template generation
- Support for multiple application types:
  - Azure Function Apps
  - Azure App Service
  - Azure Container Apps
  - Azure Logic Apps
  - Azure API Management
  - Azure Data & ETL Applications
  - Azure Cognitive AI Apps
- Support for three programming languages:
  - .NET
  - Python
  - Node.js
- Support for three deployment targets:
  - Azure (native services)
  - AKS (Azure Kubernetes Service)
  - IIS (Internet Information Services)
- Comprehensive CI pipeline template with:
  - Automated build and test
  - Security scanning (SonarQube & Snyk)
  - JFrog Artifactory integration
  - GitHub Actions artifacts backup
- Production-ready CD pipeline template with:
  - Environment-specific deployments
  - Pre-deployment validation
  - Health checks and smoke tests
  - Rollback support
- PowerShell-based template generation engine
- Fully parameterized templates (no hardcoded values)
- Extensive inline documentation and comments
- Auto-generated configuration guides

### Documentation
- Comprehensive README with quick start guide
- Quick Start Guide (QUICKSTART.md)
- Architecture documentation (ARCHITECTURE.md)
- Project structure examples (examples/PROJECT-STRUCTURES.md)
- Dockerfile examples (examples/DOCKERFILE-EXAMPLES.md)
- Contributing guidelines

### Security
- GitHub Secrets integration for all sensitive data
- Service principal authentication for Azure
- Encrypted credential handling
- No secrets in generated templates

---

## Future Enhancements (Planned)

### [1.1.0] - Planned
- [ ] Add GitHub Container Registry support
- [ ] Support for AWS deployments
- [ ] Add Terraform/Bicep infrastructure templates
- [ ] Integration with Azure DevOps Pipelines
- [ ] Support for multi-region deployments

### [1.2.0] - Planned
- [ ] Add monitoring and alerting templates
- [ ] Support for feature flags
- [ ] Blue-green deployment strategies
- [ ] Canary release support
- [ ] Automated rollback on health check failure

### [2.0.0] - Planned
- [ ] Web UI for template generation (instead of GitHub Actions UI)
- [ ] Template versioning and history
- [ ] Custom template plugins
- [ ] Support for on-premises deployments
- [ ] Integration with HashiCorp Vault

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## Support

For issues, questions, or feature requests, please:
1. Check existing documentation
2. Review closed issues
3. Open a new issue with detailed information

---

**Note**: This tool is under active development. Check back regularly for updates!
