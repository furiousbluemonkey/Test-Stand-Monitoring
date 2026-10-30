# Pressure and Nitrogen Level Logger

Alessandro Bruschi - October 2026

alessandro.bruschi@physics.ox.ac.uk

## Overview

This code base supports the monitoring of pressure and nitrogen level within a cryogenic container by measuring temperature at three different levels. It was designed to monitor a cryogenic container at the University of Oxford within the DarkSide-20k experiment.

Pressure is measured via an MKS 910 DualTrans Transducer and an MKS Series 900 Controller. The controller is queried with specific lines to prompt pressure readout, with both the MicroPirani and Piezo sensors, as well as a combination of the two. <br>
Temperature is measured via three PT1000 sensors, whose resistance-temperature relationship is governed by the Callendar-Van Dusen equation, approximated with the Newton-Raphson method. Their resistance is measured through a Teensy 4.1. The three PT1000 are placed at different heights within the container; their temperature is 77K when within liquid and gradually higher with height when in gas.

The data is printed to screen and saved in .csv files (pressure.csv and temperature.csv) within a folder called `TestStand_logger` on the user's disk. <br>
For real-time monitoring, these files are uploaded to local web servers (127.0.0.1:8000/pressure.csv and 127.0.0.1:8001/temperature.csv respectively).

The data can be viewed and graphed in real-time via Grafana, a visualization suite. The necessary dashboard and panels to view the data from the web server are included in the repository. <br>
To use it, simply navigate to Grafana on any browser and choose the ` Logger ` dashboard. The amount of time graphed can be chosen at the top, as well as the refresh rate to check for new data points.

The Pressure panel lists the MicroPirani, Piezo and combination measurements as PR1 (red), PR2 (yellow), and PR3 (orange) respectively. At pressures far from vacuum, as in our case, the MicroPirani sensor is quite inaccurate (the combined value usually just matches the Piezo measurement); it was decided to keep it nonetheless. <br>
The Temperature panel also lists the three PT1000 resistances as T1 (red), T2 (yellow), and T3 (orange); they are ordered from deepest to shallowest in the stand ** *actually do this on setup* **.

## Prerequisites


### Serial

pySerial must be installed to read and communicate with the two sensors. Once python is installed (virtual environment if needed) simply run ` pip install pyserial `.

### Connecting Teensy and MKS Controller

Plug in both, then find the correct ports.

#### Linux
To see a list of plugged in devices run ` ls /dev/tty* `; they will be listed in plug-in order (e.g. /dev/ttyACM0). <br>
If you want a specific path, independent of plug-in order, run ` s /dev/serial/by-id/ ` and use that serial id (e.g. /dev/serial/by-id/usb-Teensyduino_USB_Serial_12345670-if00).

#### macOS
To see a list of plugged in devices run `  ls /dev/cu.* `. The two sensors should be distinguishable by type (e.g. teensy /dev/cu.usbmodem165136901 and MKS /dev/cu.usbserial-14210) 

#### Windows
Navigate to Device Manager > Ports (COM & LPT) and two will be listed (e.g. COM3 and COM6)

### Grafana
The structure of the visual graphing is in ` dashboards/logger.json `, taking data from the local web servers chosen in ` logger/logger.py `.
To use Grafana it must be installed, along with the Infinity plugin, and then configured so it can read its instructions (` grafana/provisioning `). This process has been streamlined with custom made scripts (`grafana/setup`) for each OS, to make sure Grafana has the correct path to read the necessary files. This method has not been tested with other Grafana projects open, name/UID conflicts may arise.  <br>
Grafana is used through the local webserver on port 3000, which must be free (necessary condition to use the setup scrips).

#### Linux
After cloning the repository and navigating to it, run:
```bash
bash grafana/setup/setup-linux.sh
```
If using `sudo` requires a password, input it.

To check successful installation:
```bash
sudo systemctl status grafana-server
```
which should return ` active(running)`.

