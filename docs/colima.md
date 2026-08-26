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

| Setting    | Value      | Changeable later? | Notes                                          |
|------------|------------|-------------------|------------------------------------------------|
| CPUs       | 6          | yes, on restart   | Of 12 host cores; leaves headroom for macOS     |
| Memory     | 8 GB       | yes, on restart   | `vz` treats this as a ceiling the VM grows into and does not hand back |
| VM type    | `vz`       | **no**            | Fixed at creation. Apple Virtualization framework |
| Mount type | `virtiofs` | **no**            | Fixed at creation. Fastest option under `vz`    |
| Rosetta    | `true`     | yes, on restart   | Runs `linux/amd64` images via Apple's translator instead of the far slower QEMU binfmt path |
| Mounts     | *(default)*| yes, on restart   | Whole `$HOME`, writable. See "Why mounts are not narrowed" |

The desired values live at the top of `scripts/setup-colima.zsh`. The script
reconciles against them on every run.

### Disk sizing is a special case

Colima gives the VM **two** disks, and they are easy to confuse:

| Disk | Config key | Mounted at | Holds |
|------|-----------|------------|-------|
| root | `rootDisk` (default 20 GiB) | `/` | OS only |
| data | `disk` (default 100 GiB) | `/mnt/lima-colima` | `/var/lib/docker` — images, volumes, build cache |

Everything that grows lives on the **data** disk, so `df -h /` inside the VM
tells you nothing useful. Use `lsblk` or `df -h /mnt/lima-colima`.

Two traps:

1. **The data disk is grow-only.** `disk:` is a ceiling, not an allocation.
   Lowering it does not shrink anything and cannot be applied to an existing VM.
2. **`colima.yaml` and `colima list` can both lie about it.** The underlying
   Lima disk lives at `~/.colima/_lima/_disks/colima/datadisk` and survives
   `colima delete`, so once it has been grown, the config value no longer
   matches reality. Trust `lsblk` in the VM and `du -h` on that file.

Because of this, `setup-colima.zsh` deliberately does **not** pass `--disk`.
Size it explicitly when creating a VM.

### Running `linux/amd64` images (Rosetta)

On Apple Silicon, foreign-architecture images run one of two ways:

