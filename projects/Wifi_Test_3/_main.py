def start():
    try:
        import secrets
        import network
        from machine import Pin, I2C
        import ssd1306
        import time

        # Setup I2C + OLED
        i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=400000)
        oled = ssd1306.SSD1306_I2C(128, 64, i2c)

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
            time.sleep(0.5main.py)

        oled.fill(0)
        oled.text("Wi-Fi Fail!", 0, 0)
        oled.show()

    except Exception as e:
        import sys
        sys.print_exception(e)
