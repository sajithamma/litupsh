# LitUp - Streamlit App Deployer

LitUp is a Bash script designed to simplify the deployment of Streamlit applications on Ubuntu servers. It automates the setup process, including environment configuration, application setup, and deployment using systemd and Nginx. This script allows developers to quickly host any Streamlit app on an Ubuntu server.

## Features

- **Automated Installation**: Installs required tools and packages if they are missing.
- **Git Repository Cloning**: Clones your Streamlit app repository.
- **Virtual Environment Setup**: Creates and manages a Python virtual environment.
- **Streamlit Configuration**: Configures Streamlit settings and checks for port availability.
- **Service Creation**: Sets up a systemd service for your app.
- **Nginx Configuration**: Configures Nginx with a 512MB file upload limit and sets up SSL using Certbot.
- **State Management**: Allows resuming the script from any step in case of interruptions.

## Prerequisites

- An Ubuntu server with `sudo` privileges.
- A Streamlit application hosted in a Git repository.
- A domain name pointed to your server's IP address (optional, for SSL setup).

## Installation

1. **Download the `litup.sh` script** to your server:

   ```bash
   wget https://raw.githubusercontent.com/yourusername/yourrepository/main/litup.sh

2. Make the script executable:

```bash
chmod +x litup.sh
```

## Usage

```bash
./litup.sh
```

## Command-Line Arguments

* --step STEP_NAME: Start the script from a specific step.
* --currentstate: Display the current state and exit.

Example:
```bash
./litup.sh --step NGINX_CONFIG
```

## Available Steps

Available Steps
SET_SERVER_ROOT
CHECK_TOOLS
CLONE_REPO
CREATE_ENV_FILE
SETUP_PYTHON
SETUP_VENV
ACTIVATE_VENV
INSTALL_REQUIREMENTS
INSTALL_ADDITIONAL_PIP
CONFIGURE_STREAMLIT
RUN_STREAMLIT_APP
CREATE_SERVICE
NGINX_CONFIG
COMPLETE

## Step-by-Step Guide
### 1. Set Server Root Directory
Set the directory where the application will be deployed. The default is /home/ubuntu.

### 2. Check and Install Required Tools
The script checks for required tools and installs any that are missing. Required tools include:

git
python3
pip3
nginx
certbot
systemctl
lsof
curl
dig

### 3. Clone the Git Repository
Enter the URL of your Streamlit app's Git repository. The script will clone the repository into the server root directory.

### 4. Create or Edit .env File
Optionally create or edit a .env file for environment variables inside your project directory.

### 5. Set Up Python Environment
Specify the Python version to use for the virtual environment.

### 6. Set Up Virtual Environment
Create a virtual environment for the application using the specified Python version.

### . Activate Virtual Environment
Activate the virtual environment to install packages within it.

### 8. Install Python Packages
Install required packages from requirements.txt and any additional packages you specify.

### 9. Configure Streamlit
Configure Streamlit settings, including the port number. The script checks if the chosen port is available.

### 10. Run Streamlit App
Optionally run the app manually. The script provides options to start, stop, or check the status of the app.

### 11. Create systemd Service
Create a systemd service to manage the app, allowing it to start on boot and be managed by systemctl.

### 12. Configure Nginx
Set up Nginx to proxy requests to the Streamlit app and configure SSL using Certbot. The script includes a file upload limit of 512MB.

### 13. Complete
Deployment is complete. The script removes the state file.

## Notes
State Management: The script uses a state file .litup_state to track progress. If the script is interrupted, you can resume from the last step.
To start over, delete the .litup_state file:
```bash
rm .litup_state
```

Domain Name Resolution: Ensure your domain name's DNS records point to your server's IP address before running the Nginx configuration step.
Port Availability: The script checks if the chosen Streamlit port is in use and suggests choosing a different one if necessary.
Troubleshooting
Port Already in Use: If the chosen Streamlit port is in use, select a different port when prompted.
Domain Name Resolution: Verify that your domain name resolves to your server's IP address using:
```bash
dig +short yourdomain.com
```

SSL Certificate Issues: Ensure that ports 80 and 443 are open in your server's firewall.

# License
This project is licensed under the MIT License.

# Contributing
Contributions are welcome! Please open an issue or submit a pull request.