Visit [Grafana](http://localhost:3000/d/adkpsps) to view the graphs. On first installation, sign in with the default `admin`/`admin` credentials and change the password when prompted.

#### macOS
After cloning the repository and navigating to it, run:
```bash
bash grafana/setup/setup-macos.sh
```
It works for both Apple Silicon and Intel.  <br>
Then open a new terminal window and run `grafana-start`; it might take a few moments to start up. The terminal window must be kept running for Grafana to work. Close out of it to close out of Grafana.

Visit [Grafana](http://localhost:3000/d/adkpsps) to view the graphs. On first installation, sign in with the default `admin`/`admin` credentials and change the password when prompted.

#### Windows
Download the official [Grafana Windows](https://grafana.com/grafana/download?edition=oss&platform=windows) version and extract to a directory such as `C:\Grafana`. Make sure `\bin\grafana.exe` and `\conf` exist.

Open PowerShell and clone the repository, navigate to it, and run (open PowerShell as an administrator if needed):
```bash
powershell -ExecutionPolicy Bypass -File .\grafana\setup\setup-windows.ps1 -GrafanaHome `C:\Grafana`
```
Alter `C:\Grafana` with your local path if a different extraction directory is used. The command is run in a child PowerShell to not alter the overall PowerShell execution policy.

Then, as per the onscreen instructions, run:
```bash
Set-Location `C:\Grafana`
 .\bin\grafana.exe server --homepath .
```

Visit [Grafana](http://localhost:3000/d/adkpsps) to view the graphs. On first installation, sign in with the default `admin`/`admin` credentials and change the password when prompted.

## Configuration

To ensure functioning, one must write the correct ports in which the Teensy and MKS Controller are plugged in trough ` logger.py `. <br>
The port names have to be written here:
```python
PORT_TEENSY = "/dev/cu.usbmodem165136901" # teensy port
PORT_TRANS = "/dev/cu.usbserial-14210" #mks trans (controller) port
```
In the example they are shown as macOS ports; simply replace the path.

The only readily configurable setting is the measurement interval, and it is controlled through ` logger.py `. <br>
The setting is in seconds:
```python
INTERVAL = 60
```

It is possible to output other values than temperature through the Teensy 4.1 and the PT100, as explained in the following section.

### Teensy

Teensy 4.1 stores its script (` temperature_query.ino `) in memory and starts running it once it receives power. It can be unplugged anytime without problem. <br>
If one needs to alter its functioning, as per the cases below, the modified script must be reuploaded to the Teensy through Arduino IDE.

#### Resistances
It is assumed the three fixed resistors in the voltage dividers are equal and of (nominal) value `500 Ω`. In case, their value can be modified (a measured value gives a higher precision PT100 resistance value) in:
```cpp
 const float R_REF[3] = {500.0, 500.0, 500.0}; 
 ```
They correspond, respectively, to pins A0(14), A1(15), A2(16) on the Teensy 4.1. In any case, the circuitry is set inside the "Temperature Reader" box ** *actually label it* **.

It is also assumed that the PT1000 have Callendar-Van Dusen coefficients corresponding to the IEC 60751 Standard (mainly that at 0°C the resistance is 1kΩ). If that is not the case and they need to be altered, one can do so in:
```cpp
//PT1000 resistance to temperature conversion (Callendar-Van Dusen equation)
const double R0 = 1000.0;          
const double A = 3.9083e-3;
const double B = -5.775e-7;
const double C = -4.183e-12;
```

#### Queries
Four queries are accepted by the Teensy 4.1:
* ` READ\n`: outputs the computed temperature for the three PT1000. It is the only one used in ` logger.py `.
*  `READ_RESISTANCE\n`: outputs the resistance of the three PT1000. 
* ` READ_VOLTAGE\n`: outputs the voltage leaving each of the three voltage dividers.
* ` ID?\n `: prints out `Teensy PT1000 reader` as a sanity check one is talking to the right port.
Otherwise an `ERR: unknown command` error is thrown out.

One can modify `logger.py` to output resistance or voltage instead of the computed temperature, simply by replacing the `READ\n`command with one from the selection above:
```python
def query_temp(ser):
    ser.reset_input_buffer() #clear buffer
    ser.write(b"READ\n")
    reply = ser.readline().decode("ascii", errors="replace").strip()
    T1, T2, T3 = map(float, reply.split(","))
    return T1, T2, T3
```

## Output Structure

### To Screen
Each measurement is printed to screen as two lines (one for temperature, one for pressure). Each line shows the time and the three measured values, as explained in the Overview section. For easier reading, the pressure values are in brackets, while temperatures are not. <br>
For example:
```bash
12:21:54 296.4 296.8 295.5
12:21:55 [1200.0, 1018.0, 1018.0]
```
The temperatures are clearly in Kelvin; their small deviations are due to using the same values for the Callendar-Van Dusen coefficients for all three PT1000. <br>
The first pressure value is given by the MicroPirani sensor and is clearly not correct around and above atmospheric pressure, as explained in the Overview section, therefore the third value, which should be the combined one, is essentially equal to the Piezo-meaured pressure.

### CSV files
Two .csv files (pressure.csv and temperature.csv) are created to store data points, placed within a folder (~/TestStand_logger, operating system-independent). <br>
Each measurement is stored as Date-Time(UTC)-Measurements. <br>
For example:
 ` 2026-10-22T09:43:03.436306+00:00, 1200.0, 1018.0, 1018.0`

### Grafana
On a browser, navigate to `localhost:3000/d/adkpsps` which should open Grafana to the correct dashboard, displaying the Pressure and Temperature panels. Make sure you have started running ` logger.py ` with both sensors plugged in. The amount of time graphed can be selected on the top. Refresh to see new data points, or set an automatic refresh rate. <br>
For any other information, refer to the previous parts of this README.

## Troubleshooting

### MKS Controller Not Responding
If the MKS Controller is not responding, navigate within its interface to ` Setup > Communication ` and then manually reset ` Controller Adress ` to 253, `Controller Baud rate` to 9600 and ` Interface ` to RS232, even if those values are already set. It should now work.

### Permission Error/Port Occupied
Make sure no other program is occupying or reading the port (e.g. PuTTy or Arduino IDE). Close out of them.

### No Data Displayed on Grafana
Make sure `logger.py` is running.  <br>
By navigating to `http://127.0.0.1:8000/pressure.csv` and `http://127.0.0.1:8001/temperature.csv` the respective CSV files should be downloaded, with all data points up to that moment. 

#### Windows
If all the above applied, check in `Connections > Datasources` that Infinity is correctly installed and running; do the same in `Plugins` and in case manually re-install it. If after refreshing the window the graphs still display `No Data`, enter edit mode and make sure each panel has its `Datasource` set as `yesoreyeram-infinity-datasource`and not as the native Grafana one. 