# Scope

A MATLAB-based microscopy control system for automated imaging experiments, built on top of Micro-Manager.

## Overview

Scope is a comprehensive microscopy automation framework that provides high-level control over microscope hardware, fluidics systems, and imaging protocols. It's designed for complex imaging experiments including multi-channel fluorescence imaging, time-lapse studies, and automated fluidics control.

## Prerequisites

### Required Software

- **MATLAB** (R2018b or later recommended)
- **Micro-Manager** - [Download from micro-manager.org](https://micro-manager.org/)

### Micro-Manager Setup

Scope requires Micro-Manager to be properly installed and configured. Please visit [micro-manager.org](https://micro-manager.org/) to:

1. Download the latest version of Micro-Manager
2. Follow the installation instructions for your operating system
3. Configure your microscope hardware through Micro-Manager's Hardware Configuration Wizard
4. Ensure Micro-Manager is working with your specific microscope setup before using Scope

**Note**: Scope is designed to work with Micro-Manager 2.0 and later versions.

## Installation

1. **Clone or download** this repository to your local machine
2. **Add Scope to MATLAB path**:
   ```matlab
   addpath(genpath('/path/to/Scope'));
   ```
3. **Verify Micro-Manager connection**:
   ```matlab
   % Test basic Micro-Manager connectivity
   mmc = mmcore.CMMCore;
   mmc.loadSystemConfiguration();
   ```

## Quick Start

1. **Choose your microscope configuration**:
   ```matlab
   % Available scope configurations
   Scp = NinjaScope;    % For NinjaScope setup
   Scp = FutureScope;   % For FutureScope setup
   Scp = OrangeScope;   % For OrangeScope setup
   % ... and others
   ```

2. **Set up basic parameters**:
   ```matlab
   Scp.Username = 'YourName';
   Scp.Project = 'YourProject';
   Scp.Dataset = 'YourExperiment';
   ```

3. **Configure imaging parameters**:
   ```matlab
   % Set up acquisition data
   Scp.FlowData.AcqData = AcquisitionData;
   Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
   Scp.FlowData.AcqData(1).Exposure = 10;
   ```

4. **Start imaging**:
   ```matlab
   Scp.acquire(Scp.FlowData.AcqData);
   ```

## Features

- **Multi-scope support**: Pre-configured setups for various microscope configurations
- **Automated fluidics control**: Integration with fluidics systems for automated protocols
- **Advanced autofocus**: Hardware and software-based autofocus capabilities
- **Position management**: Automated position creation and management
- **Multi-channel imaging**: Support for complex multi-channel acquisition protocols
- **Time-lapse imaging**: Automated time-series acquisition
- **Data management**: Organized data storage with metadata tracking

## Examples

Check the `Examples/` directory for complete working examples:

- `example_imaging.m` - Basic imaging workflow
- `example_merfish_imaging.m` - MERFISH imaging protocol
- `example_smfish_imaging.m` - smFISH imaging protocol
- `test_timelapse.m` - Time-lapse imaging example

## Configuration

Scope uses configuration files stored in the `Configs/` directory. Each microscope setup has its own configuration file that defines:

- Hardware device mappings
- Channel configurations
- Camera settings
- Stage and objective parameters

## Troubleshooting

### Common Issues

1. **Micro-Manager not found**: Ensure Micro-Manager is properly installed and the MATLAB path includes the Micro-Manager installation directory.

2. **Hardware connection errors**: Verify your Micro-Manager hardware configuration is working before using Scope.

3. **Permission errors**: Ensure you have write permissions to the data directory.

### Getting Help

- Check the example scripts in the `Examples/` directory
- Review the configuration files in `Configs/` for your specific microscope setup
- Ensure Micro-Manager is working independently before using Scope

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Acknowledgments

- Built on top of [Micro-Manager](https://micro-manager.org/)
- Developed for the Wollman Lab at UCLA
- Supports various microscope configurations and imaging protocols

## Support

For questions and support:
1. Check the example scripts and documentation
2. Ensure Micro-Manager is properly configured
3. Review the troubleshooting section above
4. Open an issue on the project repository

---

**Important**: This software requires Micro-Manager to function. Please visit [micro-manager.org](https://micro-manager.org/) for Micro-Manager installation and setup instructions.