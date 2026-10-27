#!/usr/bin/env python3
import argparse
import base64
import json
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlencode, urlparse
from urllib.request import Request, urlopen

import yaml


CONFIG = Path(__file__).with_name("dotfiles") / "sing-box.json"
URLTEST_GROUPS = [
    ("日本 URLTest", "❤️ ", "日本专线"),
    ("新加坡 URLTest", "❤️ ", "新加坡专线"),
    ("🐰 SG URLTest", "🐰 ", " SG "),
    ("🐰 JP URLTest", "🐰 ", " JP "),
    ("🐰 TW URLTest", "🐰 ", " TW "),
]
URLTEST_URL = "https://www.gstatic.com/generate_204"
SUBSCRIPTION_ICONS = ("❤️", "🐰")


def read_subscription(args):
    if args.url:
        urls = [args.url]
    elif args.url_file:
        urls = [line.strip() for line in Path(args.url_file).read_text().splitlines()
                if line.strip() and not line.lstrip().startswith("#")]
    else:
        yield "", sys.stdin.read()
        return
    for index, url in enumerate(urls):
        icon = SUBSCRIPTION_ICONS[index] if index < len(SUBSCRIPTION_ICONS) else ""
        try:
            yield icon, read_subscription_url(url)
        except Exception as exc:
            print(f"Failed to fetch subscription {url}: {exc}", file=sys.stderr)


def read_subscription_url(url):
    request = Request(url, headers={"User-Agent": "nix-config-subscription-importer"})
    with urlopen(request, timeout=30) as response:
        return response.read().decode()


def decode_subscription(text):
    text = text.strip()
    text = re.sub(r"^```[a-zA-Z0-9_-]*\n?", "", text)
    text = re.sub(r"\n?```$", "", text)
    if re.search(r"^proxies:", text, re.MULTILINE):
        return text
    compact = re.sub(r"\s+", "", text)
    if compact.startswith(("vless://", "hysteria2://", "hy2://", "ss://")):
        return text
    padding = "=" * (-len(compact) % 4)
    return base64.b64decode(compact + padding).decode()


def unique_tag(tag, seen):
    tag = tag.strip() or "proxy"
    original = tag
    index = 2
    while tag in seen:
        tag = f"{original} {index}"
        index += 1
    seen.add(tag)
    return tag


def first(query, key, default=""):
    return query.get(key, [default])[0]


def parse_vless(link, seen):
    parsed = urlparse(link)
    query = parse_qs(parsed.query)
    tag = unique_tag(unquote(parsed.fragment), seen)
    server = parsed.hostname
    port = parsed.port
    if not server or not port or server in {"127.0.0.1", "localhost"}:
        return None

    outbound = {
        "type": "vless",
        "tag": tag,
        "server": server,
        "server_port": port,
        "uuid": parsed.username,
    }

    flow = first(query, "flow")
    if flow:
        outbound["flow"] = flow

    security = first(query, "security")
    if security in {"tls", "reality"}:
        tls = {
            "enabled": True,
            "server_name": first(query, "sni") or first(query, "host") or server,
            "insecure": first(query, "insecure") == "1",
        }
        fingerprint = first(query, "fp")
        if fingerprint:
            tls["utls"] = {
                "enabled": True,
                "fingerprint": fingerprint,
            }
        if security == "reality":
            tls["reality"] = {
                "enabled": True,
                "public_key": first(query, "pbk"),
            }
            short_id = first(query, "sid")
            if short_id:
                tls["reality"]["short_id"] = short_id
        outbound["tls"] = tls

    transport_type = first(query, "type")
    if transport_type == "ws":
        headers = {}
        host = first(query, "host")
        if host:
            headers["Host"] = host
        transport = {
            "type": "ws",
            "path": first(query, "path", "/") or "/",
        }
        if headers:
            transport["headers"] = headers
        outbound["transport"] = transport

    return outbound


def parse_hysteria2(link, seen):
    parsed = urlparse(link)
    query = parse_qs(parsed.query)
    tag = unique_tag(unquote(parsed.fragment), seen)
    server = parsed.hostname
    port = parsed.port
    if not server or not port or server in {"127.0.0.1", "localhost"}:
        return None

    outbound = {
        "type": "hysteria2",
        "tag": tag,
        "server": server,
        "server_port": port,
        "password": parsed.username,
        "tls": {
            "enabled": True,
            "server_name": first(query, "sni") or server,
            "insecure": True,
        },
    }

    server_ports = first(query, "mport")
    if server_ports:
        server_ports = server_ports.replace("-", ":", 1)
        outbound["server_ports"] = [server_ports]

    return outbound


