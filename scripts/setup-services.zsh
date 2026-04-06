#!/usr/bin/env zsh

# Setup Services Script
# Configure Redis and PostgreSQL

set -euo pipefail

source "${0:A:h}/../lib/logging.sh"

# Setup PostgreSQL
setup_postgresql() {
    log_info "Setting up PostgreSQL..."
    
    if brew services list | grep -q "postgresql@14.*started"; then
        log_info "PostgreSQL is already running"
    else
        log_info "Starting PostgreSQL service..."
        brew services start postgresql@14
        
        # Wait for PostgreSQL to start
        sleep 3
        
        # Create default database
        if ! psql -lqt | cut -d \| -f 1 | grep -qw "$USER"; then
            log_info "Creating default database: $USER"
            createdb "$USER" || log_warning "Database $USER might already exist"
        fi
        
        log_success "PostgreSQL setup complete"
    fi
    
    # Display connection info
    echo ""
    log_info "PostgreSQL Connection Info:"
    echo "  Host: localhost"
    echo "  Port: 5432"
    echo "  Database: $USER"
    echo "  User: $USER"
    echo "  Connection: psql -h localhost -U $USER -d $USER"
}

# Setup Redis
setup_redis() {
    log_info "Setting up Redis..."
    
    if brew services list | grep -q "redis.*started"; then
        log_info "Redis is already running"
    else
        log_info "Starting Redis service..."
        brew services start redis
        
        # Wait for Redis to start
        sleep 2
        
        # Test Redis connection
        if redis-cli ping | grep -q "PONG"; then
            log_success "Redis setup complete"
        else
            log_error "Redis setup failed"
            return 1
        fi
    fi
    
    # Display connection info
    echo ""
    log_info "Redis Connection Info:"
    echo "  Host: localhost"
    echo "  Port: 6379"
    echo "  Connection: redis-cli"
}

# Main setup
main() {
    log_info "Setting up development services..."
    
    setup_postgresql
    setup_redis
    
    echo ""
    log_success "All services setup complete!"
    log_info "Services can be managed with:"
    echo "  brew services start/stop/restart postgresql@14"
    echo "  brew services start/stop/restart redis"
}

# Run main function
main "$@"
