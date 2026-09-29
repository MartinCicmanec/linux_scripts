# ATTinyCore Setup for ATTiny85 with Micronucleus on Arch Linux

## Problem
ATTinyCore installation via Arduino IDE Board Manager fails because the azduino.com server hosting the Micronucleus tool is down:
```
Error: 2 UNKNOWN: Get "https://azduino.com/bin/micronucleus/micronucleus-cli-2.5-azd1-x86_64-linux-gnu.tar.bz2": dial tcp 3.218.2.136:443: connect: connection refused
```

## Solution Overview
1. Install Micronucleus from Arch Linux repos instead of the bundled version
2. Use native Arduino IDE (not Flatpak) as recommended by ATTinyCore documentation
3. Manually install ATTinyCore
4. Configure ATTinyCore to use system Micronucleus

## Prerequisites
- Arch Linux system
- ATTiny85 with Micronucleus bootloader
- microUSB connection for programming

## Installation Steps

### Step 1: Install Micronucleus from System Repos

```bash
# Install micronucleus
sudo pacman -S micronucleus

# Add your user to uucp group for USB device access (replace 'martin' with your username)
sudo usermod -aG uucp $USER

# Verify installation
which micronucleus
micronucleus --help
```

**Note:** You must log out and back in (or reboot) for the group membership to take effect.

### Step 2: Download Native Arduino IDE

The Flatpak version has sandboxing issues and can't access system binaries. ATTinyCore documentation specifically warns against using IDE versions from package managers.

```bash
# Download Arduino IDE 2.3.7 AppImage
cd /tmp
curl -L "https://downloads.arduino.cc/arduino-ide/arduino-ide_2.3.7_Linux_64bit.AppImage" -o arduino-ide.AppImage

# Make it executable
chmod +x arduino-ide.AppImage

# Move to Applications directory
mkdir -p ~/Applications
mv arduino-ide.AppImage ~/Applications/
```

### Step 3: Create Desktop Launcher (Optional)

```bash
# Create desktop entry
cat > ~/.local/share/applications/arduino-ide.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Arduino IDE
Comment=Arduino IDE 2.3.7
Exec=/home/martin/Applications/arduino-ide.AppImage %U
Icon=arduino
Terminal=false
Categories=Development;Electronics;
MimeType=text/x-arduino;
EOF

# Make it executable and update database
chmod +x ~/.local/share/applications/arduino-ide.desktop
update-desktop-database ~/.local/share/applications/
```

**Note:** Replace `/home/martin` with your actual home directory path.

### Step 4: Install ATTinyCore Manually

```bash
# Clone ATTinyCore repository
cd /tmp
git clone https://github.com/SpenceKonde/ATTinyCore.git

# Create hardware directory and install
mkdir -p ~/Arduino/hardware/ATTinyCore
cp -r ATTinyCore/* ~/Arduino/hardware/ATTinyCore/

# Verify installation
ls ~/Arduino/hardware/ATTinyCore/avr/boards.txt
```

### Step 5: Configure ATTinyCore to Use System Micronucleus

Create a platform override file to use the system Micronucleus instead of the bundled one:

```bash
# Create platform.local.txt
cat > ~/Arduino/hardware/ATTinyCore/avr/platform.local.txt << 'EOF'
# Override micronucleus path to use system installation
tools.micronucleus.cmd.path=/usr/bin/micronucleus
EOF
```

### Step 6: Launch Arduino IDE and Configure

1. **Start Arduino IDE:**
   ```bash
   ~/Applications/arduino-ide.AppImage
   ```

2. **Configure for ATTiny85:**
   - Go to **Tools > Board** → **ATTinyCore** → **ATtiny25/45/85 (No bootloader)**
   - Set **Tools > Chip** → **ATtiny85**
   - Set **Tools > Clock Source** → **16.5 MHz (internal, tweaked for USB)** (for Micronucleus)
   - Set **Tools > Programmer** → **Micronucleus**

### Step 7: Upload Code

1. Plug in your ATTiny85 via USB
2. Click **Upload** in Arduino IDE
3. The Micronucleus bootloader has approximately 5 seconds after plugging in to receive code
4. Progress will be displayed in the Arduino IDE console

## Verification

Check that everything is working:

```bash
# Verify micronucleus is installed
which micronucleus
# Should output: /usr/bin/micronucleus

# Verify user is in uucp group
groups $USER | grep uucp

# Verify ATTinyCore is installed
ls ~/Arduino/hardware/ATTinyCore/avr/boards.txt

# Verify platform override exists
cat ~/Arduino/hardware/ATTinyCore/avr/platform.local.txt
```

## Troubleshooting

### USB Permission Denied
- Make sure you're in the `uucp` group: `groups $USER`
- If not, add yourself: `sudo usermod -aG uucp $USER`
- Log out and back in for changes to take effect

### Micronucleus Not Found
- Verify installation: `which micronucleus`
- Check platform.local.txt has correct path: `cat ~/Arduino/hardware/ATTinyCore/avr/platform.local.txt`

### Upload Timeout
- Micronucleus bootloader is only active for ~5 seconds after plugging in the device
- Unplug and replug the ATTiny85, then immediately click Upload

### ATTinyCore Boards Not Showing
- Check installation directory: `ls ~/Arduino/hardware/ATTinyCore/avr/`
- Restart Arduino IDE
- Verify you're using the native IDE, not Flatpak

## References

- [ATTinyCore GitHub](https://github.com/SpenceKonde/ATTinyCore)
- [ATTinyCore Installation Guide](https://github.com/SpenceKonde/ATTinyCore/blob/v2.0.0-devThis-is-the-head-submit-PRs-against-this/Installation.md)
- [Micronucleus Documentation](https://github.com/micronucleus/micronucleus)

## Notes

- Date of setup: 2026-01-18
- Arduino IDE version: 2.3.7
- Micronucleus version: 2.6
- ATTinyCore version: Latest from GitHub (development branch)
- Issue: azduino.com server hosting bundled Micronucleus was unreachable