def parse_shadowsocks(link, seen):
    parsed = urlparse(link)
    if "@" not in parsed.netloc:
        encoded = link[5:].split("#", 1)[0]
        decoded = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)).decode()
        parsed = urlparse(f"ss://{decoded}#{parsed.fragment}")

    credentials = unquote(parsed.netloc.rsplit("@", 1)[0])
    if ":" not in credentials:
        credentials = base64.urlsafe_b64decode(
            credentials + "=" * (-len(credentials) % 4)
        ).decode()
    method, password = credentials.split(":", 1)
    server = parsed.hostname
    port = parsed.port
    if not server or not port or server in {"127.0.0.1", "localhost"}:
        return None

    outbound = {
        "type": "shadowsocks",
        "tag": unique_tag(unquote(parsed.fragment), seen),
        "server": server,
        "server_port": port,
        "method": method,
        "password": password,
    }
    plugin = first(parse_qs(parsed.query), "plugin")
    if plugin:
        outbound["plugin"], _, outbound["plugin_opts"] = plugin.partition(";")
    return outbound


def convert_shadowtls(outbound, seen):
    options = dict(
        option.split("=", 1)
        for option in outbound.pop("plugin_opts").split(";")
        if "=" in option
    )
    outbound.pop("plugin")
    tag = unique_tag(f"{outbound['tag']} ShadowTLS", seen)
    outbound["detour"] = tag
    # ShadowTLS carries TCP; this subscription does not advertise UDP over TCP.
    outbound["network"] = "tcp"
    return {
        "type": "shadowtls",
        "tag": tag,
        "server": outbound["server"],
        "server_port": outbound["server_port"],
        "version": int(options.get("version", "1")),
        "password": options.get("password", ""),
        "tls": {
            "enabled": True,
            "server_name": options.get("host") or outbound["server"],
            "utls": {"enabled": True, "fingerprint": "chrome"},
        },
    }


def parse_links(subscription):
    seen = set()
    outbounds = []
    if re.search(r"^proxies:", subscription, re.MULTILINE):
        for node in yaml.safe_load(subscription)["proxies"]:
            if node["type"] == "hysteria2":
                outbound = {
                    "type": "hysteria2",
                    "tag": unique_tag(node["name"], seen),
                    "server": node["server"],
                    "server_port": int(node["port"]),
                    "password": str(node["password"]),
                    "tls": {
                        "enabled": True,
                        "server_name": node.get("sni") or node["server"],
                        "insecure": bool(node.get("skip-cert-verify", False)),
                    },
                }
                if node.get("alpn"):
                    outbound["tls"]["alpn"] = node["alpn"]
                if node.get("obfs"):
                    outbound["obfs"] = {
                        "type": node["obfs"],
                        "password": node.get("obfs-password", ""),
                    }
                if node.get("ports"):
                    outbound.pop("server_port")
                    outbound["server_ports"] = [
                        port.strip().replace("-", ":")
                        for port in str(node["ports"]).split(",")
                    ]
                outbounds.append(outbound)
                continue
            if node["type"] != "vless":
                raise SystemExit(f"Unsupported Clash node type: {node['type']}")
            reality = node.get("reality-opts", {})
            ws = node.get("ws-opts", {})
            query = {
                "security": "reality" if reality else "tls" if node.get("tls") else "none",
                "sni": node.get("servername", ""),
                "insecure": "1" if node.get("skip-cert-verify") else "0",
                "fp": node.get("client-fingerprint", ""),
                "flow": node.get("flow", ""),
                "pbk": reality.get("public-key", ""),
                "sid": reality.get("short-id", ""),
                "type": node.get("network", "tcp"),
                "path": ws.get("path", "/"),
                "host": ws.get("headers", {}).get("Host", ""),
            }
            if query["type"] not in {"tcp", "ws"}:
                raise SystemExit(f"Unsupported Clash VLESS network: {query['type']}")
            server = node["server"]
            if ":" in server:
                server = f"[{server}]"
            link = (f"vless://{quote(str(node['uuid']), safe='')}@{server}:{node['port']}"
                    f"?{urlencode(query)}#{quote(node['name'])}")
            outbound = parse_vless(link, seen)
            if outbound:
                if node.get("alpn") and "tls" in outbound:
                    outbound["tls"]["alpn"] = node["alpn"]
                outbounds.append(outbound)
        return outbounds
    for raw in subscription.splitlines():
        link = raw.strip()
        if not link:
            continue
        if link.startswith("vless://"):
            outbound = parse_vless(link, seen)
        elif link.startswith(("hysteria2://", "hy2://")):
            outbound = parse_hysteria2(link, seen)
        elif link.startswith("ss://"):
            outbound = parse_shadowsocks(link, seen)
        else:
            continue
        if outbound:
            outbounds.append(outbound)
    return outbounds


