import ssd1306
import time
from machine import Pin, I2C

# Setup I2C + OLED + Fetch button
i2c = I2C(1, scl=Pin(3), sda=Pin(2), freq=400000)
oled = ssd1306.SSD1306_I2C(128, 64, i2c)
button = Pin(0, Pin.IN, Pin.PULL_UP)

def start():
    """
    Initializes the OLED display and attempts to connect to a Wi-Fi network.

    This function performs the following steps:
    1. Clears the OLED display and shows an "Initializing..." message.
    2. Activates the Wi-Fi interface and connects to the network using credentials
       stored in the `secrets` module.
    3. Attempts to connect to the Wi-Fi network up to 20 times, with a 0.5-second
       delay between attempts.
    4. If the connection is successful:
       - Displays "Wi-Fi Connected!" on the OLED.
       - Shows the IP address and network SSID on the OLED.
    5. If the connection fails after 20 attempts:
       - Displays "Wi-Fi Fail!" on the OLED.
    6. Handles any exceptions that occur during the process and prints the
       exception details using `sys.print_exception`.

    Note:
        - The `secrets` module must contain `WIFI_SSID` and `WIFI_PASSWORD` variables.
        - The `oled` object must be initialized and support `fill`, `text`, and `show` methods.
        - The `network` module is used for Wi-Fi connectivity.

    Raises:
        Exception: If any error occurs during the initialization or Wi-Fi connection process.
    """
    # Initialize the OLED display
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

        # Try to connect to Wi-Fi 20 times
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


def note():
    """
    Fetches a note from a remote server, parses the JSON response, and displays the note
    on an OLED screen.

    The function performs the following steps:
    1. Resolves the host address of the server.
    2. Establishes a connection to the server.
    3. Sends an HTTP GET request to fetch the note.
    4. Reads the server's response and parses the JSON body.
    5. Extracts the "note" field from the JSON and displays it on the OLED screen.

    If an error occurs during JSON parsing, a default message "No Author" is displayed.

    Note:
        - The function assumes the presence of an `oled` object for display operations.
        - The `draw_wrapped_text` function is used to render text on the OLED screen.

    Raises:
        AssertionError: If the protocol in the URL is not HTTP.
        Exception: If there is an error during JSON parsing.

    Prints:
        Logs the progress and any errors encountered during execution.
    """
    import socket
    import ujson
    from time import sleep
    import secrets

    print("Starting note()")
    url = secrets.SERVER_URL.encode()
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
    """
    Draws text on an OLED display, wrapping it to fit within a specified width.

    This function takes a string or bytes object, splits it into lines, and wraps
    each line to fit within the `max_width` in pixels. It then renders the text
    on the OLED display, optionally centering each line horizontally.

    Args:
        oled: The OLED display object that provides a `text` method for rendering text.
        text (str or bytes): The text to be displayed. If bytes, it will be decoded to a string.
        x (int, optional): The x-coordinate of the starting position for the text. Defaults to 0.
        y (int, optional): The y-coordinate of the starting position for the text. Defaults to 0.
        max_width (int, optional): The maximum width in pixels for the text. Defaults to 128.
        line_height (int, optional): The height in pixels between lines of text. Defaults to 10.

    Returns:
        None
    """
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
    """
    Check if the device is connected to a Wi-Fi network.

    This function uses the `network` module to check the connection status
    of the device's Wi-Fi interface in station mode (STA_IF).

    Returns:
        bool: True if the device is connected to a Wi-Fi network, False otherwise.
    """
    import network
    return network.WLAN(network.STA_IF).isconnected()

def init():
    """
    Initializes the OLED display and handles button press events in a loop.

    This function performs the following tasks:
    - Clears the OLED display.
    - Prints a message indicating that the button was pressed and starts the process.
    - Calls the `start` function and waits for 2 seconds.
    - Calls the `note` function to perform a specific task.
    - Enters an infinite loop to monitor button presses:
        - If the button is pressed and the device is connected to Wi-Fi, it calls the `note` function.
        - If the device is not connected to Wi-Fi, it displays a "No Wi-Fi!" message on the OLED.
        - Adds a short delay to debounce the button press.
    - Handles a `KeyboardInterrupt` to exit the loop cleanly.

    Note:
    - This function assumes the existence of the `oled`, `button`, `is_connected`, `start`, and `note` objects or functions.
    - The `time` module is used for delays.
    """
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