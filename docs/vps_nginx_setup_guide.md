# VPS Setup Guide (Local Database & Automated Configs)

This guide details the step-by-step instructions to prepare a clean Ubuntu VPS server for hosting the **Invincibles** Phoenix application, including installing a local PostgreSQL database.

Since Systemd and Nginx configurations are committed to the repository and deployed automatically via GitHub Actions, your server setup tasks are minimized.

---

## 1. Install and Configure Local PostgreSQL

Log in as `root` via SSH to your VPS, and install PostgreSQL:

```bash
apt update
apt install -y postgresql postgresql-contrib
```

Start and enable the PostgreSQL service:

```bash
systemctl start postgresql
systemctl enable postgresql
```

### Create the Database and User
Switch to the default `postgres` system user and open the PostgreSQL console:

```bash
sudo -i -u postgres psql
```

Inside the PostgreSQL shell, run the following SQL statements to configure your database:

```sql
-- 1. Create a dedicated database user
CREATE USER invincibles_user WITH PASSWORD 'choose_a_secure_password';

-- 2. Create the production database
CREATE DATABASE invincibles_prod OWNER invincibles_user;

-- 3. Grant privileges to the user
GRANT ALL PRIVILEGES ON DATABASE invincibles_prod TO invincibles_user;

-- 4. Connect to the new database to grant schema permissions (Required for PostgreSQL 15+)
\c invincibles_prod
GRANT ALL ON SCHEMA public TO invincibles_user;

-- 5. Exit the console
\q
```

Your database is now ready on port `5432`. The connection string (`DATABASE_URL`) to use in your GitHub Actions secret will be:
`ecto://invincibles_user:choose_a_secure_password@127.0.0.1:5432/invincibles_prod`

---

## 2. Install Nginx and Let's Encrypt Certbot

Run the following command to install the web server and SSL utilities:

```bash
apt install -y nginx certbot python3-certbot-nginx
```

---

## 3. Prepare the Application Directory

Create the target directory where the GitHub Actions workflow will extract the release tarball:

```bash
mkdir -p /var/www/invincibles
```

---

## 4. GitHub Repository Secrets Configuration

In your GitHub repository, navigate to **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**, and add the following keys:

- `VPS_HOST`: The IP address of your VPS.
- `VPS_USER`: `root`
- `VPS_SSH_KEY`: The private SSH key used to access your VPS. Make sure the corresponding public key is added to `/root/.ssh/authorized_keys` on the server.
- `PHX_HOST`: `invincibles.website`
- `DATABASE_URL`: The local database connection string:
  `ecto://invincibles_user:choose_a_secure_password@127.0.0.1:5432/invincibles_prod`
- `SECRET_KEY_BASE`: Run `mix phx.gen.secret` locally in your shell and paste the output.

---

## 5. Deploy the Code

Now, push your changes to the `main` branch. This will trigger the GitHub Actions workflow to build the release, transfer it to the server, extract it, and automatically apply the Systemd and Nginx configuration files.

---

## 6. Enable SSL/TLS with Let's Encrypt (Run Once)

After the first deployment successfully completes and Nginx restarts, run Certbot to automatically configure Let's Encrypt certificates:

```bash
certbot --nginx -d invincibles.website -d www.invincibles.website
```

Certbot will automatically alter the Nginx configuration to support HTTPS on port 443 and redirect all port 80 HTTP traffic to HTTPS.

---

## 7. Logs and Debugging

To view application logs on the VPS:

```bash
# Follow live logs
journalctl -u invincibles.service -f

# View recent logs
journalctl -u invincibles.service -n 100
```
