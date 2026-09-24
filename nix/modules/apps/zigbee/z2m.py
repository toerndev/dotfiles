"""zigbee2mqtt over MQTT: device registry, state cache, commands. No policy.

paho delivers messages on its own network thread; they only go into a queue
here. poll() drains that queue on the caller's thread, updates the cache and
returns Events -- so everything above this layer is single-threaded.
"""
import json, logging, queue, time, uuid
from dataclasses import dataclass, field

import paho.mqtt.client as mqtt

log = logging.getLogger("z2m")


@dataclass(frozen=True)
class Device:
    name: str
    ieee: str
    type: str                  # Router, EndDevice, ...
    model: str
    vendor: str
    description: str
    interviewed: bool
    color_temp: tuple | None   # (min, max) mireds, None if not a CCT light
    brightness: bool
    occupancy: bool


@dataclass(frozen=True)
class Event:
    kind: str                  # bridge | devices | announce | joined | interview |
                               # response | availability | state
    name: str = ""
    data: dict = field(default_factory=dict)
    prev: object = None        # availability: previous bool; state: previous dict


def _features(exposes):
    for e in exposes or []:
        yield e
        yield from _features(e.get("features"))


def _device(d):
    definition = d.get("definition") or {}
    feats = {f.get("name"): f for f in _features(definition.get("exposes"))}
    ct = feats.get("color_temp")
    return Device(
        name=d["friendly_name"], ieee=d["ieee_address"], type=d.get("type", ""),
        model=definition.get("model") or d.get("model_id") or "",
        vendor=definition.get("vendor") or d.get("manufacturer") or "",
        description=definition.get("description", ""),
        interviewed=d.get("interview_state", "SUCCESSFUL") == "SUCCESSFUL",
        color_temp=(ct["value_min"], ct["value_max"]) if ct and "value_min" in ct else None,
        brightness="brightness" in feats, occupancy="occupancy" in feats)


class Z2M:
    def __init__(self, host="127.0.0.1", port=1883, base="zigbee2mqtt",
                 client_id=None, dry_run=False):
        self.host, self.port, self.base, self.dry_run = host, port, base, dry_run
        self.devices = {}      # name -> Device
        self.state = {}        # name -> merged last payload
        self.online = {}       # name -> bool, from availability
        self.received = 0      # messages handled, event-producing or not
        self.info = None       # bridge/info: coordinator, network, config
        self.bridge_online = None
        self._inbox = queue.Queue()
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                                  client_id=client_id or f"lamps-{uuid.uuid4().hex[:6]}")
        self.client.on_connect = self._on_connect
        self.client.on_message = lambda c, u, m: self._inbox.put((m.topic, m.payload))
        self.client.reconnect_delay_set(1, 30)

    def connect(self):
        self.client.connect(self.host, self.port, keepalive=60)
        self.client.loop_start()

    def close(self):
        self.client.loop_stop()
        self.client.disconnect()

    def _on_connect(self, client, userdata, flags, reason_code, properties):
        if reason_code.is_failure:
            log.error("MQTT connect failed: %s", reason_code)
            return
        log.info("connected to MQTT at %s:%s", self.host, self.port)
        client.subscribe(f"{self.base}/#", qos=1)

    # -- inbound ---------------------------------------------------------
    def poll(self, timeout):
        """Wait up to `timeout` s for traffic; return the Events it caused."""
        events = []
        try:
            item = self._inbox.get(timeout=max(0.0, timeout))
        except queue.Empty:
            return events
        while True:
            events += self._handle(*item)
            try:
                item = self._inbox.get_nowait()
            except queue.Empty:
                return events

    def _handle(self, topic, payload):
        self.received += 1
        if not topic.startswith(self.base + "/"):
            return []
        sub = topic[len(self.base) + 1:]
        try:
            data = json.loads(payload) if payload else {}
        except (json.JSONDecodeError, UnicodeDecodeError):
            data = payload.decode(errors="replace")

        if sub == "bridge/state":
            state = data.get("state") if isinstance(data, dict) else data
            self.bridge_online = state == "online"
            return [Event("bridge", data={"online": self.bridge_online})]
        if sub == "bridge/info" and isinstance(data, dict):
            self.info = data
            return []
        if sub == "bridge/devices":
            self.devices = {d["friendly_name"]: _device(d) for d in data
                            if d.get("type") != "Coordinator"}
            return [Event("devices")]
        if sub == "bridge/event" and isinstance(data, dict):
            d = data.get("data", {})
            kind = {"device_announce": "announce", "device_joined": "joined",
                    "device_interview": "interview"}.get(data.get("type"))
            return [Event(kind, d.get("friendly_name", ""), d)] if kind else []
        if sub.startswith("bridge/response/"):
            return [Event("response", sub[len("bridge/response/"):], data)]
        if sub.startswith("bridge/"):
            return []
        if sub.endswith("/availability"):
            name = sub[:-len("/availability")]
            up = (data.get("state") if isinstance(data, dict) else data) == "online"
            prev, self.online[name] = self.online.get(name), up
            return [Event("availability", name, {"online": up}, prev)]
        if sub.endswith(("/set", "/get")) or "/set/" in sub or not isinstance(data, dict):
            return []
        prev = self.state.get(sub, {})
        self.state[sub] = {**prev, **data}
        return [Event("state", sub, data, prev)]

    def is_on(self, name):
        """ON per z2m, and not known to be offline (mains cut -> stale ON)."""
        return (self.state.get(name, {}).get("state") == "ON"
                and self.online.get(name, True))

    # -- outbound --------------------------------------------------------
    def _publish(self, topic, payload):
        body = json.dumps(payload)
        if self.dry_run:
            log.info("(dry run) %s %s", topic, body)
            return
        self.client.publish(f"{self.base}/{topic}", body, qos=1)

    def set(self, name, payload):
        log.info("%s <- %s", name, json.dumps(payload))
        self._publish(f"{name}/set", payload)

    def get(self, name, keys=("state",)):
        """Ask z2m to READ the device live; the answer arrives as a state Event."""
        self._publish(f"{name}/get", {k: "" for k in keys})

    def request(self, path, payload, timeout=15):
        """Bridge request/response. Swallows other Events -- for tools, not the engine."""
        tid = uuid.uuid4().hex[:8]
        self._publish(f"bridge/request/{path}", {**payload, "transaction": tid})
        deadline = time.monotonic() + timeout
        while (left := deadline - time.monotonic()) > 0:
            for ev in self.poll(left):
                if ev.kind == "response" and ev.name == path and ev.data.get("transaction") == tid:
                    return ev.data
        raise TimeoutError(f"no response to bridge/request/{path}")
