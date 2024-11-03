#!/bin/bash

# litup.sh - Streamlit App Deployment Script with State Management and Step Control

# State file to track progress
STATE_FILE=".litup_state"

# Function to save state
function save_state() {
    echo "$1" > "$STATE_FILE"
}

# Function to load state
function load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "START"
    fi
}

# Function to check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to confirm and run a command
function confirm_and_run() {
    local CMD="$1"
    echo "Command: $CMD"
    read -p "Run this command? (y/n): " confirm
    if [ "$confirm" == "y" ]; then
        eval "$CMD"
    else
        echo "Skipping command."
    fi
}

# Function to display usage
function usage() {
    echo "Usage: $0 [--step STEP_NAME]"
    echo "Available steps:"
    echo "  SET_SERVER_ROOT"
    echo "  CHECK_TOOLS"
    echo "  CLONE_REPO"
    echo "  SETUP_PYTHON"
    echo "  SETUP_VENV"
    echo "  ACTIVATE_VENV"
    echo "  INSTALL_REQUIREMENTS"
    echo "  INSTALL_ADDITIONAL_PIP"
    echo "  CONFIGURE_STREAMLIT"
    echo "  RUN_STREAMLIT_APP"
    echo "  CREATE_SERVICE"
    echo "  NGINX_CONFIG"
    echo "  COMPLETE"
    exit 1
}

# Parse command-line arguments
START_STEP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --step)
            if [[ -n $2 ]]; then
                START_STEP="$2"
                shift
            else
                echo "Error: --step requires a value."
                usage
            fi
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Starting the script
echo "Welcome to LitUp - Streamlit App Deployer"

# Check if previous state exists
if [ -n "$START_STEP" ]; then
    echo "Starting from step: $START_STEP"
    CURRENT_STEP="$START_STEP"
else
    if [ -f "$STATE_FILE" ]; then
        echo "A previous state was detected."
        read -p "Do you want to resume from where you left off? (y/n): " resume
        if [ "$resume" != "y" ]; then
            rm "$STATE_FILE"
            CURRENT_STEP="START"
        else
            CURRENT_STEP=$(load_state)
            echo "Resuming from step: $CURRENT_STEP"
        fi
    else
        CURRENT_STEP="START"
    fi
fi

# Steps execution
# Define the list of steps
STEPS=("SET_SERVER_ROOT" "CHECK_TOOLS" "CLONE_REPO" "SETUP_PYTHON" "SETUP_VENV" "ACTIVATE_VENV" "INSTALL_REQUIREMENTS" "INSTALL_ADDITIONAL_PIP" "CONFIGURE_STREAMLIT" "RUN_STREAMLIT_APP" "CREATE_SERVICE" "NGINX_CONFIG" "COMPLETE")

# Function to check if we should execute a step
function should_execute_step() {
    local step="$1"
    local execute=false

    # If starting from a specific step, skip steps until we reach it
    if [ -n "$START_STEP" ]; then
        if [ "$step" == "$START_STEP" ] || [ "$step_executed" == "true" ]; then
            execute=true
            step_executed="true"
        fi
    elif [ "$CURRENT_STEP" == "START" ]; then
        execute=true
    elif [ "$CURRENT_STEP" == "$step" ] || [ "$step_executed" == "true" ]; then
        execute=true
        step_executed="true"
    fi

    echo "$execute"
}

# Variable to track if we've reached the starting step
step_executed="false"

# Functions to manage the Streamlit app
function start_streamlit_app() {
    nohup streamlit run "$APP_FILE" &
    STREAMLIT_PID=$!
    echo $STREAMLIT_PID > streamlit.pid
    echo "Streamlit app started with PID $STREAMLIT_PID."
    echo "You can access it at http://<server_ip>:$STREAMLIT_PORT"
}

function stop_streamlit_app() {
    if [ -f streamlit.pid ]; then
        STREAMLIT_PID=$(cat streamlit.pid)
        kill $STREAMLIT_PID
        rm streamlit.pid
        echo "Streamlit app with PID $STREAMLIT_PID has been stopped."
    else
        echo "Streamlit app is not running or PID file not found."
    fi
}

function status_streamlit_app() {
    if [ -f streamlit.pid ]; then
        STREAMLIT_PID=$(cat streamlit.pid)
        if ps -p $STREAMLIT_PID > /dev/null; then
            echo "Streamlit app is running with PID $STREAMLIT_PID."
        else
            echo "Streamlit app PID file found but process is not running."
        fi
    else
        echo "Streamlit app is not running."
    fi
}

