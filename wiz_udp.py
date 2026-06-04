import socket
import json

# Minimal non-interactive helper for Wiz UDP commands.

def udp_client(ip, port, message):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, 0)
    try:
        s.sendto(message.encode('utf-8'), (ip, port))
        s.settimeout(3)
        try:
            data, address = s.recvfrom(4096)
            print(f"[-] Data received from Client : {data.decode('utf-8')}")
        except socket.timeout:
            # Non-fatal: Wiz bulbs sometimes don't answer
            print("[-] No response from bulb (timeout)")
    finally:
        s.close()


def set_rgb(ip, port, r, g, b, dimming=100):
    message = json.dumps({
        "id": 1,
        "method": "setPilot",
        "params": {"r": r, "g": g, "b": b, "dimming": dimming},
    })
    udp_client(ip, port, message)


def set_dimming(ip, port, dimming):
    message = json.dumps({
        "id": 1,
        "method": "setPilot",
        "params": {"dimming": dimming},
    })
    udp_client(ip, port, message)


def set_temp(ip, port, temp, dimming=100):
    message = json.dumps({
        "id": 1,
        "method": "setPilot",
        "params": {"temp": temp, "dimming": dimming},
    })
    udp_client(ip, port, message)


def set_scene(ip, port, scene_id, dimming=100, speed=None):
    params = {"sceneId": scene_id}
    if dimming is not None:
        params["dimming"] = dimming
    if speed is not None:
        params["speed"] = speed
    message = json.dumps({
        "id": 1,
        "method": "setPilot",
        "params": params,
    })
    udp_client(ip, port, message)


def set_power(ip, port, state):
    message = json.dumps({
        "id": 1,
        "method": "setState",
        "params": {"state": bool(state)},
    })
    udp_client(ip, port, message)


def request(ip, port, method, params=None, timeout=3):
    message = json.dumps({"id": 1, "method": method, "params": params or {}})
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, 0)
    try:
        s.sendto(message.encode("utf-8"), (ip, port))
        s.settimeout(timeout)
        data, _address = s.recvfrom(4096)
        return json.loads(data.decode("utf-8"))
    finally:
        s.close()


def get_pilot(ip, port):
    return request(ip, port, "getPilot")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Non-interactive Wiz control helper")
    parser.add_argument("--ip", required=True, help="IP of the Wiz light")
    parser.add_argument("--port", type=int, default=38899, help="UDP port (default 38899)")
    parser.add_argument("--mode", choices=["on", "off", "rgb", "dimming", "temp", "scene", "status"], required=True, help="Operation mode")
    parser.add_argument("--r", type=int, help="Red 0-255 (rgb mode)")
    parser.add_argument("--g", type=int, help="Green 0-255 (rgb mode)")
    parser.add_argument("--b", type=int, help="Blue 0-255 (rgb mode)")
    parser.add_argument("--dimming", type=int, default=100, help="Dimming 10-100")
    parser.add_argument("--temp", type=int, default=2700, help="White color temperature in Kelvin (temp mode)")
    parser.add_argument("--scene-id", type=int, help="Wiz scene id (scene mode)")
    parser.add_argument("--speed", type=int, help="Dynamic scene speed 10-200 (scene mode)")
    parser.add_argument("--preserve-dimming", action="store_true", help="Do not send dimming in scene mode")

    args = parser.parse_args()

    if args.mode == "on":
        set_power(args.ip, args.port, True)
    elif args.mode == "off":
        set_power(args.ip, args.port, False)
    elif args.mode == "rgb":
        if args.r is None or args.g is None or args.b is None:
            raise SystemExit("--r, --g, --b are required in rgb mode")
        set_rgb(args.ip, args.port, args.r, args.g, args.b, args.dimming)
    elif args.mode == "dimming":
        set_dimming(args.ip, args.port, args.dimming)
    elif args.mode == "temp":
        set_temp(args.ip, args.port, args.temp, args.dimming)
    elif args.mode == "scene":
        if args.scene_id is None:
            raise SystemExit("--scene-id is required in scene mode")
        dimming = None if args.preserve_dimming else args.dimming
        set_scene(args.ip, args.port, args.scene_id, dimming, args.speed)
    elif args.mode == "status":
        print(json.dumps(get_pilot(args.ip, args.port)))
