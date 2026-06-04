#!/usr/bin/env python3
"""Discover Wiz bulbs on the LAN and update config.json by matching MAC addresses.

Usage:
  ./discover_wiz_lights.py
  ./discover_wiz_lights.py --subnet 192.168.0.0/24
  ./discover_wiz_lights.py --dry-run
"""

import argparse
import concurrent.futures
import ipaddress
import json
import socket
import threading
import time
from pathlib import Path

PORT = 38899
ROOT = Path(__file__).resolve().parent
APP_HOME = Path.home() / ".wiz-cli"
CONFIG_FILE = APP_HOME / "config.json"


def udp_request(ip: str, method: str, params=None, timeout: float = 1.0):
    msg = json.dumps({"id": 1, "method": method, "params": params or {}}).encode("utf-8")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(msg, (ip, PORT))
        data, _addr = sock.recvfrom(8192)
        return json.loads(data.decode("utf-8"))
    finally:
        sock.close()


def udp_send(ip: str, method: str, params=None):
    msg = json.dumps({"id": 1, "method": method, "params": params or {}}).encode("utf-8")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(msg, (ip, PORT))
    finally:
        sock.close()


def query_system_config(ip: str, timeout: float):
    try:
        response = udp_request(ip, "getSystemConfig", timeout=timeout)
        result = response.get("result") or {}
        mac = result.get("mac")
        if mac:
            return ip, str(mac).lower(), result
    except Exception:
        return None
    return None


def discover(subnet: str, timeout: float, workers: int):
    ips = [str(ip) for ip in ipaddress.ip_network(subnet, strict=False).hosts()]
    found = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(query_system_config, ip, timeout) for ip in ips]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                ip, mac, config = result
                found[mac] = {"ip": ip, "config": config}
    return found


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def restore_pilot(ip: str, pilot: dict | None):
    if not isinstance(pilot, dict):
        return
    params = {}
    for key in ("sceneId", "r", "g", "b", "c", "w", "temp", "dimming", "speed"):
        if key in pilot and pilot[key] is not None:
            params[key] = pilot[key]
    if params:
        udp_send(ip, "setPilot", params)
    if pilot.get("state") is False:
        time.sleep(0.15)
        udp_send(ip, "setState", {"state": False})


def read_pilot(ip: str):
    try:
        response = udp_request(ip, "getPilot", timeout=1.0)
        return response.get("result") or {}
    except Exception:
        return None


def blink_until_stopped(ip: str, stop_event: threading.Event):
    colors = (
        {"r": 255, "g": 0, "b": 0, "dimming": 100},
        {"r": 0, "g": 255, "b": 0, "dimming": 100},
        {"r": 0, "g": 0, "b": 255, "dimming": 100},
        {"r": 255, "g": 255, "b": 255, "dimming": 100},
    )
    while not stop_event.is_set():
        for params in colors:
            if stop_event.is_set():
                return
            udp_send(ip, "setPilot", params)
            stop_event.wait(0.7)


def start_identifying(ip: str):
    pilot = read_pilot(ip)
    stop_event = threading.Event()
    thread = threading.Thread(target=blink_until_stopped, args=(ip, stop_event), daemon=True)
    thread.start()
    return pilot, stop_event, thread


def stop_identifying(ip: str, pilot: dict | None, stop_event: threading.Event, thread: threading.Thread):
    stop_event.set()
    thread.join(timeout=1.0)
    restore_pilot(ip, pilot)


