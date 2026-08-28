# Deployment to Nginx and Ubuntu via GitHub Actions (Bare-Metal) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure and deploy the Phoenix application to an Ubuntu VPS behind an Nginx reverse proxy using compiled releases, systemd, and GitHub Actions (without Docker).

**Architecture:**
- GitHub Actions compiles assets and compiles the Elixir OTP release, compressing the output into a tarball.
- Systemd and Nginx configuration templates are stored in the `deployment/` directory.
- The workflow copies the tarball, systemd service, and nginx config to the VPS via SCP.
- The workflow SSHs into the VPS as `root`, extracts the release, moves configurations to system paths (`/etc/systemd/system/` and `/etc/nginx/sites-available/`), symlinks Nginx, updates `.env`, runs migrations, and reloads Nginx/Systemd automatically.

**Tech Stack:** Elixir, Phoenix, Nginx, Ubuntu VPS, systemd, GitHub Actions.

---

### Task 1: Create Release Migration Helper

Since Phoenix releases run without `mix`, we need an Elixir module to execute Ecto migrations.

**Files:**
- Create: `lib/invincibles/release.ex`

- [ ] **Step 1: Write the Release module**
  Create `lib/invincibles/release.ex` with the following content:
  ```elixir
  defmodule Invincibles.Release do
    @app :invincibles

    def migrate do
      load_app()

      for repo <- repos() do
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      end
    end

    def rollback(repo, version) do
      load_app()

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    end

    defp repos do
      Application.fetch_env!(@app, :ecto_repos)
    end

    defp load_app do
      Application.load(@app)
    end
  end
  ```

- [ ] **Step 2: Run mix compile to verify syntax**
  Run: `mix compile`
  Expected: Compile compiles successfully with no errors or warnings for the new file.

---

### Task 2: Create Deployment Configuration Templates

We will store Nginx and Systemd templates in the codebase so they can be copied to the server automatically.

**Files:**
- Create: `deployment/invincibles.service`
- Create: `deployment/nginx.conf`

- [ ] **Step 3: Create systemd unit file**
  Create `deployment/invincibles.service`:
  ```ini
  [Unit]
  Description=Invincibles Phoenix Application
  After=network.target

  [Service]
  Type=simple
  User=root
  Group=root
  WorkingDirectory=/var/www/invincibles
  EnvironmentFile=/var/www/invincibles/.env
  ExecStart=/var/www/invincibles/bin/invincibles start
  ExecStop=/var/www/invincibles/bin/invincibles stop
  Restart=on-failure
  RestartSec=5
  SyslogIdentifier=invincibles

  [Install]
  WantedBy=multi-user.target
  ```

- [ ] **Step 4: Create nginx site configuration**
  Create `deployment/nginx.conf`:
  ```nginx
  map $http_upgrade $connection_upgrade {
      default upgrade;
      ''      close;
  }

  server {
      server_name invincibles.website www.invincibles.website;

      location / {
          proxy_pass http://127.0.0.1:4000;
          proxy_http_version 1.1;

          # WebSocket support
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;

          # Headers forwarding client info
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Port $server_port;

          # Timeouts for persistent LiveView sockets
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
      }

      listen 80;
  }
  ```

---

### Task 3: Create GitHub Actions Workflow

Define the CI/CD pipeline to build the release, SCP it along with configurations, and execute installation steps.

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 5: Write the deploy.yml workflow**
  Create `.github/workflows/deploy.yml` with the following configuration:
  ```yaml
  name: Deploy Application

  on:
    push:
      branches: [ "main" ]

  jobs:
    build-and-deploy:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4

        - name: Set up Elixir & Erlang
          uses: erlef/setup-beam@v1
          with:
            elixir-version: '1.15.7' # Matches project Elixir version
            otp-version: '26.1.2'

        - name: Restore dependencies cache
          uses: actions/cache@v4
          with:
            path: deps
            key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
            restore-keys: ${{ runner.os }}-mix-

        - name: Install dependencies
          run: mix deps.get --only prod

        - name: Compile Application
          run: MIX_ENV=prod mix compile

        - name: Build assets
          run: MIX_ENV=prod mix assets.deploy

        - name: Build Release
          run: MIX_ENV=prod mix release

        - name: Create Tarball
          run: tar -czf release.tar.gz -C _build/prod/rel/invincibles .

        - name: Copy Release and Configs to VPS
          uses: appleboy/scp-action@v0.1.7
          with:
            host: ${{ secrets.VPS_HOST }}
            username: ${{ secrets.VPS_USER }}
            key: ${{ secrets.VPS_SSH_KEY }}
            source: "release.tar.gz,deployment/invincibles.service,deployment/nginx.conf"
            target: "/tmp/"

        - name: Extract & Restart via SSH
          uses: appleboy/ssh-action@v1.0.3
          with:
            host: ${{ secrets.VPS_HOST }}
            username: ${{ secrets.VPS_USER }}
            key: ${{ secrets.VPS_SSH_KEY }}
            script: |
              # Ensure target directories exist
              mkdir -p /var/www/invincibles
              
              # Extract application
              tar -xzf /tmp/release.tar.gz -C /var/www/invincibles
              rm /tmp/release.tar.gz
              
              # Setup environment variables file
              echo "PORT=4000" > /var/www/invincibles/.env
              echo "PHX_SERVER=true" >> /var/www/invincibles/.env
              echo "PHX_HOST=${{ secrets.PHX_HOST }}" >> /var/www/invincibles/.env
              echo "DATABASE_URL=${{ secrets.DATABASE_URL }}" >> /var/www/invincibles/.env
              echo "SECRET_KEY_BASE=${{ secrets.SECRET_KEY_BASE }}" >> /var/www/invincibles/.env
              
              # Run Migrations
              /var/www/invincibles/bin/invincibles eval "Invincibles.Release.migrate"
              
              # Copy configuration files to their system paths
              cp /tmp/deployment/invincibles.service /etc/systemd/system/invincibles.service
              cp /tmp/deployment/nginx.conf /etc/nginx/sites-available/invincibles
              rm -rf /tmp/deployment
              
              # Symlink Nginx configuration if not already present
              if [ ! -f /etc/nginx/sites-enabled/invincibles ]; then
                ln -s /etc/nginx/sites-available/invincibles /etc/nginx/sites-enabled/invincibles
              fi
              
              # Reload Systemd & Restart service
              systemctl daemon-reload
              systemctl enable invincibles
              systemctl restart invincibles
              
              # Test and restart Nginx
              nginx -t && systemctl reload nginx
  ```

---

### Task 4: Server Setup and Nginx Configuration Documentation

**Files:**
- Create: `docs/vps_nginx_setup_guide.md`

- [ ] **Step 6: Write VPS setup guide**
  Create `docs/vps_nginx_setup_guide.md` with:
  - Docker removal / basic package install steps
  - Web site SSL certificate configuration steps
  - Log verification instructions

---

### Task 5: Pre-Commit & Verification

**Files:**
- None (Command line verification)

- [ ] **Step 7: Run mix precommit alias**
  Run: `mix precommit`
  Expected: PASS
