# 📡 4G LTE KeepAlive 📡

## Automatically monitors 4G connection via QMI/MBIM (OpenWRT) and revives the connection when ping loss exceeds 60%. Includes automatic router reboot after 3 failed recovery cycles.

## 🛠️ Features 🛠️

- Monitors 4G connection via ping
- Automatic QMI/MBIM recovery when ping loss > 60%
- Configurable via UCI
- Syslog logging with tag `LTE-KA`
- Automatic router reboot after 3 failed recovery cycles
- Uses only busybox tools and uqmi
- Init.d service enabled by default

## ⚙️ Platforms ⚙️

- x86-64
- ramips-mt76x8
- ath79-generic

## 🔧 Installation Guide 🔧

### From Source

```bash
# Clone repository
git clone <repository-url>
cd 4G-LTE-KeepAlive

# Copy to OpenWrt SDK
cp -r Makefile src <openwrt-sdk>/package/4g-lte-keepalive/

# Build
cd <openwrt-sdk>
make package/4g-lte-keepalive/compile
```

### From IPK

```bash
opkg install 4g-lte-keepalive_1.0.0-1_all.ipk
```

## ⚙️ Configuration ⚙️

Edit `/etc/config/lte-keepalive`:

```uci
config config
	option enabled '1'
	option ping_target '8.8.8.8'
	option ping_count '10'
	option ping_interval '5'
	option loss_threshold '60'
	option max_failed_cycles '3'
	option qmi_device '/dev/cdc-wdm0'
	option apn ''
	option username ''
	option password ''
	option pincode ''
```

Then restart the service:

```bash
/etc/init.d/lte-keepalive restart
```

## 🧑‍💻 Usage 🧑‍💻

The service starts automatically after installation. To control it manually:

```bash
/etc/init.d/lte-keepalive start
/etc/init.d/lte-keepalive stop
/etc/init.d/lte-keepalive restart
/etc/init.d/lte-keepalive status
```

## 📜 Logs 📜

View logs with:

```bash
logread | grep LTE-KA
```
