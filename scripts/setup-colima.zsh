#!/usr/bin/env zsh

# Setup Colima Script
# Configure Colima for container development

set -euo pipefail

source "${0:A:h}/../lib/logging.sh"

# Check if Colima is installed
check_colima() {
    if ! command -v colima &> /dev/null; then
        log_error "Colima is not installed. Please install it first with: brew install colima"
        exit 1
    fi
}

# Setup Colima
setup_colima() {
    log_info "Setting up Colima..."
    
    # Check if Colima is already running
    if colima status &> /dev/null; then
        log_info "Colima is already running"
        return 0
    fi
    
    # Start Colima with optimized settings
    log_info "Starting Colima with optimized settings..."
    colima start \
        --cpu 4 \
        --memory 8 \
        --disk 60 \
        --vm-type=vz \
        --mount-type=virtiofs
    
    # Wait for Colima to start
    sleep 5
    
    # Verify Docker is working
    if docker info &> /dev/null; then
        log_success "Colima and Docker setup complete"
    else
        log_error "Docker is not responding. Colima setup may have failed."
        return 1
    fi
}

# Configure Docker context
configure_docker_context() {
    log_info "Configuring Docker context..."
    
    # Set Colima as the default Docker context
    if docker context list | grep -q colima; then
        docker context use colima
        log_success "Docker context set to Colima"
    else
        log_warning "Colima Docker context not found"
    fi
}

# Create useful Docker aliases and functions
create_docker_helpers() {
    log_info "Docker helper functions are available in functions.zsh"
}

# Display usage information
display_usage() {
    echo ""
    log_info "Colima Usage:"
    echo "  colima start          - Start Colima VM"
    echo "  colima stop           - Stop Colima VM"
    echo "  colima restart        - Restart Colima VM"
    echo "  colima status         - Check Colima status"
    echo "  colima ssh            - SSH into Colima VM"
    echo ""
    log_info "Docker is now available via Colima!"
    echo "  docker run hello-world"
    echo "  docker-compose up -d"
}

# Main setup
main() {
    log_info "Setting up Colima for container development..."
    
    check_colima
    setup_colima
    configure_docker_context
    create_docker_helpers
    display_usage
    
    log_success "Colima setup complete!"
}

# Run main function
main "$@"
