# Inception Project - Issues Fixed and Explanations

This document explains all the issues that were found in your Inception project and how they were fixed. Read this carefully to understand what was wrong and why the fixes were necessary.

---

## Table of Contents

1. [Dockerfiles - Non-Interactive Build Issues](#1-dockerfiles---non-interactive-build-issues)
2. [MariaDB Init Script - SQL Syntax Errors](#2-mariadb-init-script---sql-syntax-errors)
3. [WordPress Container - Missing php-fpm Process](#3-wordpress-container---missing-php-fpm-process)
4. [WordPress Configuration - Invalid PHP File](#4-wordpress-configuration---invalid-php-file)
5. [NGINX Configuration - Wrong Root and Missing PHP Forwarding](#5-nginx-configuration---wrong-root-and-missing-php-forwarding)
6. [Environment Variables Setup](#6-environment-variables-setup)
7. [Testing Your Setup](#7-testing-your-setup)

---

## 1. Dockerfiles - Non-Interactive Build Issues

### Problem
All three Dockerfiles (`nginx`, `mariadb`, `wordpress`) were using `apt upgrade` or `apt-get upgrade` **without the `-y` flag**. This causes Docker builds to hang indefinitely because the command waits for interactive user confirmation, which is impossible in a Docker build context.

**Original code:**
```dockerfile
RUN ["apt", "update"]
RUN ["apt", "upgrade"]  # ❌ Missing -y flag
```

### Why This Failed
- Docker builds run in non-interactive mode
- `apt upgrade` without `-y` prompts: "Do you want to continue? [Y/n]"
- Build process hangs waiting for input that never comes
- Your `make build` command would never complete

### Fix Applied
Added `-y` flag to all upgrade commands:

**Fixed code:**
```dockerfile
RUN ["apt", "update"]
RUN ["apt", "upgrade", "-y"]  # ✅ Now non-interactive
```

**Files changed:**
- `srcs/requirements/nginx/Dockerfile`
- `srcs/requirements/mariadb/Dockerfile`
- `srcs/requirements/wordpress/Dockerfile`

### Test
After this fix, `make build` should no longer hang at the upgrade step. The build process will complete successfully (assuming other issues are resolved).

---

## 2. MariaDB Init Script - SQL Syntax Errors

### Problem
The `db_user.sh` script had **critical SQL syntax errors** that would prevent MariaDB from initializing correctly:

**Original code:**
```bash
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ${SQL_ROOT_PW}';"
#                                                      ^ Missing quote    ^ Extra quote
```

### Issues Found

1. **Missing opening quote** before `${SQL_ROOT_PW}`
2. **Extra closing quote** after the variable
3. **Unquoted password variable** - dangerous if password contains special characters
4. **No error handling** - script continues even if commands fail
5. **No wait for MySQL readiness** - script might run before MySQL is ready

### Why This Failed
- SQL syntax error: `IDENTIFIED BY password';` instead of `IDENTIFIED BY 'password';`
- If password contains spaces or special chars, SQL breaks
- Script fails silently, MariaDB container starts but database isn't configured
- WordPress can't connect to database → 500 error

### Fix Applied

**Fixed code:**
```bash
#!/bin/bash
set -e  # Exit on any error

# Start MariaDB service
service mysql start

# Wait for MySQL to be ready
until mysqladmin ping -h localhost --silent; do
    sleep 1
done

# Create database if it doesn't exist
mysql -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DB}\`;"

# Create user and grant privileges (using CREATE USER IF NOT EXISTS for MariaDB compatibility)
mysql -e "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PW}';"
mysql -e "GRANT ALL PRIVILEGES ON \`${SQL_DB}\`.* TO \`${SQL_USER}\`@'%';"

# Set root password (properly quoted)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PW}';"

# Flush privileges
mysql -e "FLUSH PRIVILEGES;"

# Shutdown MariaDB gracefully
mysqladmin -u root -p"${SQL_ROOT_PW}" shutdown

# Start MariaDB in foreground as PID 1 (best practice for Docker)
exec mysqld_safe
```

### Improvements
- ✅ Proper quoting: `'${SQL_ROOT_PW}'` instead of `${SQL_ROOT_PW}'`
- ✅ Error handling: `set -e` stops script on any failure
- ✅ Wait for MySQL: ensures database is ready before running SQL
- ✅ Better user creation: uses `CREATE USER IF NOT EXISTS` for MariaDB compatibility
- ✅ Proper shutdown: gracefully stops MySQL before exec

**File changed:**
- `srcs/requirements/mariadb/tools/db_user.sh`

---

## 3. WordPress Container - Missing php-fpm Process

### Problem
The WordPress Dockerfile installed php-fpm but **never started it**. The container had no process running as PID 1, so it would immediately exit.

**Original code:**
```dockerfile
RUN ["apt-get", "install", "-y", "php-fpm"]
# ... WordPress installation ...
RUN ["chown", "-R", "root:root", "/var/www/wordpress"]
# ❌ No CMD or ENTRYPOINT - container exits immediately
```

### Why This Failed
- Docker containers need a process running as PID 1
- Without `CMD` or `ENTRYPOINT`, container starts and immediately exits
- NGINX tries to forward PHP requests to `wordpress:9000` → connection refused
- You see 502 Bad Gateway errors in browser

### Fix Applied

**Added to Dockerfile:**
```dockerfile
# Ensure runtime directories exist for php-fpm
RUN ["mkdir", "-p", "/run/php"]

# Copy php-fpm pool configuration to listen on 0.0.0.0:9000
COPY ["./conf/www.conf", "/etc/php/7.3/fpm/pool.d/www.conf"]

# Copy WordPress configuration (will use environment variables)
COPY ["./conf/wp-config.php", "/var/www/wordpress/wp-config.php"]

# Set proper permissions for WordPress directory
RUN ["chown", "-R", "www-data:www-data", "/var/www/wordpress"]

# Run php-fpm in the foreground so it becomes PID 1
CMD ["php-fpm7.3", "-F"]
```

**Created new file:** `srcs/requirements/wordpress/conf/www.conf`
```ini
[www]
user = www-data
group = www-data
listen = 0.0.0.0:9000  # Listen on all interfaces, port 9000
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

### Why This Works
- ✅ `php-fpm7.3 -F` runs php-fpm in foreground mode (becomes PID 1)
- ✅ Pool config listens on `0.0.0.0:9000` so NGINX can connect
- ✅ Proper permissions ensure WordPress can write files
- ✅ Container stays alive and processes PHP requests

**Files changed:**
- `srcs/requirements/wordpress/Dockerfile`
- `srcs/requirements/wordpress/conf/www.conf` (new file)

---

## 4. WordPress Configuration - Invalid PHP File

### Problem
The `wp-config.php` file contained **invalid PHP code** mixed with php-fpm configuration directives:

**Original code:**
```php
// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
clear_env = no;           // ❌ This is php-fpm config, not PHP!
listen = wordpress:9000;  // ❌ This is php-fpm config, not PHP!
define( 'DB_NAME', 'database_name_here' );
define( 'DB_USER', 'username_here' );
define( 'DB_PASSWORD', 'password_here' );
define( 'DB_HOST', 'localhost' );  // ❌ Wrong - should be 'mariadb'
```

### Issues Found

1. **Invalid PHP syntax**: `clear_env = no;` and `listen = wordpress:9000;` are php-fpm pool directives, not PHP code
2. **Hardcoded credentials**: Violates subject requirement "Passwords must not be present in your Dockerfiles"
3. **Wrong database host**: `localhost` won't work in Docker - should be service name `mariadb`
4. **Not using environment variables**: Subject requires using env vars

### Why This Failed
- PHP parser throws syntax error on `clear_env = no;`
- WordPress can't load config → white screen or 500 error
- Even if it worked, `localhost` doesn't resolve to MariaDB container
- Hardcoded passwords violate security requirements

### Fix Applied

**Fixed code:**
```php
// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', getenv('SQL_DB') ?: 'wordpress' );

/** Database username */
define( 'DB_USER', getenv('SQL_USER') ?: 'wordpress_user' );

/** Database password */
define( 'DB_PASSWORD', getenv('SQL_PW') ?: '' );

/** Database hostname */
define( 'DB_HOST', 'mariadb' );  // ✅ Service name from docker-compose.yml
```

### Why This Works
- ✅ Removed invalid php-fpm directives (moved to `www.conf`)
- ✅ Uses `getenv()` to read from environment variables
- ✅ `DB_HOST` set to `'mariadb'` (Docker service name)
- ✅ Fallback values provided for safety
- ✅ No hardcoded passwords

**File changed:**
- `srcs/requirements/wordpress/conf/wp-config.php`

---

## 5. NGINX Configuration - Wrong Root and Missing PHP Forwarding

### Problem
NGINX was configured incorrectly - wrong document root and PHP forwarding was commented out:

**Original code:**
```nginx
root /var/www/html;  # ❌ Wrong - WordPress is in /var/www/wordpress

server_name login.42.fr;  # ❌ Should be cthaler.42.fr

location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    # fastcgi_pass wordpress:9000;  # ❌ Commented out - PHP won't work!
}
```

### Issues Found

1. **Wrong document root**: `/var/www/html` but WordPress is mounted at `/var/www/wordpress`
2. **PHP forwarding disabled**: `fastcgi_pass` is commented out
3. **Wrong domain name**: `login.42.fr` instead of `cthaler.42.fr`
4. **Missing FastCGI params**: Need proper `SCRIPT_FILENAME` configuration

### Why This Failed
- NGINX serves files from `/var/www/html` (empty or wrong location)
- PHP files aren't forwarded to php-fpm → PHP code shows as plain text or 404
- Domain mismatch → SSL certificate issues
- WordPress installation page never loads

### Fix Applied

**Fixed code:**
```nginx
root /var/www/wordpress;  # ✅ Correct WordPress location

server_name cthaler.42.fr;  # ✅ Correct domain

location / {
    try_files $uri $uri/ /index.php?$args;  # ✅ WordPress-friendly routing
}

location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass wordpress:9000;  # ✅ Forward PHP to WordPress container
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

### Why This Works
- ✅ Correct root directory matches volume mount
- ✅ PHP requests forwarded to `wordpress:9000` (php-fpm)
- ✅ Proper FastCGI parameters for WordPress
- ✅ WordPress-friendly URL rewriting
- ✅ Domain matches SSL certificate CN

**File changed:**
- `srcs/requirements/nginx/conf/default`

---

## 6. Environment Variables Setup

### Required `.env` File

You **must** create a file `srcs/.env` with the following variables:

```bash
# Domain name (must match your login)
DOMAIN_NAME=cthaler.42.fr

# MariaDB/MySQL Configuration
SQL_DB=wordpress_db
SQL_USER=wordpress_user
SQL_PW=your_secure_password_here
SQL_ROOT_PW=your_root_password_here
```

### Important Notes

1. **Never commit `.env` to git** - it contains passwords!
2. **Use strong passwords** - don't use simple passwords like "password123"
3. **Domain must match**: `DOMAIN_NAME` should be `cthaler.42.fr` (your login)
4. **Variable names**: The script uses `SQL_DB`, `SQL_USER`, `SQL_PW`, `SQL_ROOT_PW`

### How Variables Are Used

- **MariaDB container**: Reads `SQL_DB`, `SQL_USER`, `SQL_PW`, `SQL_ROOT_PW` from `.env`
- **WordPress container**: Reads same variables via `getenv()` in `wp-config.php`
- **NGINX container**: Reads `DOMAIN_NAME` (though currently hardcoded in config)

### Creating the `.env` File

```bash
cd /Users/marianfurnica/Desktop/inception/inception/srcs
cat > .env << EOF
DOMAIN_NAME=cthaler.42.fr
SQL_DB=wordpress_db
SQL_USER=wordpress_user
SQL_PW=ChangeThisPassword123!
SQL_ROOT_PW=ChangeThisRootPassword123!
EOF
chmod 600 .env  # Restrict permissions
```

---

## 7. Testing Your Setup

### Prerequisites

1. **Create volume directories** on your VM:
```bash
sudo mkdir -p /home/cthaler/data/mariadb
sudo mkdir -p /home/cthaler/data/wordpress
sudo chown -R $USER:$USER /home/cthaler/data
```

2. **Create `.env` file** (see section 6 above)

3. **Configure `/etc/hosts`** to point domain to localhost:
```bash
echo "127.0.0.1 cthaler.42.fr" | sudo tee -a /etc/hosts
```

### Build and Start

```bash
cd /Users/marianfurnica/Desktop/inception/inception
make build
```

This will:
1. Build all Docker images
2. Start all containers
3. Initialize MariaDB database
4. Start php-fpm in WordPress container
5. Start NGINX with TLS

### Verify Everything Works

1. **Check containers are running:**
```bash
docker ps
```
You should see `nginx`, `wordpress`, and `mariadb` containers running.

2. **Check container logs:**
```bash
docker logs mariadb    # Should show database initialization
docker logs wordpress  # Should show php-fpm started
docker logs nginx      # Should show NGINX started
```

3. **Access WordPress:**
Open browser: `https://cthaler.42.fr`
- You should see WordPress installation page
- If you see SSL warning, accept it (self-signed certificate)
- Complete WordPress installation

4. **Test database connection:**
```bash
docker exec -it mariadb mysql -u wordpress_user -p
# Enter password from .env
# Should connect successfully
```

### Common Issues

**502 Bad Gateway:**
- Check `wordpress` container is running: `docker ps`
- Check php-fpm logs: `docker logs wordpress`
- Verify `fastcgi_pass wordpress:9000` in NGINX config

**Database connection error:**
- Check `.env` file exists and has correct values
- Check MariaDB logs: `docker logs mariadb`
- Verify `DB_HOST` is `'mariadb'` in `wp-config.php`

**SSL certificate error:**
- Verify domain in `/etc/hosts` matches certificate CN
- Certificate CN is `cthaler.42.fr` (matches your login)

---

## Summary of All Changes

### Files Modified:
1. ✅ `srcs/requirements/nginx/Dockerfile` - Added `-y` to apt upgrade
2. ✅ `srcs/requirements/mariadb/Dockerfile` - Added `-y` to apt upgrade
3. ✅ `srcs/requirements/wordpress/Dockerfile` - Added `-y`, php-fpm config, CMD
4. ✅ `srcs/requirements/mariadb/tools/db_user.sh` - Fixed SQL syntax, added error handling
5. ✅ `srcs/requirements/wordpress/conf/wp-config.php` - Removed invalid directives, uses env vars
6. ✅ `srcs/requirements/nginx/conf/default` - Fixed root path, enabled PHP forwarding

### Files Created:
1. ✅ `srcs/requirements/wordpress/conf/www.conf` - php-fpm pool configuration

### Files You Must Create:
1. ⚠️ `srcs/.env` - Environment variables (see section 6)

---

## Next Steps

1. Create the `.env` file with your passwords
2. Create volume directories on your VM
3. Configure `/etc/hosts` for domain resolution
4. Run `make build` and verify everything works
5. Complete WordPress installation via browser

Good luck with your project! 🚀

