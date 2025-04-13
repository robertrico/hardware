import ssd1306
import time
from machine import Pin, I2C
# Setup I2C + OLED
i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=400000)
oled = ssd1306.SSD1306_I2C(128, 64, i2c)
button = Pin(0, Pin.IN, Pin.PULL_UP)

def start():
    try:
        import secrets
        import network
        import time

        oled.fill(0)
        oled.text("Initializing...", 0, 0)
        oled.show()

        # Wi-Fi
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        wlan.connect(secrets.WIFI_SSID, secrets.WIFI_PASSWORD)

        for _ in range(20):
            if wlan.isconnected():
                oled.fill(0)
                oled.text("Wi-Fi Connected!", 0, 0)
                # Show IP address
                ip = wlan.ifconfig()[0]
                oled.text("IP:", 0, 16)
                oled.text(ip, 0, 26)
                # Show network name
                ssid = wlan.config('essid')
                oled.text("SSID:", 0, 42)
                oled.text(ssid, 0, 52)
                oled.show()
                return
            time.sleep(0.5)

        oled.text("Wi-Fi Fail!", 0, 0)
        oled.show()

    except Exception as e:
        import sys
        sys.print_exception(e)

def simple_http_get(url=b"http://httpbin.org/json", use_stream=False):
    import socket

    proto, _, host, path = url.split(b"/", 3)
    assert proto == b"http:"

    print("Resolving", host)
    ai = socket.getaddrinfo(host, 80)[0]
    addr = ai[-1]

    print("Connecting to", addr)
    s = socket.socket()
    s.connect(addr)

    request = b"GET /%s HTTP/1.0\r\nHost: %s\r\n\r\n" % (path, host)
    if use_stream:
        s = s.makefile("rwb", 0)
        s.write(request)
        print(s.read())
    else:
        s.send(request)
        response = s.recv(4096)
        print(response.decode())

    s.close()

def note():
    import socket
    import ujson
    from time import sleep

    print("Starting note()")
    url = b"http://3.19.70.134:8081/"
    proto, _, host, path = url.split(b"/", 3)
    assert proto == b"http:"
    host = host.split(b":")[0]

    print("Resolving host...")
    ai = socket.getaddrinfo(host, 8081)[0]
    addr = ai[-1]

    print("Connecting to server...")
    s = socket.socket()
    s.connect(addr)

    print("Sending GET request...")
    request = b"GET /%s HTTP/1.0\r\nHost: %s\r\n\r\n" % (path, host)
    s.send(request)

    print("Reading response...")
    response = b""
    while True:
        chunk = s.recv(512)
        if not chunk:
            break
        response += chunk

    s.close()
    print("Finished reading, parsing JSON...")

    try:
        header, body = response.split(b"\r\n\r\n", 1)
        data = ujson.loads(body)
        author = data["note"]
    except Exception as e:
        print("❌ Error parsing JSON:", e)
        author = "No Author"

    oled.fill(0)
    draw_wrapped_text(oled, author, 0, 6)
    print("Author:", repr(author))
    oled.show()
    print("Displayed on OLED")

def draw_wrapped_text(oled, text, x=0, y=0, max_width=128, line_height=10):
    if isinstance(text, bytes):
        text = text.decode()

    max_chars = max_width // 8
    lines = []

    for raw_line in text.splitlines():
        while raw_line:
            chunk = raw_line[:max_chars]
            if len(chunk) == max_chars and ' ' in chunk:
                space = chunk.rfind(' ')
                chunk = chunk[:space]
            lines.append(chunk)
            raw_line = raw_line[len(chunk):].lstrip()

        if not raw_line:
            lines.append("")

    for i, line in enumerate(lines):
        line = line.strip()
        line_px = len(line) * 8
        centered_x = (max_width - line_px) // 2 if line else x
        oled.text(line, centered_x, y + i * line_height)



def is_connected():
    import network
    return network.WLAN(network.STA_IF).isconnected()

def init():
    oled.fill(0)
    print("Button pressed! Refetching message...")
    start()
    time.sleep(2)
    note()

    try:
        while True:
            if button.value() == 0:
                print("Button pressed! Refetching message...")
                if is_connected():
                    note()
                else:
                    oled.fill(0)
                    oled.text("No Wi-Fi!", 0, 0)
                    oled.show()
                time.sleep(0.3)
    except KeyboardInterrupt:
        print("Exiting loop cleanly.")

if __name__ == "__main__":
    init()