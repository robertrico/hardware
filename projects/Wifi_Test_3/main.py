import ssd1306
import time
from machine import Pin, I2C
# Setup I2C + OLED
i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=400000)
oled = ssd1306.SSD1306_I2C(128, 64, i2c)

def start():
    try:
        import secrets
        import network
        import time

        oled.fill(0)
        oled.text("Starting up!!!", 0, 0)
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

        oled.fill(0)
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

    url = b"http://3.19.70.134:8081/"
    proto, _, host, path = url.split(b"/", 3)
    assert proto == b"http:"
    host = host.split(b":")[0]

    # Resolve host
    ai = socket.getaddrinfo(host, 8081)[0]

    addr = ai[-1]

    # Connect to server
    s = socket.socket()
    s.connect(addr)

    # Send raw GET request
    request = b"GET /%s HTTP/1.0\r\nHost: %s\r\n\r\n" % (path, host)
    s.send(request)

    # Read full response
    response = b""
    while True:
        chunk = s.recv(512)
        if not chunk:
            break
        response += chunk

    s.close()

    # Parse HTTP response
    try:
        header, body = response.split(b"\r\n\r\n", 1)
        data = ujson.loads(body)
        author = data["note"]
    except Exception as e:
        print("❌ Error parsing JSON:", e)
        author = "No Author"

    # Display on OLED
    oled.fill(0)
    draw_wrapped_text(oled, author.encode(), 0, 0)

    oled.show()

def draw_wrapped_text(oled, text, x=0, y=0, max_width=128, line_height=10):
    max_chars = max_width // 8  # each char ~8px wide on 128x64 display

    lines = []
    while text:
        # Take up to max_chars
        chunk = text[:max_chars]
        # If it's not the whole string and doesn't end with space, backtrack to last space
        if len(chunk) == max_chars and b' ' in chunk:
            space = chunk.rfind(b' ')
            chunk = chunk[:space]
        lines.append(chunk)
        text = text[len(chunk):].lstrip()

    for i, line in enumerate(lines):
        oled.text(line.decode(), x, y + i * line_height)


def init():
    start()
    time.sleep(2)
    note()

if __name__ == "__main__":
    init()