## Automatic installation for EngineGP
**This shell script allows you to:**
- Install EngineGP in automatic mode;
- Set up a location (unit);
- Download game servers.
## Supported systems:
- **GNU/Linux:** Debian 11, 12
- **GNU/Linux:** Ubuntu 22.04, 24.04
> [!IMPORTANT]
> The architecture and bit depth of x86_64 are required.
## Starting the auto installer:
**Update indexes and packages**
```bash
apt -y update && apt -y full-upgrade
```
**Install GIT**
```bash
apt -y install git
```
**Clone the repository**
```bash
git clone https://github.com/EngineGPDev/Autoinstall.git
```
**Make the installation file executable**
```bash
chmod +x ./Autoinstall/install.sh
```
**Run automatic installation**
```bash
./Autoinstall/install.sh
```
## Automatic installation keys:
**Forcibly specifying an IP address**
```bash
./Autoinstall/install.sh --ip 192.0.2.0
```
> [!NOTE]
> Instead of 192.0.2.0, you need to substitute your IP address.

**Choosing the php version**
```bash
./Autoinstall/install.sh --php 8.2
```
> [!NOTE]
> Instead of 8.2, you need to substitute the desired php version;\
> Supported php versions: 7.4, 8.0, 8.1, 8.2

**Choosing an EngineGP release**
```bash
./Autoinstall/install.sh --release
```
> [!NOTE]
> --release - the current stable version;\
> --beta - current beta version;\
> --snapshot - future beta version.
