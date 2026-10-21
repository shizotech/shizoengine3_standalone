# ShizoNet

ShizoNet is the network protocol of shizoscript. It runs on the Art-Net port (6454) next to Art-Net and does two things:

- **unreliable data** (Art-Net, streams, `send_fast`, static buffers): paced per destination, the pacing adapts to the
  measured packet loss (some ESP32 drop packets when they come too fast)
- **reliable data** (`send`, `get`, `fetch`): sequenced, acknowledged and resent, as fast as the network allows

A **server** sends discovery beacons (every 3 s, the first one right at start), a **client** only answers them. Apart
from that both are the same. Sources: `core/shizoscript3_core/builtin_modules/shizonet/` (the protocol, also compiled for
the ESP32 firmware) and `shz_builtin_shizonet.cpp` (the script API).

| File | |
|---|---|
| `shizonet_platform.h` | addresses, wire structs, timers, the queue between threads, key/value format, the UDP sockets (ESP32, win/linux/mac) |
| `shizonet_platform_os.h` | the plain UDP socket of win/linux/mac |
| `shizonet_artnet.h` | Art-Net packets, the universes we send to a node, frame detection for what we receive |
| `shizonet_buffers.h` | static buffer definitions and the dirty-chunk buffer |
| `shizonet.h` / `.cpp` | receiver, devices, device registry and handshake, commands, client / server |

## Threads (win/linux/mac)

- the **receive thread** blocks on the socket. Acks, ack requests, alive checks, ArtPolls and time sync requests are
  answered right there, so the other side gets them as fast as possible. Completed transfers and everything else go
  to the script thread.
- the **send thread** owns the socket for sending. Every destination has its own queue and pacing: every 64 packets a
  diagnostic request asks how many arrived, lost packets slow the destination down, clean runs speed it up again.
- the **script thread** (`update()`) handles what was received, the handshake and the timers, and queues packets.

Backpressure: every destination has a budget of queued packets (about 20 ms at its current rate,
`send_capacity()`). A device's reliable transfers stop when the budget is used up, so a slow ESP32 does not fill the
queues and does not slow down the other destinations. If the script thread is behind, the receive thread answers new
transfers with *busy* and the sender asks again a little later, instead of acknowledging data that was dropped.

Microcontrollers have no threads of their own: lwIP hands the packets over in its callback, the main loop does the rest.

## Devices

A device is created when it is first seen and **never deleted when it disconnects**: it goes *offline* and keeps its
object, settings and static buffers. Offline devices are freed after a day (not the ones added by script). Offline
devices with a known IP are polled directly, so they are found again in other subnets as well.

States: `offline` → `auth` (auth request sent) → `init` (init commands and device info) → `online`.

Handshake (both nodes run the same code, every step is answered at once, timers only resend what got lost):

1. `AUTH_BEACON` → `AUTH_BEACON_REPLY` (each side's session id)
2. `AUTH_REQ` (session id + node info) → `AUTH_REPL`: both nodes register each other
3. `shznet_init_device` → `shznet_init_device_result`: each side knows it is registered on the other one
4. get `shznet_init_connection`: the device info (commands, static buffers, capabilities) → online

Two nodes on one network connect in a few milliseconds.

A node's MAC is the same on every start: the hardware address of the network card (on Linux / macOS physical cards
first, on Windows the first adapter), plus the port for every further node on the same machine (the first one gets
6454, the next 6455, ...). So a restarted PC is the same device on the other side, like an ESP32.

**Restarts**: a node that restarts (an ESP32 after a reboot, same MAC) has new session ids and forgot ours. That is
seen in the beacon replies, auth requests and acks, the device goes through `on_disconnect` / `on_connect` right away
(no timeout). Reliable sends the device could not have executed yet (not all packets were sent) are sent again after
the new handshake, sends it may have executed already are reported as failed: sending them again could run a command
twice (e.g. a reboot).

## Art-Net