def load_extra_config(path):
    config = json.loads(path.read_text())
    outbounds = []
    default = None

    if isinstance(config, list):
        candidates = config
    elif isinstance(config, dict):
        candidates = config.get("outbounds", [])
        route = config.get("route", {})
        if isinstance(route, dict):
            default = route.get("final")
        default = config.get("default", default)
    else:
        raise SystemExit(f"Unsupported extra config in {path}")

    for outbound in candidates:
        if not isinstance(outbound, dict):
            continue
        tag = outbound.get("tag")
        if tag in {"direct", "proxy"}:
            continue
        outbounds.append(outbound)

    if not outbounds:
        raise SystemExit(f"No extra remote nodes found in {path}")

    tags = {outbound.get("tag") for outbound in outbounds}
    if default not in tags:
        default = outbounds[0].get("tag")

    return outbounds, default


def main():
    parser = argparse.ArgumentParser(
        description="Import VLESS/Hysteria2/Shadowsocks subscription links into sing-box.json."
    )
    parser.add_argument(
        "--url",
        help="Download subscription content from this URL instead of reading stdin.",
    )
    parser.add_argument(
        "--url-file",
        help="Read subscription URLs from this file, one per line, and download them.",
    )
    parser.add_argument(
        "--base-config",
        default=CONFIG,
        type=Path,
        help="Base sing-box JSON config to extend.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write generated sing-box JSON config to this path. Defaults to stdout.",
    )
    parser.add_argument(
        "--extra-config-file",
        action="append",
        default=[],
        type=Path,
        help="Read additional sing-box outbounds from an encrypted JSON fragment.",
    )
    args = parser.parse_args()

    imported = []
    detours = []
    if args.url or args.url_file or not args.extra_config_file:
        seen = {"proxy", "direct"}
        for icon, content in read_subscription(args):
            try:
                parsed = parse_links(decode_subscription(content))
            except (Exception, SystemExit) as exc:
                print(f"Failed to parse subscription {icon}: {exc}", file=sys.stderr)
                continue
            for outbound in parsed:
                tag = f"{icon} {outbound['tag']}" if icon else outbound["tag"]
                outbound["tag"] = unique_tag(tag, seen)
                if outbound.get("plugin") == "shadow-tls":
                    detours.append(convert_shadowtls(outbound, seen))
                imported.append(outbound)

    extra_default = None
    for extra_config_file in args.extra_config_file:
        extra_outbounds, extra_default = load_extra_config(extra_config_file)
        imported.extend(extra_outbounds)

    if not imported:
        raise SystemExit("No supported remote nodes found.")

    config = json.loads(args.base_config.read_text())
    preserved = [
        outbound
        for outbound in config.get("outbounds", [])
        if outbound.get("tag") in {"proxy", "direct"}
    ]
    proxy = next(outbound for outbound in preserved if outbound.get("tag") == "proxy")
    tags = [outbound["tag"] for outbound in imported]
    generated_outbounds = preserved + imported + detours

    used_tags = {outbound.get("tag") for outbound in generated_outbounds}
    urltest_tags = []
    for group_tag, prefix, keyword in URLTEST_GROUPS:
        group_members = [tag for tag in tags if tag.startswith(prefix) and keyword in tag]
        if not group_members:
            continue
        group_tag = unique_tag(group_tag, used_tags)
        generated_outbounds.append(
            {
                "type": "urltest",
                "tag": group_tag,
                "outbounds": group_members,
                "url": URLTEST_URL,
                "interval": "15s",
                "tolerance": 50,
            }
        )
        urltest_tags.append(group_tag)
    proxy["outbounds"] = urltest_tags + tags + ["direct"]

    proxy["default"] = (
        "日本 URLTest" if "日本 URLTest" in urltest_tags
        else extra_default if extra_default in tags else tags[0]
    )

    final_outbound = "proxy"
    route = config.setdefault("route", {})
    route["final"] = final_outbound
    for rule in route.get("rules", []):
        outbound = rule.get("outbound")
        if outbound and outbound not in used_tags:
            rule["outbound"] = final_outbound

    generated = json.dumps(config | {"outbounds": generated_outbounds}, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(generated + "\n")
        print(f"Imported {len(imported)} nodes into {args.output}")
    else:
        print(generated)


if __name__ == "__main__":
    main()
