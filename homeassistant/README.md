# Home Assistant OS: reliable `homeassistant.local` and Wi-Fi

Setup: Home Assistant OS on a Raspberry Pi (`end0` Ethernet, `wlan0` Wi-Fi), MikroTik hAP ac^3 (RouterOS 7.24), one flat `192.168.88.0/24` bridge, Arch Linux client.

Goal: `homeassistant.local:8123` resolves regardless of the DHCP-assigned IP, with no static `.local` rules.

## 1. Wi-Fi on the Pi would not stay connected

**Symptom:** after a reboot `wlan0` had no IP and `ha network update` failed with
`Activating connection failed, check connection settings.`

**Cause:** the 2.4 GHz SSID `MikroTik-A265E4` was on channel 12 (2467 MHz). The Pi has no regulatory country set, so it cannot associate on channels 12-13. The host log showed `ssid-not-found`. The 2.4 GHz and 5 GHz radios use different SSIDs (`...E4` / `...E5`), which is why only the 5 GHz one appeared in the UI.

**Fix (MikroTik):** move the 2.4 GHz radio to channel 6 with a 20 MHz width.

```routeros
/interface/wifi set wifi1 channel.frequency=2437 channel.width=20mhz
```

**Fix (Home Assistant CLI):** re-save the Wi-Fi profile. Single quotes are required if the password contains `!`.

```bash
ha network update wlan0 --ipv4-method auto \
  --wifi-mode infrastructure --wifi-auth wpa-psk \
  --wifi-ssid 'MikroTik-A265E4' --wifi-psk '<password>'
```

**Verify persistence:**

```bash
ha network info     # wlan0 shows the SSID and an IPv4 address
ha host reboot      # clean reboot, not a power pull
ha network info     # still connected
```

Use `ha host shutdown` before physically moving the device.

## 2. `.local` resolution on the Arch client

mDNS (UDP 5353 multicast) is resolved client to device on the same L2 segment, so the router needs no configuration.

The client needed an mDNS resolver. Plain avahi + nss-mdns fixed browsers but not the Butler Flatpak, which can only use the systemd-resolved socket. Final setup:

```bash
sudo systemctl disable --now avahi-daemon.service avahi-daemon.socket
sudo systemctl enable --now systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
nmcli connection modify "<connection name>" connection.mdns yes
nmcli connection up "<connection name>"
```

Check with `resolvectl query homeassistant.local`.

## 3. Cleanup on the MikroTik

The static `homeassistant.lan` entry was only a workaround and was removed:

```routeros
/ip dns static remove [find name=homeassistant.lan]
```

## Notes

- Router upstream DNS was set to `192.168.88.238` (HA's Wi-Fi IP, a leftover from a DuckDNS attempt). This is fragile: if HA is down, router DNS breaks. Prefer a public or ISP resolver.
- HA is dual-homed (Ethernet and Wi-Fi), so it has two DHCP leases. `.local` can resolve to either.
- Wi-Fi password was pasted into a chat during troubleshooting and should be rotated.
- `.local` does not cross the WireGuard tunnel (`wg0`, `10.10.10.0/24`).
- If a Wi-Fi network has to be hidden, the HA CLI has no flag for it; use a keyfile with `hidden=true` on a CONFIG USB stick instead.