- Any number of universes (Port-Address 0 - 32767). A node only gets memory for the universes that are written.
- `artnet_sync_now()` ends a frame: an ArtSync, then the written data is committed and sent 4 universes per node every
  2 ms. Universes that did not change are resent every second (nodes like WLED leave realtime mode otherwise).
- The frame rate is not limited: when frames come faster than 4 universes per 2 ms can send them (many universes,
  120+ fps), a node gets more universes per step, so its frame is still out before the next one.
- Optional frame rate limit, off by default: `net.artnet_max_fps(fps)` for all nodes, `artnet_device.max_fps(fps)` per
  node (wins over the other). A frame inside the limit is skipped for that node, its data goes out when the node's
  next frame is due, so the last frame is never lost.
- Without `artnet_sync_now()`, the node sends frames of its own without ArtSync, 30 per second
  (`net.artnet_auto_fps(fps)`, 0: none). `net.artnet_fps()`: the frame rate that is sent right now.
- `set_artnet_buffer(..., wrap_leds = true, ...)`: a universe holds whole pixels only (170 RGB LEDs, 128 RGBW LEDs),
  without it pixels continue over the universe border.
- The universes a node announces in its ArtPollReplies (SwOut / SwIn, all BindIndexes): `artnet_device.universes()`.
- Our own ArtPollReply announces ports 1 - 4, or what `net.artnet_ports([...])` sets.
- Nodes that do not answer ArtPolls (or before they answer): `net.add_artnet_device(ip, name)`.

Receiving: `on_artnet(fn(universe, data))` for every universe, frames (all universes that arrive regularly) are
detected for any number of universes.

## Network interfaces