# Begin steps
for STEP in "${STEPS[@]}"; do

    EXECUTE_STEP=$(should_execute_step "$STEP")
    if [ "$EXECUTE_STEP" == "true" ]; then

        case $STEP in

            "SET_SERVER_ROOT")
                echo "=== Step: SET_SERVER_ROOT ==="
                SERVER_ROOT="/home/ubuntu"
                read -p "Enter the server root directory [default: $SERVER_ROOT]: " input_server_root
                if [ ! -z "$input_server_root" ]; then
                    SERVER_ROOT="$input_server_root"
                fi
                echo "Server root set to: $SERVER_ROOT"
                save_state "SET_SERVER_ROOT"
                ;;

            "CHECK_TOOLS")
                echo "=== Step: CHECK_TOOLS ==="
                REQUIRED_CMDS=("git" "python3" "pip3" "nginx" "certbot" "systemctl")
                for cmd in "${REQUIRED_CMDS[@]}"; do
                    if ! command_exists "$cmd"; then
                        read -p "$cmd is not installed. Do you want to install it? (y/n): " install_cmd
                        if [ "$install_cmd" == "y" ]; then
                            if [ "$cmd" == "certbot" ]; then
                                sudo snap install --classic certbot
                            else
                                sudo apt-get install -y "$cmd"
                            fi
                        else
                            echo "Cannot proceed without $cmd. Exiting."
                            exit 1
                        fi
                    else
                        echo "$cmd is installed."
                    fi
                done
                save_state "CHECK_TOOLS"
                ;;

            "CLONE_REPO")
                echo "=== Step: CLONE_REPO ==="
                read -p "Enter the Git repository URL: " GIT_REPO_URL
                # Extract the folder name from the repo URL
                REPO_NAME=$(basename "$GIT_REPO_URL" .git)
                cd "$SERVER_ROOT" || { echo "Cannot change to directory $SERVER_ROOT"; exit 1; }
                if [ -d "$REPO_NAME" ]; then
                    echo "Directory $REPO_NAME already exists."
                    echo "Options:"
                    echo "1) git pull"
                    echo "2) Delete and re-clone"
                    echo "3) Skip cloning"
                    read -p "Select an option (1/2/3): " repo_option
                    case $repo_option in
                        1)
                            cd "$REPO_NAME"
                            confirm_and_run "git pull"
                            cd ..
                            ;;
                        2)
                            confirm_and_run "rm -rf $REPO_NAME"
                            confirm_and_run "git clone $GIT_REPO_URL"
                            ;;
                        3)
                            echo "Skipping git clone."
                            ;;
                        *)
                            echo "Invalid option."
                            ;;
                    esac
                else
                    confirm_and_run "git clone $GIT_REPO_URL"
                fi
                save_state "CLONE_REPO"
                ;;

            "SETUP_PYTHON")
                echo "=== Step: SETUP_PYTHON ==="
                DEFAULT_PYTHON_VERSION="python3"
                read -p "Enter Python version to use for virtual environment [default: $DEFAULT_PYTHON_VERSION]: " PYTHON_VERSION
                if [ -z "$PYTHON_VERSION" ]; then
                    PYTHON_VERSION="$DEFAULT_PYTHON_VERSION"
                fi
                if ! command_exists "$PYTHON_VERSION"; then
                    echo "$PYTHON_VERSION is not installed."
                    read -p "Do you want to install $PYTHON_VERSION? (y/n): " install_python
                    if [ "$install_python" == "y" ]; then
                        sudo apt-get install -y "$PYTHON_VERSION"
                    else
                        echo "Cannot proceed without $PYTHON_VERSION. Exiting."
                        exit 1
                    fi
                fi
                save_state "SETUP_PYTHON"
                ;;

            "SETUP_VENV")
                echo "=== Step: SETUP_VENV ==="
                cd "$SERVER_ROOT/$REPO_NAME" || { echo "Cannot change to directory $REPO_NAME"; exit 1; }
                if [ -d "venv" ]; then
                    echo "Virtual environment already exists."
                    read -p "Do you want to recreate it? (y/n): " recreate_venv
                    if [ "$recreate_venv" == "y" ]; then
                        confirm_and_run "rm -rf venv"
                        confirm_and_run "$PYTHON_VERSION -m venv venv"
                    else
                        echo "Keeping existing virtual environment."
                    fi
                else
                    confirm_and_run "$PYTHON_VERSION -m venv venv"
                fi
                save_state "SETUP_VENV"
                ;;

            "ACTIVATE_VENV")
                echo "=== Step: ACTIVATE_VENV ==="
                echo "Command: source venv/bin/activate"
                read -p "Run this command? (y/n): " confirm
                if [ "$confirm" == "y" ]; then
                    source venv/bin/activate
                else
                    echo "Skipping activation of virtual environment."
                fi
                save_state "ACTIVATE_VENV"
                ;;

            "INSTALL_REQUIREMENTS")
                echo "=== Step: INSTALL_REQUIREMENTS ==="
                if [ -f "requirements.txt" ]; then
                    echo "Command: pip install -r requirements.txt"
                    read -p "Run this command? (y/n): " confirm
                    if [ "$confirm" == "y" ]; then
                        pip install -r requirements.txt
                    else
                        echo "Skipping pip install requirements.txt."
                    fi
                else
                    echo "No requirements.txt found."
                fi
                save_state "INSTALL_REQUIREMENTS"
                ;;

            "INSTALL_ADDITIONAL_PIP")
                echo "=== Step: INSTALL_ADDITIONAL_PIP ==="
                read -p "Do you want to install additional pip packages? (y/n): " install_extra_pip
                if [ "$install_extra_pip" == "y" ]; then
                    read -p "Enter pip packages to install (space-separated): " PIP_PACKAGES
                    confirm_and_run "pip install $PIP_PACKAGES"
                fi
                save_state "INSTALL_ADDITIONAL_PIP"
                ;;

            "CONFIGURE_STREAMLIT")
                echo "=== Step: CONFIGURE_STREAMLIT ==="
                DEFAULT_STREAMLIT_PORT=8501
                read -p "Enter Streamlit port [default: $DEFAULT_STREAMLIT_PORT]: " STREAMLIT_PORT
                if [ -z "$STREAMLIT_PORT" ]; then
                    STREAMLIT_PORT="$DEFAULT_STREAMLIT_PORT"
                fi
                # Configure Streamlit port using .streamlit/config.toml
                mkdir -p .streamlit
                CONFIG_FILE=".streamlit/config.toml"
                if [ -f "$CONFIG_FILE" ]; then
                    echo "$CONFIG_FILE already exists."
                    read -p "Do you want to overwrite it? (y/n): " overwrite_config
                    if [ "$overwrite_config" == "y" ]; then
                        cat > "$CONFIG_FILE" << EOL
