import ssd1306
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

def display_json_author():
    import socket
    import ujson
    from time import sleep

    url = b"http://httpbin.org/json"
    proto, _, host, path = url.split(b"/", 3)
    assert proto == b"http:"

    # Resolve host
    ai = socket.getaddrinfo(host, 80)[0]
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
        author = data["slideshow"]["author"]
    except Exception as e:
        print("❌ Error parsing JSON:", e)
        author = "No Author"

    # Display on OLED
    oled.fill(0)
    oled.text("Author:", 0, 0)
    oled.text(author, 0, 16)
    oled.show()