By default every interface is used: ArtPoll goes to the directed broadcast address of every IPv4 interface that is up
(#194), the other broadcasts (ShizoNet beacons, ArtSync, stream broadcasts) to 255.255.255.255, which leaves through the
interface of the default route. That includes virtual interfaces (docker, VPN, WSL, Hyper-V switches, bridges) and
networks where Art-Net has no business (the office Wi-Fi). #501 lets a script choose:

```
for (i : shizonet.interfaces())            // one entry per IPv4 address
    std.print(i.name, i.ip, i.physical, i.wireless, i.used);
shizonet.use_interfaces("physical");       // only network cards (wired, Wi-Fi), no virtual interfaces
shizonet.use_interfaces(["eth1", "Ethernet 2"]);   // these (names without case; Windows: also description or id)
shizonet.use_interfaces(["physical", "wg0"]);      // the network cards and wg0
shizonet.use_interfaces("all");            // default
```

- With a selection every broadcast (ArtPoll, ArtSync, beacons, streams) goes to the directed broadcast addresses of the
  selected interfaces that are up, 255.255.255.255 is not used. A selection without an interface sends no broadcasts.
- Packets from the network of an interface that is not selected are dropped (the node does not find or accept devices
  there). Loopback and routed networks (not on any interface of this machine) are always accepted.
- Unicast to known devices (found before, or added with `add_artnet_device(ip)`) is not filtered: the system routes it.
- Process wide, for every node of `shz` (not for the Prolink module, which has its own copy of ShizoNet). The interface
  list is read again every 2 seconds, so cards and cables that come and go are picked up.
- `physical`: Linux: the interface has a device (`/sys/class/net/<name>/device`). macOS: `en0`, `en1`, ... Windows:
  Ethernet or Wi-Fi adapters whose description and MAC address are not those of a virtual switch / VPN / tunnel.
  `wireless` is not known on macOS.
- The socket is still bound to all interfaces (`INADDR_ANY`).
- VibeVJ: *Devices* › *Network* › *Network cards*, kept in `engine/style.json` (`network_interfaces`).
- Test: `_testing/shizonet_interfaces.shio`.

## Static buffers

A device describes fixed size buffers in its device info, the other side keeps a copy, only the 256 byte chunks that
changed are sent (unreliable, with the frames).

| field | |
|---|---|
| `type` | `data`, `leds`, `dmx`, `motors`, `servos`, `sensors` |
| `direction` | `output`: written by the server, read by the device. `input`: written by the device (sensors), read by the servers |
| `value` | `u8`, `u16`, `i16`, `u32`, `i32`, `f32` |
| `channels`, `count` | values per element (3 for RGB LEDs), number of elements |
| `order` | channel order or names, e.g. `"GRB"`, `"RGBW"`, `"XYZ"` |
| `rate` | input buffers: maximum send rate |
| `description`, `setup` | text for humans / for programs (e.g. json) |

```
//on the device (or in C++: add_buffer(shznet_buffer_def::leds("strip", 300, 3, "GRB"), memory))
net = shizonet.client("lamp");
net.add_buffer("strip", [type = "leds", count = 300, channels = 3, order = "GRB"]);
net.add_buffer("temp", [type = "sensors", count = 2, value = "f32", direction = "input"]);
net.on_buffer("strip", [](server, data) { /* show data */ });
net.set_buffer_value("temp", 0, 21.5);

//on the server
dev.set_leds("strip", 0, pixels);           //converted to the channels of the buffer
net.artnet_sync_now();
dev.on_buffer("temp", [](dev, data) { std.print(dev.buffer_value("temp", 0)); });
```

Older nodes see the buffers with their old type (`data`, LEDs with 1 - 4 channels). Before a device is online its
buffers can be defined by script (`net.add_device(mac, ip)`, `dev.define_buffer(name, definition)`) and written; the
data is sent when it connects.

## Time sync

Nodes measure the clock offset to each other (NTP like, the request with the shortest round trip of the last 8 wins,
one request per second, answered in the receive thread). `dev.time_offset()`, `dev.time()`, `dev.ping()`,
`net.time()`, `net.network_time()`: the clock of the connected server with the lowest MAC, the same on all nodes
(e.g. to run animations on several devices in sync).

## Script API (additions)

Node (`shizonet.server` / `shizonet.client`): `all_devices`, `add_device(mac, ip, name)`,
`add_artnet_device(ip, name, mac)`, `artnet_ports`, `artnet_auto_fps`, `artnet_max_fps`, `artnet_fps`, `add_buffer`, `buffers`, `buffer`, `write_buffer`,
`set_buffer_value`, `buffer_value`, `on_buffer`, `receiving`, `time`, `network_time`, `time_master`.
`get(command, data, timeout)` queries the first device that supports the command; `get_all(command, data, callback, timeout)` queries all matching devices and waits for their responses. `broadcast(command, data)` sends the request to all matching devices without waiting for responses and returns the number that accepted it.
`set_prop(name, value)` stores a local property (including JSON values); `device.get_prop(name, timeout)` fetches it from that device on demand, so changes are visible without syncing or caching properties on the requester.
`on(command, callback)` handles GET requests like `on_get`, but always sends an empty response; use `on_get` when the request needs a value back.
`find_device` also returns offline devices, `devices()` only the online ones, `on_disconnect` gets the device.

Device: `state`, `dummy`, `pending`, `buffers`, `define_buffer`, `write_buffer`, `set_leds`, `set_buffer_value`,
`buffer_value`, `read_buffer`, `clear_buffers`, `on_buffer`, `time`, `time_offset`, `ping`.

Art-Net device: `online` (answered a poll within 10 s), `dummy`, `max_fps`, `universes`, `input_universes`,
`used_universes`, `get_artnet_channel`, `clear`.

## Compatibility

The packets and the handshake are the same as before (compat version 15, older nodes still work with newer ones and the
other way round, OTA updates over ShizoNet keep working). New things are in new keys of the device info and in new
packet types, older nodes ignore them: no time sync, no buffer layouts, no input buffers with them.

Tests: `_testing/shizonet.shio` (script API) and `_testing/native/shizonet_test.cpp` (protocol: restarts, big
transfers, the queue between threads).