[server]
port = $STREAMLIT_PORT
enableCORS = false
headless = true
EOL
                    else
                        echo "Appending port configuration to $CONFIG_FILE"
                        echo "port = $STREAMLIT_PORT" >> "$CONFIG_FILE"
                    fi
                else
                    echo "Creating $CONFIG_FILE with port $STREAMLIT_PORT"
                    cat > "$CONFIG_FILE" << EOL
[server]
port = $STREAMLIT_PORT
enableCORS = false
headless = true
EOL
                fi
                save_state "CONFIGURE_STREAMLIT"
                ;;

            "RUN_STREAMLIT_APP")
                echo "=== Step: RUN_STREAMLIT_APP ==="
                DEFAULT_APP_FILE="app.py"
                read -p "Enter the main app file name [default: $DEFAULT_APP_FILE]: " APP_FILE
                if [ -z "$APP_FILE" ]; then
                    APP_FILE="$DEFAULT_APP_FILE"
                fi
                FULL_APP_PATH="$SERVER_ROOT/$REPO_NAME/$APP_FILE"

                echo "Do you want to run the Streamlit app now? (This is not necessary if you are creating a systemd service)"
                read -p "(y/n): " run_now
                if [ "$run_now" == "y" ]; then
                    start_streamlit_app
                else
                    echo "Skipping running the Streamlit app manually."
                fi

                # App management menu
                while true; do
                    echo ""
                    echo "Streamlit App Management Options:"
                    echo "1) Start app"
                    echo "2) Stop app"
                    echo "3) Check app status"
                    echo "4) Continue"
                    read -p "Select an option: " app_option
                    case $app_option in
                        1)
                            start_streamlit_app
                            ;;
                        2)
                            stop_streamlit_app
                            ;;
                        3)
                            status_streamlit_app
                            ;;
                        4)
                            break
                            ;;
                        *)
                            echo "Invalid option"
                            ;;
                    esac
                done

                save_state "RUN_STREAMLIT_APP"
                ;;

            "CREATE_SERVICE")
                echo "=== Step: CREATE_SERVICE ==="
                read -p "Do you want to create a systemd service for this app? (y/n): " create_service
                if [ "$create_service" == "y" ]; then
                    # Create service file
                    SERVICE_NAME="streamlit_$REPO_NAME"
                    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
                    if [ -f "$SERVICE_FILE" ]; then
                        echo "Service file $SERVICE_FILE already exists."
                        read -p "Do you want to overwrite it? (y/n): " overwrite_service
                        if [ "$overwrite_service" != "y" ]; then
                            echo "Keeping existing service file."
                            save_state "CREATE_SERVICE"
                            continue
                        fi
                    fi
                    echo "Creating systemd service file at $SERVICE_FILE"
                    CURRENT_USER=$(whoami)
                    sudo bash -c "cat > $SERVICE_FILE" << EOL
