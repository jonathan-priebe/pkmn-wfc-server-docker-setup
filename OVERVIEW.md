# 📋 Summary: MariaDB Separation - All Files

## 🎯 Main Changes

### What was changed compared to [u1f992/pkmn-wfc-server](https://github.com/u1f992/pkmn-wfc-server)?
1. **MariaDB** now runs in a separate container
2. **All configurations** are centralized in the `.env` file
3. **Automatic initialization** of databases on first start
4. **Health checks** ensure MariaDB is ready before other services start
5. **Persistent data** through Docker volumes

## 📁 All Files Overview

### Root Directory: `/pkmn-wfc-server/`

#### 1. `.env`
```
Path: ./env
Content: All environment variables (passwords, container names, etc.)
```

#### 2. `docker-compose.yml`
```
Path: ./docker-compose.yml
Most Important Changes:
- New mariadb service
- Health check for MariaDB
- depends_on with condition: service_healthy
- Shared network: pkmn-network
- Volume for persistent data
```

### Pokemon Server: `/pkmn-wfc-server/pkmn-server/`

#### 5. `pkmn-server/Dockerfile`
```
Path: ./pkmn-server/Dockerfile
Most Important Changes:
- MariaDB is NO longer installed
- Uses mysql-client instead of mariadb-server
- All localhost/gts replaced with ${MARIADB_HOST}
- Entrypoint waits for MariaDB
- Database commands use remote host
```

#### 6. `pkmn-server/build/bkup/openssl/openssl-1.1.1m.tar.gz`
```
Path: ./pkmn-server/build/bkup/openssl/openssl-1.1.1m.tar.gz
Status: Unchanged (must be present)
```

### DNS: `/pkmn-wfc-server/dnsmasq/`

#### 7. `dnsmasq/wfc.conf`
```
Path: ./dnsmasq/wfc.conf
Status: Unchanged (already created by you)
```

## 🔑 Important Configuration Points

### Changed in Dockerfile (Build Stage):

```dockerfile
# BEFORE:
find ./ -name *.config | xargs -n 1 sed -i -e 's/connectionString="Server=gts;/connectionString="Server=localhost;/g'

# AFTER:
find ./ -name *.config | xargs -n 1 sed -i -e "s/connectionString=\"Server=gts;/connectionString=\"Server=${MARIADB_HOST};/g"
find ./ -name *.config | xargs -n 1 sed -i -e "s/connectionString=\"Server=localhost;/connectionString=\"Server=${MARIADB_HOST};/g"
```

### Changed in Dockerfile (Runtime):

```dockerfile
# BEFORE:
service mariadb start
mysql --user=root ...

# AFTER:
mysql -h${MARIADB_HOST} -uroot -p${MARIADB_ROOT_PASSWORD} ...
```

### Entrypoint Script:

```bash
# Newly added: Wait for MariaDB
until mysql -h${MARIADB_HOST} -uroot -p${MARIADB_ROOT_PASSWORD} -e 'SELECT 1' >/dev/null 2>&1; do
    echo 'MariaDB is unavailable - sleeping'
    sleep 2
done
```

## 🚀 Quick Start Checklist

- [ ] Create all directories: `mkdir -p pkmn-wfc-server/{dnsmasq,mariadb/{conf.d,init},pkmn-server}`
- [ ] Create and customize `.env` file
- [ ] Place `docker-compose.yml` in root directory
- [ ] Copy `Dockerfile` to `pkmn-server/`
- [ ] Copy `openssl-1.1.1m.tar.gz` to `pkmn-server/`
- [ ] Create `wfc.conf` in `dnsmasq/` (if not already present)
- [ ] Run `docker-compose up -d`

## 🔍 Connection Schema

```
┌─────────────┐
│   dnsmasq   │ (DNS Resolution)
└─────────────┘
       │
       │ Port 53/UDP
       ▼
┌─────────────────────────────────────┐
│          pkmn-server                │
│  ┌─────────────────────────────┐   │
│  │  Apache + Mono (GTS/CoWFC)  │   │
│  │  Python (DWC Server)        │   │
│  └─────────────────────────────┘   │
│              │                      │
│              │ mysql-client         │
│              ▼                      │
│     MariaDB Connection              │
│     Host: mariadb-pkmn             │
└─────────────────────────────────────┘
                │
                │ TCP Connection
                │ (pkmn-network)
                ▼
       ┌─────────────────┐
       │  mariadb-pkmn   │
       │  ┌───────────┐  │
       │  │  cowfc DB │  │
       │  │  gts DB   │  │
       │  └───────────┘  │
       │   Port 3306     │
       └─────────────────┘
```

## 📊 Database Connections in Detail

### CoWFC Web Config:
```ini
# In: /var/www/config.ini
db_host = mariadb-pkmn  # (from ${MARIADB_HOST})
db_user = cowfc
db_pass = cowfc
db_name = cowfc
```

### GTS Connection String:
```xml
<!-- In: pkmn-classic-framework *.config files -->
<connectionString>
  Server=mariadb-pkmn;  <!-- Replaced: localhost/gts -->
  Database=gts;
  User ID=gts;
  Password=gts;
</connectionString>
```

## ⚙️ Environment Variables Usage

### Build Time (ARG):
- Used during `docker build`
- For static configuration in the image

### Runtime (ENV):
- Used during `docker run`
- For dynamic database connections

```dockerfile
# Build Time
ARG MARIADB_HOST
# Replaces values in configuration files

# Runtime
ENV MARIADB_HOST=${MARIADB_HOST}
# Used in entrypoint scripts and at runtime
```

## 🐛 Debugging Commands

```bash
# MariaDB Logs
docker-compose logs -f mariadb

# Pokemon Server Logs
docker-compose logs -f pkmn-server

# Inside MariaDB Container
docker exec -it mariadb-pkmn mysql -uroot -p

# Test CoWFC DB
docker exec -it mariadb-pkmn mysql -ucowfc -pcowfc cowfc -e "SHOW TABLES;"

# Test GTS DB
docker exec -it mariadb-pkmn mysql -ugts -pgts gts -e "SHOW TABLES;"

# Network Check
docker network inspect pkmn-network

# Connection Test from pkmn-server
docker exec -it pkmn-server mysql -h mariadb-pkmn -uroot -p[PASSWORD] -e "SELECT 1;"
```

## 📝 Important Notes

1. **First start takes longer**: The GTS setup with Wine can take 5-10 minutes
2. **Change passwords**: Change ALL passwords in `.env` before first start
3. **Port conflicts**: Ensure port 3306 is not already in use
4. **Backup**: The database is stored in volume `pkmn-mariadb-data`
5. **Clean install**: `docker-compose down -v` deletes ALL data!

## ✅ Success Indicators

After running `docker-compose up -d` you should see:

```bash
# Containers running
docker-compose ps
# All should be "Up" and "healthy"

# Check logs
docker-compose logs pkmn-server | grep "Starting DWC"
# Should show "Starting DWC Network Server..."

# Databases exist
docker exec -it mariadb-pkmn mysql -uroot -p[PASSWORD] -e "SHOW DATABASES;"
# Should list 'cowfc' and 'gts'
```

## 🎉 Done!

Your Pokemon WiFi Server is now running with separate MariaDB!

Admin Panel: http://[YOUR-IP]/?page=admin&section=Dashboard