- `binfmt` (Colima's default) -- QEMU user-mode emulation. Works, slow.
- `rosetta: true` -- Apple's own translator. Much faster, requires `vmType: vz`.
  Makes `binfmt` a no-op.

Enabled here because amd64 images are pulled regularly. Verify it is live:

```bash
colima ssh -- ls /proc/sys/fs/binfmt_misc/rosetta   # exists when active
```

Toggling it needs only a restart, not a VM recreate.

### Why mounts are not narrowed

Colima mounts all of `$HOME` into the VM as writable by default. Narrowing it to
`~/Projects` looks like an easy hardening win, but it buys very little here:

- **No performance gain.** virtiofs does no upfront scan; cost is per-access, not
  proportional to tree size. A 400 GB mount idles the same as a 4 GB one.
- **It misses the biggest hole anyway.** `~/.dotfiles` is a symlink to
  `~/Projects/dotfiles`, and those files are symlinked back into `$HOME` and
  executed by the shell. Any container with write access to `~/Projects` can
  still alter your shell startup.

Narrowing *would* protect `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.claude` (which
contains hooks that execute on the host) and `~/Library/Keychains`. If you ever
run untrusted images, that is the trade to revisit -- but it is partial
mitigation, not a fix. Set it via `mounts:` in `colima.yaml`.

### Config directory location

Colima prefers `$XDG_CONFIG_HOME/colima` but uses the legacy `~/.colima` when it
exists. Whenever `~/.colima` is present it prints this on **every** invocation,
three lines at a time, regardless of whether an XDG directory also exists:

```
level=warning msg="found ~/.colima, ignoring $XDG_CONFIG_HOME..."
level=warning msg="delete ~/.colima to use $XDG_CONFIG_HOME as config directory"
level=warning msg="or run `mv ~/.colima \"$HOME/.config/colima\"`"
```

Deleting a leftover `~/.config/colima` does **not** silence it -- the nag is
driven by `~/.colima` existing. The only fix is to migrate off the legacy path:

```bash
colima stop
mv ~/.colima ~/.config/colima
colima start
```

This is the migration Colima itself suggests, and within `/Users` it is an
instant rename rather than a copy. Verify afterwards, because the Lima instance
stores absolute paths -- notably `_lima/_disks/colima/in_use_by`, which is a
symlink into the old location, and the generated `ssh_config`. Confirm the data
disk still attaches before trusting it:

```bash
colima ssh -- df -h /mnt/lima-colima    # should show your data disk, not just /
```

## How the Setup Script Works

The script runs automatically during `./install.sh` on macOS (gated behind an `$OS == "macos"` check). It performs these steps:

1. Verifies that `colima` is installed (exits with an error if not).
2. If the VM is **not** running, starts it with the settings above.
3. If the VM **is** running, compares its live CPU/memory against the desired
   values and reports any drift. It does not restart on its own, because that
   stops every running container. Pass `COLIMA_RECONCILE=1` to allow a restart.
4. Verifies that `docker info` responds.
5. Sets the `colima` Docker context as the default.

The script previously returned early whenever the VM was already running, which
meant its documented CPU/memory were silently never applied to a VM created by a
bare `colima start`. It now reconciles instead of skipping. Live state is read
from `colima list --json`.

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
colima start --cpu 2 --memory 4
```

`--disk` is omitted deliberately -- see "Disk sizing is a special case" above. It
only takes effect when the data disk is created or grown, so passing it to an
existing VM is misleading.

The Colima configuration file lives at `~/.colima/default/colima.yaml`. Edits there persist across restarts, but note that the `disk:` value there is not authoritative once the disk has been grown.

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

### `docker-reclaim`

The one to reach for. Prunes regenerable caches and then TRIMs the VM disk so
the **host** actually gets the space back. Never touches named volumes.

```bash
docker-reclaim
# runs: docker builder prune -af
#       docker image prune -f
#       colima ssh -- sudo fstrim -v /mnt/lima-colima
```

### `docker-cleanup`

Prunes stopped containers, unused images, networks and build cache. **Does not
touch volumes.**

```bash
docker-cleanup
# runs: docker system prune -af
```

### `docker-cleanup-full`

Adds `--volumes`, which deletes every volume with no container attached. That
includes database volumes whose container was merely removed -- a stopped
Postgres stack looks identical to garbage here. The function lists exactly what
will die and requires you to type `DELETE`.

```bash
docker-cleanup-full
# lists dangling volumes, waits for confirmation, then:
#   docker system prune -af --volumes
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
colima delete   # destroys images, containers AND named volumes -- back up first
colima start --cpu 6 --memory 8 --disk 100 --vm-type=vz --mount-type=virtiofs --vz-rosetta
```

### Slow file mounts or I/O

The setup script already uses `virtiofs`, which is the fastest mount type available with the `vz` VM type. If you still experience slow I/O, consider narrowing the mounted paths by editing `~/.colima/default/colima.yaml` and specifying explicit `mounts:` entries instead of mounting the entire home directory.

### Reclaiming disk space

**Pruning alone does not give space back to the host.** Freeing blocks inside the
VM leaves the host's sparse disk image exactly as large. Restarting Colima does
not shrink it either. The guest filesystem has to be TRIMmed, and the data disk
is mounted without `discard`, so that never happens automatically.

Use the helper, which does both in the right order:

```bash
docker-reclaim
```

Or by hand:

```bash
docker builder prune -af                          # build cache is usually the bulk
colima ssh -- sudo fstrim -v /mnt/lima-colima     # <-- the step that matters
du -h -d0 ~/.colima/_lima/_disks/colima/datadisk  # confirm the image shrank
```

Check what is actually consuming space first:

```bash
docker system df -v                               # per-image/volume/cache breakdown
colima ssh -- df -h /mnt/lima-colima              # the disk that fills up
```

Note that `node_modules`, pnpm/bundle stores and Next.js caches held in named
volumes can easily dwarf your images. Those are regenerable, but
`docker-reclaim` will not remove them -- they are named volumes, and deleting a
named volume is never automatic. Remove idle project stacks by name instead:

```bash
docker volume ls | grep '<stack-name>'
docker volume rm <volume>...
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
- `zsh/functions.zsh` -- Docker helper functions (`docker-reclaim`, `docker-cleanup`, `docker-cleanup-full`, `docker-stop-all`, `docker-rm-all`)
- `Brewfile` -- installs `colima` via Homebrew
- `install.sh` -- calls `setup_colima` on macOS
