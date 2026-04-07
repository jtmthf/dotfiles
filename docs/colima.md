# Colima (Docker) Setup

Colima is a lightweight container runtime for macOS that provides Docker (and containerd) without requiring Docker Desktop. It is free, open-source, and runs containers inside a Linux VM managed by Apple's Virtualization framework.

This repo uses Colima as the default Docker backend on macOS.

## Why Colima over Docker Desktop

- No license cost -- Docker Desktop requires a paid subscription for larger organizations.
- Lower resource footprint -- Colima uses Apple's native Virtualization framework (`vz`) instead of QEMU, resulting in faster startup and lower overhead.
- CLI-first workflow -- no desktop app or menu bar icon required.
- Installed and managed entirely through Homebrew (`brew install colima`).

## VM Configuration

The setup script (`scripts/setup-colima.zsh`) starts Colima with these settings:

| Setting    | Value      | Notes                                              |
|------------|------------|----------------------------------------------------|
| CPUs       | 4          | Adjust with `--cpu` if your machine has fewer cores |
| Memory     | 8 GB       | Adjust with `--memory` for heavier workloads        |
| Disk       | 60 GB      | Thin-provisioned; grows on demand up to this limit  |
| VM type    | `vz`       | Apple Virtualization framework (faster than QEMU)   |
| Mount type | `virtiofs` | Fast host-to-VM file sharing via virtio-fs          |

These defaults are applied only on first start. To change them later, stop Colima and start it again with new flags, or edit `~/.colima/default/colima.yaml` directly.

## How the Setup Script Works

The script runs automatically during `./install.sh` on macOS (gated behind an `$OS == "macos"` check). It performs these steps:

1. Verifies that `colima` is installed (exits with an error if not).
2. Checks if Colima is already running -- skips startup if so.
3. Starts Colima with the optimized settings listed above.
4. Waits 5 seconds for the VM to initialize.
5. Verifies that `docker info` responds successfully.
6. Sets the `colima` Docker context as the default so all `docker` commands route through it.

## Managing Colima

```bash
colima start            # Start the VM (uses settings from last start)
colima stop             # Gracefully stop the VM
colima restart          # Stop then start
colima status           # Show running state, CPU, memory, disk usage
colima ssh              # SSH into the Linux VM
```

To start with custom resources (overriding the defaults):

```bash
colima start --cpu 2 --memory 4 --disk 30
```

The Colima configuration file lives at `~/.colima/default/colima.yaml`. Edits there persist across restarts.

## Docker Aliases

Defined in `zsh/aliases.zsh`. These are always available (they do not gate on `command -v` since Docker is expected to be present when Colima is running).

| Alias   | Expands to          | Description                    |
|---------|---------------------|--------------------------------|
| `d`     | `docker`            | Short Docker invocation        |
| `dc`    | `docker-compose`    | Short Compose invocation       |
| `dps`   | `docker ps`         | List running containers        |
| `dpsa`  | `docker ps -a`      | List all containers            |
| `di`    | `docker images`     | List images                    |
| `drmi`  | `docker rmi`        | Remove image(s)                |
| `drm`   | `docker rm`         | Remove container(s)            |
| `dexec` | `docker exec -it`   | Interactive exec into container|
| `dlogs` | `docker logs`       | Tail container logs            |
| `dstop` | `docker stop`       | Stop container(s)              |
| `dstart`| `docker start`      | Start container(s)             |
| `ld`    | `lazydocker`        | TUI for Docker (gated on install) |

## Docker Helper Functions

Defined in `zsh/functions.zsh`.

### `docker-cleanup`

Aggressively prunes everything -- stopped containers, unused images, build cache, and volumes:

```bash
docker-cleanup
# runs: docker system prune -af --volumes && docker image prune -af
```

### `docker-stop-all`

Stops every running container:

```bash
docker-stop-all
# runs: docker stop $(docker ps -aq)
```

### `docker-rm-all`

Removes every container (running or stopped):

```bash
docker-rm-all
# runs: docker rm $(docker ps -aq)
```

## Troubleshooting

### Docker commands fail with "Cannot connect to the Docker daemon"

Colima is probably not running. Start it:

```bash
colima start
```

If it was running but Docker still cannot connect, verify the context:

```bash
docker context ls
docker context use colima
```

### Colima fails to start

Check the VM log for errors:

```bash
colima start --very-verbose
```

If a previous VM is stuck, delete and recreate it:

```bash
colima delete
colima start --cpu 4 --memory 8 --disk 60 --vm-type=vz --mount-type=virtiofs
```

### Slow file mounts or I/O

The setup script already uses `virtiofs`, which is the fastest mount type available with the `vz` VM type. If you still experience slow I/O, consider narrowing the mounted paths by editing `~/.colima/default/colima.yaml` and specifying explicit `mounts:` entries instead of mounting the entire home directory.

### Reclaiming disk space

Docker images and build cache accumulate over time. Run:

```bash
docker-cleanup
```

Or reclaim the VM disk itself:

```bash
colima stop
# The QCOW2/raw image shrinks on next start after a prune
colima start
```

### Port conflicts

If a container port conflicts with a host service, identify the conflict:

```bash
port-check 8080    # shell function from functions.zsh
port-kill 8080     # kill the process on that port
```

## Related Files

- `scripts/setup-colima.zsh` -- setup script with VM configuration
- `zsh/aliases.zsh` -- Docker aliases
- `zsh/functions.zsh` -- Docker helper functions (`docker-cleanup`, `docker-stop-all`, `docker-rm-all`)
- `Brewfile` -- installs `colima` via Homebrew
- `install.sh` -- calls `setup_colima` on macOS
