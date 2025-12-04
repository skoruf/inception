# Quick Start Guide - Inception Project

## Prerequisites Checklist

- [ ] Virtual Machine with Docker and Docker Compose installed
- [ ] Your 42 login: `cthaler`
- [ ] Volume directories created (see below)

## Step 1: Create Volume Directories

```bash
sudo mkdir -p /home/cthaler/data/mariadb
sudo mkdir -p /home/cthaler/data/wordpress
sudo chown -R $USER:$USER /home/cthaler/data
```

## Step 2: Create `.env` File

Docker Compose now loads environment variables from `/home/cthaler/.env` (so it also works outside the repo). Create the file on your VM:

```bash
sudo mkdir -p /home/cthaler
cat << 'EOF' | sudo tee /home/cthaler/.env > /dev/null
DOMAIN_NAME=cthaler.42.fr
SQL_DB=wordpress_db
SQL_USER=wordpress_user
SQL_PW=YourSecurePassword123!
SQL_ROOT_PW=YourRootPassword123!
EOF
sudo chmod 600 /home/cthaler/.env
```

**⚠️ IMPORTANT:** Never commit `.env` to git! It contains passwords.

## Step 3: Configure Domain Resolution

Add to `/etc/hosts`:

```bash
echo "127.0.0.1 cthaler.42.fr" | sudo tee -a /etc/hosts
```

## Step 4: Build and Start

```bash
cd /Users/marianfurnica/Desktop/inception/inception
make build
```

## Step 5: Verify

1. **Check containers:**
   ```bash
   docker ps
   ```
   Should show: `nginx`, `wordpress`, `mariadb`

2. **Check logs:**
   ```bash
   docker logs mariadb
   docker logs wordpress
   docker logs nginx
   ```

3. **Access WordPress:**
   - Open browser: `https://cthaler.42.fr`
   - Accept SSL warning (self-signed certificate)
   - Complete WordPress installation

## Troubleshooting

**502 Bad Gateway:**
- Check `docker ps` - all containers running?
- Check `docker logs wordpress` - php-fpm started?

**Database connection error:**
- Verify `.env` file exists and has correct values
- Check `docker logs mariadb` for errors

**SSL certificate error:**
- Verify `/etc/hosts` has `127.0.0.1 cthaler.42.fr`
- Certificate CN matches domain

## Commands Reference

```bash
# Build and start
make build

# Stop containers
make down

# Stop and remove volumes
make clean

# Restart everything
make restart
```

For detailed explanations of all fixes, see `FIXES_EXPLAINED.md`.