def interactive_setup(config: dict, lights: dict, discovered: dict, dry_run: bool):
    mac_to_name = {
        str(entry.get("mac", "")).lower(): str(name)
        for name, entry in lights.items()
        if isinstance(entry, dict) and entry.get("mac")
    }
    updated_lights = {name: dict(entry) for name, entry in lights.items() if isinstance(entry, dict)}

    print("\nInteractive setup")
    print("Each bulb will keep blinking until you answer. Enter its friendly name or 's' to skip.")

    changed = False
    for mac, info in sorted(discovered.items(), key=lambda item: item[1]["ip"]):
        ip = info["ip"]
        device_config = info.get("config") or {}
        existing_name = mac_to_name.get(mac)
        module = device_config.get("moduleName", "-")
        room_id = device_config.get("roomId", "-")

        print(f"\n{ip}  {mac}  module={module}  roomId={room_id}")
        if existing_name:
            print(f"Currently configured as: {existing_name}")

        pilot, stop_event, thread = start_identifying(ip)
        try:
            while True:
                default = existing_name or ""
                suffix = f" [{default}]" if default else ""
                answer = input(f"Name{suffix}: ").strip()
                if answer.lower() in {"s", "skip"}:
                    print("Skipped")
                    break
                name = answer or default
                if not name:
                    print("Skipped")
                    break
                if name in updated_lights and updated_lights[name].get("mac", "").lower() != mac:
                    print(f"Name '{name}' is already used for another light. Choose a different name.")
                    continue

                if existing_name and existing_name != name:
                    updated_lights.pop(existing_name, None)
                old_entry = updated_lights.get(name, {})
                new_entry = {"ip": ip, "mac": mac}
                if old_entry != new_entry:
                    changed = True
                updated_lights[name] = new_entry
                print(f"Configured {name}: {ip} / {mac}")
                break
        finally:
            stop_identifying(ip, pilot, stop_event, thread)

    if dry_run:
        print(f"\nDry run: not writing {CONFIG_FILE}")
    elif changed:
        config["lights"] = updated_lights
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(config, indent=2) + "\n")
        print(f"\nUpdated {CONFIG_FILE}")
    else:
        print("\nconfig.json already up to date")


def main():
    parser = argparse.ArgumentParser(description="Discover Wiz lights and update IP map by MAC address")
    parser.add_argument("--subnet", default="192.168.0.0/24", help="Subnet to scan, default: 192.168.0.0/24")
    parser.add_argument("--timeout", type=float, default=0.8, help="Per-IP UDP timeout, default: 0.8")
    parser.add_argument("--workers", type=int, default=64, help="Concurrent scan workers, default: 64")
    parser.add_argument("--dry-run", action="store_true", help="Print matches without writing config.json")
    parser.add_argument("--interactive", action="store_true", help="Flash each discovered bulb and prompt for its friendly name")
    args = parser.parse_args()

    config = load_json(CONFIG_FILE, {})
    lights = config.get("lights", {}) if isinstance(config, dict) else {}
    if not isinstance(lights, dict):
        raise SystemExit(f"Invalid lights section in {CONFIG_FILE}")

    name_to_mac = {
        str(name): str(entry.get("mac", "")).lower()
        for name, entry in lights.items()
        if isinstance(entry, dict) and entry.get("mac")
    }
    if not name_to_mac and not args.interactive:
        raise SystemExit(f"No light MACs found in {CONFIG_FILE}; use --interactive to create a new config")

    print(f"Scanning {args.subnet} for Wiz lights...")
    discovered = discover(args.subnet, args.timeout, args.workers)

    print(f"Found {len(discovered)} Wiz device(s):")
    for mac, info in sorted(discovered.items(), key=lambda item: item[1]["ip"]):
        device_config = info.get("config") or {}
        module = device_config.get("moduleName", "-")
        room_id = device_config.get("roomId", "-")
        print(f"  {info['ip']:15}  {mac}  {module}  roomId={room_id}")

    if args.interactive:
        interactive_setup(config, lights, discovered, args.dry_run)
        return

    updated_lights = {name: dict(entry) for name, entry in lights.items() if isinstance(entry, dict)}
    changed = False

    print("\nKnown light matches:")
    for name, mac in name_to_mac.items():
        match = discovered.get(mac)
        if not match:
            print(f"  {name:10}  {mac}  not found")
            continue
        ip = match["ip"]
        old_ip = updated_lights.get(name, {}).get("ip")
        updated_lights.setdefault(name, {})["ip"] = ip
        updated_lights[name]["mac"] = mac
        changed = changed or old_ip != ip
        marker = "updated" if old_ip != ip else "unchanged"
        print(f"  {name:10}  {mac}  {old_ip or '-'} -> {ip}  {marker}")

    if args.dry_run:
        print(f"\nDry run: not writing {CONFIG_FILE}")
    elif changed:
        config["lights"] = updated_lights
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(config, indent=2) + "\n")
        print(f"\nUpdated {CONFIG_FILE}")
    else:
        print("\nconfig.json already up to date")


if __name__ == "__main__":
    main()
