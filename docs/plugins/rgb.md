# SylRGB

One place for the lights on your mouse, keyboard, headset, memory, graphics card, motherboard, cooler and LED strips. SylRGB decides the colours; [OpenRGB](https://openrgb.org) talks to the hardware, so every device OpenRGB supports works here (several hundred, from SteelSeries, Logitech, Razer, Corsair, HyperX, ASUS, MSI, Gigabyte, Kingston and many others).

## Set it up

1. Install OpenRGB and turn on its SDK server. On NixOS that is one line, which also runs it as a service that can reach every device:

   ```nix
   services.hardware.openrgb.enable = true;
   ```

   Elsewhere, install `openrgb` from your distribution and either run `openrgb --server` at login or open OpenRGB and start the server in its SDK Server tab. Its udev rules (installed with the package) let it reach USB devices without root.
2. Turn SylRGB on in SylSettings › Plugins or with `sylvaris plugins enable rgb`.
3. Open it with `sylvaris rgb open`, from the Lighting tile in SylCenter, or from SylSettings › Lighting.

SylRGB needs `python3` (already there for other parts) and nothing else; it speaks OpenRGB's network protocol itself.

## What it does

- **One colour for everything**, from the swatches or a hex code, just for the lights. Or turn on "Follow the theme": every device takes the theme's colour and changes with it. Theme accents are chosen for screens and often look dull on LEDs, so SylRGB sends them at full strength ("Vivid theme colours", on by default; greys become white). A theme can also name its own LED colour with `colors.rgb`, which wins over the accent.
- **Brightness** scales every colour it sends.
- **Each device on its own**: tap a device for its own colour or one of its effects (breathing, spectrum and whatever else the device offers), or switch it off with its toggle.
- **A flash when you click**: tap a mouse and pick a colour under "When a button is pressed". The mouse shows that colour for as long as any button is held and goes back to its own colour when you let go. See [clicks and privacy](#clicks-and-privacy).
- **Lights off** turns every device dark and back with one switch or the "Turn all lighting off" button, also from SylCenter and `sylvaris rgb off`.
- **Restart OpenRGB** restarts its systemd service (a user service without asking; the system service asks for your password) and puts your colours back once it answers again. Colours also come back on their own whenever OpenRGB restarts.
- **Colours that stick**: a plain colour goes to a device's Static mode at full brightness when it has one, so keyboards keep it after their own lighting key switches the light off and on again. Devices without one get their colour LED by LED.
- **OpenRGB profiles** you saved in OpenRGB load with one tap. Loading one clears the colours picked in SylRGB, so the two never fight.
- **Colours come back** when Sylvaris starts and whenever a device reconnects, for example a wireless mouse waking up. Turn this off in SylSettings › Lighting if you would rather keep whatever the device shows.

Until you pick something, SylRGB leaves every device exactly as it is.

## Commands

```sh
sylvaris rgb                                   # state as JSON
sylvaris rgb open                              # the panel (also: toggle, close)
sylvaris rgb list                              # devices and their effects
sylvaris rgb color ff8800                      # every device
sylvaris rgb color 00c7be "Krux Atax Pro RGB"  # one device
sylvaris rgb mode Breathing                    # every device that has it
sylvaris rgb mode "Spectrum Cycle" "Krux Atax Pro RGB"
sylvaris rgb follow on                         # use the theme's colour
sylvaris rgb vivid off                         # send the theme's accent as it is
sylvaris rgb press ffffff                      # every mouse flashes white while clicked
sylvaris rgb press off "SteelSeries Aerox 3 Wireless"
sylvaris rgb brightness 40
sylvaris rgb off                               # also: on
sylvaris rgb restart                           # restart OpenRGB and put the colours back
sylvaris rgb profile Evening                   # load an OpenRGB profile
```

Names with spaces go in quotes. `sylvaris watch rgb` streams changes.

## Settings

Everything lives under `rgb` in `settings.json`: `on`, `color`, `follow`, `vivid`, `brightness`, `restore`, `devices` (per-device `off`, `color`, `mode` and `press`, keyed by the name OpenRGB shows), `host` and `port` (the SDK server, `127.0.0.1:6742` by default; another computer's address works too). `placement.rgb` sets where the panel opens, and `center.extra` can hold the `rgb` tile.

## Clicks and privacy

Wayland does not tell other programs about your clicks, so for the click flash SylRGB reads the mouse's own input device (`/dev/input/event…`), found through the USB device OpenRGB uses for that mouse. It opens only that mouse's devices, acts only on mouse-button events, and never stores or sends anything it reads. Nothing is read while no device has a press colour.

Your user needs read access to those device files. On most systems the logged-in user already has it; if the panel says it cannot read `/dev/input/event…`, add a udev rule for that mouse only (not the `input` group, which would expose your keyboard too). On NixOS, for example:

```nix
services.udev.extraRules = ''
  SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="1838", TAG+="uaccess", RUN{builtin}+="uaccess"
'';
```

The flash needs the mouse in plain-colour mode; with an effect or with the mouse switched off it stays out of the way.

## Devices that need a hand

**SteelSeries Rival 3 Wireless and Aerox 3 Wireless.** Both use the same 2.4 GHz dongle, so OpenRGB lists the mouse as "SteelSeries Aerox 3 Wireless" either way. Colours set while the mouse sleeps show up as soon as it wakes, because SylRGB puts them back when the device reconnects. With the cable plugged in, OpenRGB lists the Aerox 3 a second time as "SteelSeries Aerox 3 Wireless Wired", with its own colour and press flash. The Aerox 3 can also flash on clicks by itself (the reactive colour set in SteelSeries GG or rivalcfg), which would cover SylRGB's flash, so while it has a press colour SylRGB switches that off until the mouse is next plugged in, without saving it to the mouse.

OpenRGB does not notice devices plugged in after it started, so SylRGB asks it to look again whenever a HID device comes or goes, and the colours follow a moment later.

**Krux Atax Pro RGB** (USB `3299:2736`). It uses the same EVision V2 controller as the Endorfy Omnis, which OpenRGB 1.0 already drives, but OpenRGB does not list its ID yet. Until it does, add the ID with a small patch. On NixOS:

```nix
services.hardware.openrgb.package = pkgs.openrgb.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    echo 'REGISTER_HID_DETECTOR_IP("Krux Atax Pro RGB", DetectEVisionV2Keyboards, SPCGEAR_VID, 0x2736, 1, EVISION_KEYBOARD_USAGE_PAGE);' \
      >> Controllers/EVisionKeyboardController/EVisionV2KeyboardController/EVisionV2KeyboardControllerDetect.cpp
  '';
});
```

On other distributions, add the same line to that file and build OpenRGB from source. OpenRGB then finds the keyboard with its logo and edge lights as separate devices. If single keys light up in the wrong places, the key layout differs from the generic one and is worth reporting to OpenRGB.

**A device OpenRGB does not see.** Check OpenRGB's own window first: if it is not listed there, SylRGB cannot see it either. [OpenRGB's supported devices](https://openrgb.org/devices.html) lists what works, and its issue tracker is where new devices get added.