[Unit]
Description=Streamlit App Service for $REPO_NAME
After=network.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$SERVER_ROOT/$REPO_NAME
Environment="PATH=$SERVER_ROOT/$REPO_NAME/venv/bin"
ExecStart=$SERVER_ROOT/$REPO_NAME/venv/bin/streamlit run $FULL_APP_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOL
                    # Reload systemd
                    confirm_and_run "sudo systemctl daemon-reload"
                    # Enable the service
                    confirm_and_run "sudo systemctl enable $SERVICE_NAME"
                    # Start the service
                    confirm_and_run "sudo systemctl start $SERVICE_NAME"
                    # Service management options
                    while true; do
                        echo ""
                        echo "Service Management Options:"
                        echo "1) Check status"
                        echo "2) Restart service"
                        echo "3) Stop service"
                        echo "4) Continue"
                        read -p "Select an option: " service_option
                        case $service_option in
                            1)
                                confirm_and_run "sudo systemctl status $SERVICE_NAME"
                                ;;
                            2)
                                confirm_and_run "sudo systemctl restart $SERVICE_NAME"
                                ;;
                            3)
                                confirm_and_run "sudo systemctl stop $SERVICE_NAME"
                                ;;
                            4)
                                break
                                ;;
                            *)
                                echo "Invalid option"
                                ;;
                        esac
                    done
                else
                    echo "Skipping service creation."
                fi
                save_state "CREATE_SERVICE"
                ;;

            "NGINX_CONFIG")
                echo "=== Step: NGINX_CONFIG ==="
                read -p "Enter the domain name to configure Nginx (leave blank to skip): " DOMAIN_NAME
                if [ ! -z "$DOMAIN_NAME" ]; then
                    # Create Nginx config
                    NGINX_CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN_NAME"
                    if [ -f "$NGINX_CONFIG_FILE" ]; then
                        echo "Nginx config $NGINX_CONFIG_FILE already exists."
                        read -p "Do you want to overwrite it? (y/n): " overwrite_nginx
                        if [ "$overwrite_nginx" != "y" ]; then
                            echo "Keeping existing Nginx config."
                            save_state "NGINX_CONFIG"
                            continue
                        fi
                    fi
                    echo "Creating Nginx config at $NGINX_CONFIG_FILE"
                    sudo bash -c "cat > $NGINX_CONFIG_FILE" << EOL
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:$STREAMLIT_PORT;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_read_timeout 86400;
    }
}
EOL
                    # Create symbolic link
                    if [ ! -L "/etc/nginx/sites-enabled/$DOMAIN_NAME" ]; then
                        confirm_and_run "sudo ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/"
                    else
                        echo "Symbolic link for Nginx config already exists."
                    fi
                    # Test Nginx configuration
                    confirm_and_run "sudo nginx -t"
                    # Restart Nginx
                    confirm_and_run "sudo systemctl restart nginx"
                    # Use certbot to get HTTPS
                    read -p "Do you want to obtain an SSL certificate with certbot? (y/n): " use_certbot
                    if [ "$use_certbot" == "y" ]; then
                        confirm_and_run "sudo certbot --nginx -d $DOMAIN_NAME"
                    else
                        echo "Skipping SSL certificate setup."
                    fi
                else
                    echo "Skipping Nginx configuration."
                fi
                save_state "NGINX_CONFIG"
                ;;

            "COMPLETE")
                echo "=== Step: COMPLETE ==="
                echo "Deployment completed."
                # Remove state file
                rm -f "$STATE_FILE"
                ;;

            *)
                echo "Unknown step: $STEP"
                ;;
        esac
    fi

done
