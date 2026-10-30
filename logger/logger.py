import csv, os, time, datetime, threading, functools
import http.server, socketserver
import serial


PORT_TEENSY = "/dev/cu.usbmodem165136901" # teensy port
PORT_TRANS = "/dev/cu.usbserial-14210" #mks trans (controller) port
INTERVAL = 10
FOLDER = os.path.expanduser("~/TestStand_logger")
CSV_TEMP = os.path.join(FOLDER, "temperature.csv")
CSV_PRES = os.path.join(FOLDER, "pressure.csv")
os.makedirs(FOLDER, exist_ok=True)

#--- tiny file server, local only ---
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

handler = functools.partial(Quiet, directory=FOLDER)
socketserver.TCPServer.allow_reuse_address = True
httpd_temp = socketserver.TCPServer(("127.0.0.1", 8001), handler)
httpd_pres = socketserver.TCPServer(("127.0.0.1", 8000), handler)
threading.Thread(target=httpd_temp.serve_forever, daemon=True).start()
threading.Thread(target=httpd_pres.serve_forever, daemon=True).start()

#--- serial querying teensy (temp)---
def query_temp(ser):
    ser.reset_input_buffer() #clear buffer
    ser.write(b"READ\n")
    reply = ser.readline().decode("ascii", errors="replace").strip()
    T1, T2, T3 = map(float, reply.split(","))
    return T1, T2, T3

#--- serial querying mks controller/transducer(pres)---
def query_pres(ser, cmd, addr="253"):
    ser.reset_input_buffer()
    ser.write(f"@{addr}{cmd}?;FF".encode("ascii"))
    reply = ser.read_until(b";FF").decode("ascii", errors="replace")
    if "ACK" not in reply:
        raise IOError(f"bad reply {reply!r}")
    return float(reply.split("ACK", 1)[1].replace(";FF", ""))


while True:
    t0 = time.time()
    try: #teensy communication
        with serial.Serial(PORT_TEENSY, 115200, timeout=2) as ser:
            T1, T2, T3 = query_temp(ser)
        new = not os.path.exists(CSV_TEMP)
        with open(CSV_TEMP, "a", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["Time", "T1", "T2", "T3"])
            w.writerow([datetime.datetime.now(datetime.timezone.utc).isoformat(), T1, T2, T3])
        print(datetime.datetime.now().strftime("%H:%M:%S"), T1, T2, T3)
    except (serial.SerialException, ValueError) as e:
        print("read serial:", e) # e.g. cable unplugged
    try: #mks communication
        with serial.Serial(PORT_TRANS, 9600, bytesize=8, parity="N",
                            stopbits=1, timeout=1) as ser:
            vals = [query_pres(ser, c) for c in ("PR1", "PR2", "PR3")]
        new = not os.path.exists(CSV_PRES)
        with open(CSV_PRES, "a", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["Time", "PR1", "PR2", "PR3"])
            w.writerow([datetime.datetime.now(datetime.timezone.utc).isoformat()] + vals)
        print(datetime.datetime.now().strftime("%H:%M:%S"), vals)
    except (serial.SerialException, IOError, ValueError) as e:
        print("read failed:", e) # skip this row, leaves a gap
   
    time.sleep(max(0, INTERVAL - (time.time() - t0))) #then retry