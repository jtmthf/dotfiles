#!/usr/bin/env zsh

# Setup Colima Script
# Configure Colima for container development.
#
# This script is idempotent and reconciles on every run: if the VM is already
# running with settings that drift from the desired values below, it reports the
# drift instead of silently skipping. It never restarts a running VM on its own,
# because that would kill in-flight containers.

set -euo pipefail

source "${0:A:h}/../lib/logging.sh"

# --- Desired VM configuration -------------------------------------------------
# Edit these; the script reconciles against them.
#
# CPU/memory are safe to change later — they apply on the next VM restart.
# vm-type and mount-type are FIXED at VM creation and cannot be changed after.
# rosetta needs vm-type=vz; it makes linux/amd64 images run via Apple's
# translator instead of the much slower QEMU binfmt path.
COLIMA_CPU="${COLIMA_CPU:-6}"
COLIMA_MEMORY="${COLIMA_MEMORY:-8}"
COLIMA_VM_TYPE="${COLIMA_VM_TYPE:-vz}"
COLIMA_MOUNT_TYPE="${COLIMA_MOUNT_TYPE:-virtiofs}"
COLIMA_ROSETTA="${COLIMA_ROSETTA:-true}"

# NOTE: --disk is deliberately not set here. Colima's data disk is grow-only,
# and the value in colima.yaml does NOT reflect the real provisioned size once
# the underlying Lima disk has been grown. Setting it on an existing VM is a
# no-op at best and misleading at worst. Size it explicitly at creation time.

# Set COLIMA_RECONCILE=1 to allow this script to restart a running VM to apply
# drifted CPU/memory. Off by default: a restart stops every running container.
COLIMA_RECONCILE="${COLIMA_RECONCILE:-0}"

check_colima() {
    if ! command -v colima &> /dev/null; then
        log_error "Colima is not installed. Please install it first with: brew install colima"
        exit 1
    fi
}

# Echo "<cpus> <memory_gib>" for the default profile, or nothing if not running.
colima_actual() {
    local json
    json=$(colima list --json 2>/dev/null | grep '"name":"default"' || true)
    [[ -z "$json" ]] && return 0

    local cpus mem_bytes
    cpus=$(printf '%s' "$json" | sed -n 's/.*"cpus":\([0-9]*\).*/\1/p')
    mem_bytes=$(printf '%s' "$json" | sed -n 's/.*"memory":\([0-9]*\).*/\1/p')
    [[ -z "$cpus" || -z "$mem_bytes" ]] && return 0

    print -- "$cpus $(( mem_bytes / 1073741824 ))"
}

start_colima() {
    log_info "Starting Colima (cpu=$COLIMA_CPU memory=${COLIMA_MEMORY}G vm=$COLIMA_VM_TYPE mount=$COLIMA_MOUNT_TYPE rosetta=$COLIMA_ROSETTA)..."

    local -a args
    args=(
        --cpu "$COLIMA_CPU"
        --memory "$COLIMA_MEMORY"
        --vm-type="$COLIMA_VM_TYPE"
        --mount-type="$COLIMA_MOUNT_TYPE"
    )
    [[ "$COLIMA_ROSETTA" == true ]] && args+=(--vz-rosetta)

    colima start "${args[@]}"

    if docker info &> /dev/null; then
        log_success "Colima and Docker setup complete"
    else
        log_error "Docker is not responding. Colima setup may have failed."
        return 1
    fi
}

setup_colima() {
    log_info "Setting up Colima..."

    if ! colima status &> /dev/null; then
        start_colima
        return $?
    fi

    # Already running — reconcile rather than skip silently.
    local actual cpus mem
    actual=$(colima_actual)
    if [[ -z "$actual" ]]; then
        log_warning "Colima is running but its state could not be read; leaving it alone"
        return 0
    fi
    cpus=${actual%% *}
    mem=${actual##* }

    local drift=""
    if [[ "$cpus" != "$COLIMA_CPU" ]]; then
        drift="cpu: $cpus -> $COLIMA_CPU"
    fi
    if [[ "$mem" != "$COLIMA_MEMORY" ]]; then
        [[ -n "$drift" ]] && drift="$drift, "
        drift="${drift}memory: ${mem}G -> ${COLIMA_MEMORY}G"
    fi

    if [[ -z "$drift" ]]; then
        log_success "Colima is running with the desired settings (cpu=$cpus memory=${mem}G)"
        return 0
    fi

    log_warning "Colima is running with drifted settings: $drift"
    if [[ "$COLIMA_RECONCILE" == 1 ]]; then
        log_info "COLIMA_RECONCILE=1 — restarting to apply"
        colima stop
        start_colima
    else
        log_warning "Not restarting automatically (it would stop running containers)."
        log_warning "To apply: colima stop && colima start --cpu $COLIMA_CPU --memory $COLIMA_MEMORY"
        log_warning "Or re-run with: COLIMA_RECONCILE=1 ./install.sh"
    fi
}

configure_docker_context() {
    log_info "Configuring Docker context..."

    # NOTE: do not pipe `docker context list` into `grep -q` here. Under
    # `set -o pipefail`, grep -q exits on first match, docker takes SIGPIPE, and
    # the pipeline reports failure even though the context exists.
    if docker context inspect colima &> /dev/null; then
        docker context use colima &> /dev/null
        log_success "Docker context set to Colima"
    else
        log_warning "Colima Docker context not found"
    fi
}

display_usage() {
    echo ""
    log_info "Colima Usage:"
    echo "  colima start          - Start Colima VM"
    echo "  colima stop           - Stop Colima VM"
    echo "  colima restart        - Restart Colima VM"
    echo "  colima status         - Check Colima status"
    echo "  colima ssh            - SSH into Colima VM"
    echo "  colima list --json    - Machine-readable VM state"
    echo ""
    log_info "Reclaiming disk space (order matters):"
    echo "  docker-reclaim        - prune caches, then TRIM so the host gets the space back"
    echo ""
    log_info "Docker is now available via Colima!"
    echo "  docker run hello-world"
    echo "  docker compose up -d"
}

main() {
    log_info "Setting up Colima for container development..."

    check_colima
    setup_colima
    configure_docker_context
    display_usage

    log_success "Colima setup complete!"
}

main "$@"
