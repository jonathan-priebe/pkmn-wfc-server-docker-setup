# Pokemon WiFi Connection Server (with separate MariaDB)

Docker-based setup for running a Pokémon Wi-Fi Connection (WFC) server to enable online features for Nintendo DS/Wii Pokémon games.

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
    - [Environment Variables Reference](#environment-variables-reference)
- [Architecture Details](#architecture-details)
  - [System Overview](#system-overview)
  - [Data Flow](#data-flow)
- [Usage](#usage)
  - [Admin Panel](#admin-panel)
  - [Nintendo DS Setup](#nintendo-ds-setup)
  - [Supported Games](#supported-games)
    - [Adding Custom Games](#adding-custom-games)
- [Container Management](#container-management)
- [Database Operations](#database-operations)
- [Game Database Management](#game-database-management)
  - [View Allowed Games](#view-allowed-games)
  - [Add New Games](#add-new-games)
  - [Remove Games](#remove-games)
  - [Find Your Game ID](#find-your-game-id)
- [Troubleshooting](#troubleshooting)
- [Network Ports](#network-ports)
- [Security Notes](#security-notes)
- [Credits](#credits)
- [License](#license)

## Architecture

This setup uses a multi-container architecture with separate services for better maintainability and scalability.

### Components

- **dnsmasq**: DNS server for redirecting Nintendo WiFi domains
- **MariaDB**: Separate database container for data persistence
- **pkmn-server**: Main server with Apache, Python GameSpy emulator, and GTS

## Features

✅ **Separate MariaDB container** for better data management  
✅ **Persistent data** survives container restarts  
✅ **Easy configuration** via `.env` file  
✅ **Health checks** ensure proper startup order  
✅ **Host network mode** for better UDP support  
✅ **UTF8MB4 support** for modern character encoding  
✅ **SSLv3 support** for Nintendo DS compatibility  

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- A dedicated server or VPS with public IP
- Open ports (see [Network Ports](#network-ports))

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/jonathan-priebe/pkmn-wfc-server-docker-setup.git
cd pkmn-wfc-server-docker-setup
```

2. **Configure environment**
```bash
# Copy and edit environment file
cp example.env .env
nano .env

# Copy and edit DNS configuration
cp dnsmasq/wfc.example dnsmasq/wfc.conf
nano dnsmasq/wfc.conf
```

3. **Start the containers**
```bash
docker-compose up -d
```

4. **Check logs**
```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f pkmn-server
```

### Configuration

### Environment Variables Reference

The [example environment file](./example.env) file supports the following configuration options:

#### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MARIADB_CONTAINER_NAME` | `mariadb-pkmn` | Name of MariaDB container |
| `MARIADB_HOST` | `mariadb-pkmn` | Hostname for database connections |
| `MARIADB_ROOT_PASSWORD` | `rootpassword123` | Root password for MariaDB |
| `MARIADB_VERSION` | `10.3` | MariaDB version to use |

#### CoWFC Database

| Variable | Default | Description |
|----------|---------|-------------|
| `COWFC_DB_NAME` | `cowfc` | Database name for CoWFC |
| `COWFC_DB_USER` | `cowfc` | Database user for CoWFC |
| `COWFC_DB_PASSWORD` | `cowfc` | Database password for CoWFC |

#### GTS Database

| Variable | Default | Description |
|----------|---------|-------------|
| `GTS_DB_NAME` | `gts` | Database name for GTS |
| `GTS_DB_USER` | `gts` | Database user for GTS |
| `GTS_DB_PASSWORD` | `gts` | Database password for GTS |

#### Admin Credentials

| Variable | Default | Description |
|----------|---------|-------------|
| `ADMIN_USERNAME` | `admin` | Admin panel username |
| `ADMIN_PASSWORD` | `opensesame` | Admin panel password |

#### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `NETWORK_NAME` | `pkmn-network` | Docker network name |

⚠️ **Security Warning**: Change all default passwords before deploying!

Edit `dnsmasq/wfc.conf` to set your server IP:
```bash
# Replace YOUR_SERVER_IP with your actual IP
address=/nintendowifi.net/YOUR_SERVER_IP
# ... etc
```

## Architecture Details

### System Overview
```
┌─────────────────────────────────────────────────────────────┐
│  HOST SYSTEM (Your Server IP)                               │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Container: dnsmasq                                   │   │
│  │  Port: 53 UDP                                         │   │
│  │  → Redirects *.nintendowifi.net to server IP        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Container: mariadb (network: host)                  │   │
│  │  Port: 3306                                           │   │
│  │  Databases:                                           │   │
│  │    ├── cowfc (CoWFC Admin Panel)                     │   │
│  │    └── gts (Pokemon GTS, utf8mb4)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Container: pkmn-server (network: host)              │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────┐    │   │
│  │  │  Apache 2.4.65 + OpenSSL 1.1.1m             │    │   │
│  │  │  Port 80:  HTTP                               │    │   │
│  │  │  Port 443: HTTPS (SSLv3 for Nintendo DS)     │    │   │
│  │  │                                               │    │   │
│  │  │  VirtualHosts:                                │    │   │
│  │  │  ├─ :80 → CoWFC Web (PHP)                    │    │   │
│  │  │  ├─ :80 → gamestats2.gs.nintendowifi.net     │    │   │
│  │  │  │         (GTS - ASP.NET/Mono)              │    │   │
│  │  │  └─ :443 → nas.nintendowifi.net              │    │   │
│  │  │            (Proxy → NAS Server :9000)        │    │   │
│  │  └──────────────────────────────────────────────┘    │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────┐    │   │
│  │  │  Python Master Server (Python 2.7)          │    │   │
│  │  │  /var/www/dwc_network_server_emulator/      │    │   │
│  │  │                                               │    │   │
│  │  │  Services:                                    │    │   │
│  │  │  ├─ NAS Server (Authentication)              │    │   │
│  │  │  ├─ QR Server (Master Server List)           │    │   │
│  │  │  ├─ GP Server (Game Profiles)                │    │   │
│  │  │  └─ NAT Negotiation (P2P Trading)            │    │   │
│  │  │                                               │    │   │
│  │  │  SQLite DB: gpcm.db                          │    │   │
│  │  │  (Sessions, Users, Game Profiles)            │    │   │
│  │  └──────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**Nintendo DS Connection Flow:**
```
┌──────────────────┐
│  Nintendo DS     │
│  DNS: Server IP  │
└────────┬─────────┘
         │
         │ 1. DNS Query: nas.nintendowifi.net?
         ▼
    ┌─────────┐
    │ dnsmasq │ → Returns: Server IP
    └─────────┘
         │
         │ 2. HTTPS Request (SSLv3)
         ▼
  ┌────────────┐
  │ Apache:443 │ (SSLv3, Nintendo Certificate)
  └──────┬─────┘
         │ 3. ProxyPass
         ▼
  ┌──────────────┐
  │ NAS Server   │ Port 9000 (Python)
  │ (Auth/Login) │
  └──────┬───────┘
         │ 4. Create/Verify Session
         ▼
  ┌──────────────┐
  │ gpcm.db      │ (SQLite)
  │ - users      │
  │ - sessions   │
  │ - profiles   │
  └──────────────┘
```

## Usage

### Admin Panel

Access the admin panel at:
```
http://YOUR_SERVER_IP/?page=admin&section=Dashboard
```

Default credentials (change in `.env`):
- **Username**: admin
- **Password**: opensesame

### Nintendo DS Setup

1. **Configure DNS on Nintendo DS/Wii:**
   - Primary DNS: `YOUR_SERVER_IP`
   - Secondary DNS: `8.8.8.8` (optional)

2. **Supported Features:**
   - ✅ Mystery Gifts / Wonder Cards
   - ✅ GTS (Global Trade Station)
   - ✅ Wi-Fi Plaza
   - ✅ Wi-Fi Club (Player vs Player)
   - ⚠️ P2P Trading (may require additional NAT configuration)

### Supported Games

The server comes pre-configured with support for the following Pokémon games:

#### Generation 4 (Nintendo DS)

| Game | Region | Game ID | Status |
|------|--------|---------|--------|
| Pokémon Diamond | ALL | ADA | ✅ Supported |
| Pokémon Diamond | USA | ADAE | ✅ Supported |
| Pokémon Diamond | EUR | ADAP | ✅ Supported |
| Pokémon Diamond | JPN | ADAJ | ✅ Supported |
| Pokémon Pearl | ALL | APA | ✅ Supported |
| Pokémon Pearl | USA | APAE | ✅ Supported |
| Pokémon Pearl | EUR | APAP | ✅ Supported |
| Pokémon Pearl | JPN | APAJ | ✅ Supported |
| Pokémon Platinum | ALL | CPU | ✅ Supported |
| Pokémon Platinum | USA | CPUE | ✅ Supported |
| Pokémon Platinum | EUR | CPUP | ✅ Supported |
| Pokémon Platinum | JPN | CPUJ | ✅ Supported |
| Pokémon HeartGold | ALL | IPK | ✅ Supported |
| Pokémon HeartGold | USA | IPKE | ✅ Supported |
| Pokémon HeartGold | EUR | IPKP | ✅ Supported |
| Pokémon HeartGold | JPN | IPKJ | ✅ Supported |
| Pokémon SoulSilver | ALL | IPG | ✅ Supported |
| Pokémon SoulSilver | USA | IPGE | ✅ Supported |
| Pokémon SoulSilver | EUR | IPGP | ✅ Supported |
| Pokémon SoulSilver | JPN | IPGJ | ✅ Supported |

#### Generation 5 (Nintendo DS)

| Game | Region | Game ID | Status |
|------|--------|---------|--------|
| Pokémon Black | ALL | IRB | ✅ Supported |
| Pokémon Black | USA | IRBO | ✅ Supported |
| Pokémon Black | EUR | IRBP | ✅ Supported |
| Pokémon Black | JPN | IRBJ | ✅ Supported |
| Pokémon White | ALL | IRA | ✅ Supported |
| Pokémon White | USA | IRAO | ✅ Supported |
| Pokémon White | EUR | IRAP | ✅ Supported |
| Pokémon White | JPN | IRAJ | ✅ Supported |
| Pokémon Black 2 | ALL | IRE | ✅ Supported |
| Pokémon Black 2 | USA | IREO | ✅ Supported |
| Pokémon Black 2 | EUR | IREP | ✅ Supported |
| Pokémon Black 2 | JPN | IREJ | ✅ Supported |
| Pokémon White 2 | ALL | IRD | ✅ Supported |
| Pokémon White 2 | USA | IRDO | ✅ Supported |
| Pokémon White 2 | EUR | IRDP | ✅ Supported |
| Pokémon White 2 | JPN | IRDJ | ✅ Supported |

**Note**: All supported games are automatically added to the `allowed_games` table during initialization. You can verify this by checking the SQLite database:
```bash
docker exec pkmn-server sqlite3 /var/www/dwc_network_server_emulator/gpcm.db "SELECT * FROM allowed_games;"
```

#### Adding Custom Games

To add support for additional games, you can manually insert them into the database:
```bash
docker exec pkmn-server sqlite3 /var/www/dwc_network_server_emulator/gpcm.db "
INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('GAME_ID', '01');
"
```

Replace `GAME_ID` with the actual game identifier (e.g., 'ADAE' for Diamond USA).

To grant a wildcard allowance for all regional versions of a game, use only the first three characters of the Game ID.
For example, the entry 'ADA' allows access for all IDs starting with those three characters (e.g., 'ADAE', 'ADAP', 'ADAU', etc.).

## Container Management

### Basic Commands
```bash
# Start all containers
docker-compose up -d

# Stop all containers
docker-compose down

# Restart containers
docker-compose restart

# Rebuild and start
docker-compose up -d --build

# View logs
docker-compose logs -f [container_name]

# Remove everything including volumes
docker-compose down -v
```

### Individual Container Operations
```bash
# Restart Apache
docker exec pkmn-server apachectl restart

# Access container shell
docker exec -it pkmn-server /bin/bash

# Check running processes
docker exec pkmn-server ps aux
```

## Database Operations

### Access Database
```bash
# Connect to MariaDB
docker exec -it mariadb mysql -uroot -p

# List databases
docker exec mariadb mysql -uroot -p -e "SHOW DATABASES;"
```

### Backup and Restore
```bash
# Create backup
docker exec mariadb mysqldump -uroot -p[ROOT_PASSWORD] --all-databases > backup.sql

# Restore from backup
docker exec -i mariadb mysql -uroot -p[ROOT_PASSWORD] < backup.sql

# Backup specific database
docker exec mariadb mysqldump -uroot -p[ROOT_PASSWORD] gts > gts_backup.sql
```

### Database Maintenance
```bash
# Check table character sets
docker exec mariadb mysql -uroot -p[ROOT_PASSWORD] gts -e "
SELECT TABLE_NAME, TABLE_COLLATION 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'gts';"

# Show database variables
docker exec mariadb mysql -uroot -p[ROOT_PASSWORD] -e "
SHOW VARIABLES LIKE 'character_set%';"
```

## Troubleshooting

### Common Issues

#### Issue: pkmn-server won't start

**Solution**: Check if MariaDB is healthy
```bash
docker-compose ps
docker-compose logs mariadb
```

#### Issue: "Can't connect to MySQL server"

**Solutions**:
1. Verify network configuration in `docker-compose.yml`
2. Ensure MariaDB container is running: `docker ps`
3. Check environment variables in `.env`
4. Test connection: `docker exec pkmn-server mysql -h localhost -uroot -p`

#### Issue: Admin login doesn't work

**Solutions**:
1. Verify credentials in `.env`
2. Check users table:
```bash
docker exec mariadb mysql -uroot -p
USE cowfc;
SELECT Username, Rank FROM users;
```
3. Reset admin password if needed

#### Issue: Nintendo DS Error 42003 (Wi-Fi Plaza)

**Possible causes**:
- SSL certificate issue
- Apache not listening on port 443
- Firewall blocking HTTPS

**Debug steps**:
```bash
# Check if Apache is listening on 443
docker exec pkmn-server cat /proc/net/tcp | grep "01BB"

# Check Apache SSL configuration
docker exec pkmn-server apache2ctl -S | grep 443

# View Apache error logs
docker logs pkmn-server | grep -i "ssl\|error"
```

#### Issue: GTS "Connection interrupted"

**Possible causes**:
- Database connection issue
- Character encoding problem
- SSL handshake failure

**Debug steps**:
```bash
# Test GTS endpoint
curl -H "Host: gamestats2.gs.nintendowifi.net" http://YOUR_SERVER_IP:80/

# Check database connection
docker exec pkmn-server mysql -h localhost -ugts -p

# Monitor logs during DS connection
docker logs -f pkmn-server
```

#### Issue: UDP ports not working / NAT problems

**Solution**: The setup uses host network mode which should resolve most UDP issues. If problems persist:
```bash
# Verify Python servers are listening on UDP
docker exec pkmn-server cat /proc/net/udp

# Check for port conflicts on host
sudo netstat -ulpn | grep -E "27900|27901|41000"
```

### Debug Mode

Enable verbose logging:
```bash
# Python server debug mode
docker exec pkmn-server cat /var/www/dwc_network_server_emulator/master_server.py

# Apache debug
docker exec pkmn-server tail -f /var/log/apache2/error.log

# Monitor all activity
docker logs -f pkmn-server
```

## Network Ports

### Required Open Ports

| Port(s) | Protocol | Service | Description |
|---------|----------|---------|-------------|
| 53 | UDP | DNS | dnsmasq DNS server |
| 80 | TCP | HTTP | Apache web server |
| 443 | TCP | HTTPS | Apache SSL (SSLv3) |
| 8000-8003 | TCP | Game Services | Additional game services |
| 9000-9003 | TCP | GameSpy | NAS and other servers |
| 9009, 9998 | TCP | Misc | Additional services |
| 27500 | TCP/UDP | GameSpy | Master server |
| 27900-27901 | TCP/UDP | GameSpy | QR and query servers |
| 28910 | TCP | GameSpy | GP server (profiles) |
| 29900-29901 | TCP | GameSpy | Chat and stats |
| 29920 | TCP | GameSpy | Additional service |
| 41000-41099 | UDP | NAT | NAT negotiation for P2P |

### Firewall Configuration

**UFW Example:**
```bash
# Allow all required ports
sudo ufw allow 53/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000:9003/tcp
sudo ufw allow 9009/tcp
sudo ufw allow 9998/tcp
sudo ufw allow 27500
sudo ufw allow 27900:27901
sudo ufw allow 28910/tcp
sudo ufw allow 29900:29901/tcp
sudo ufw allow 29920/tcp
sudo ufw allow 41000:41099/udp
```

## Security Notes

⚠️ **Important Security Information**

This setup uses **intentionally weak** SSL/TLS configurations (SSLv3, weak ciphers) for Nintendo DS compatibility. 

### Security Considerations

- ❌ **DO NOT** use in production environments
- ❌ **DO NOT** expose to public internet without additional security measures
- ✅ **DO** change all default passwords in `.env`
- ✅ **DO** use strong, unique passwords
- ✅ **DO** run in a protected network or VPN
- ✅ **DO** keep backups of your databases
- ✅ **DO** monitor logs for suspicious activity

### Recommended Security Measures

1. **Firewall**: Only allow connections from trusted IPs
2. **VPN**: Consider running behind a VPN
3. **Monitoring**: Set up log monitoring
4. **Updates**: Keep Docker and base images updated
5. **Backups**: Regular database backups

## Credits

This project builds upon the excellent work of:

- **[CoWFC](https://github.com/EnergyCube/CoWFC)** by EnergyCube - Admin panel and web interface
- **[dwc_network_server_emulator](https://github.com/EnergyCube/dwc_network_server_emulator)** by EnergyCube - GameSpy protocol implementation
- **[pkmn-classic-framework](https://github.com/mm201/pkmn-classic-framework)** by mm201 - GTS implementation
- **[barronwaffles/dwc_network_server_emulator](https://github.com/barronwaffles/dwc_network_server_emulator)** - Alternative maintained fork

Special thanks to the Nintendo DS homebrew and preservation community!

## License

This project is provided as-is for educational and preservation purposes. Please respect Nintendo's intellectual property and only use this for games you legally own.

Individual components maintain their original licenses:
- CoWFC: Check original repository
- dwc_network_server_emulator: Check original repository
- pkmn-classic-framework: MIT License

---

**Made with ❤️ for Pokémon preservation**

For issues and contributions, please visit: [GitHub Repository](https://github.com/jonathan-priebe/pkmn-wfc-server-docker-setup)