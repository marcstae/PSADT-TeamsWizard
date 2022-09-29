# PSADT-TeamsWizard

This is a learning project I undertook in my time at the Workplace team as a part of my apprenticeship @Aveniq.



## Key Features

Note: This project is by no means perfect and was just a proof of concept for myself.

This whole project is about taking a preexisting .exe or .msi and implementing it into a Powershell script that automatically installs it on a customer pc without him having to configure anything afterwards.

![](ztp.png)

* Forked README: <https://github.com/flopach/ztp2go>
* ZTP Repo: <https://github.com/jeremycohoe/c9300-ztp>

## Configuration Steps

### 1. Configuration of the local network (e.g. eth0) = Ethernet port of RasPi

`sudo vim /etc/network/interfaces.d/eth0`

Example config:

```
auto eth0
iface eth0 inet static
hwaddress b8:27:eb:43:80:fe
address 10.100.10.100
netmask 255.255.255.0
gateway 10.100.10.1
```

### 2. Install ISC DHCP-Server on the Raspberry Pi
