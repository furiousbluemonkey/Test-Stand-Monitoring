# Pressure and Nitrogen Level Logger

Alessandro Bruschi - October 2026

alessandro.bruschi@physics.ox.ac.uk

## Overview

This code base supports the monitoring of pressure and nitrogen level within a cryogenic container by measuring temperature at three different levels. It was designed to monitor a cryogenic container at the University of Oxford within the DarkSide-20k experiment.

Pressure is measured via an MKS 910 DualTrans Transducer and an MKS Series 900 Controller. The controller is queried with specific lines to prompt pressure readout (with both the MicroPirani and Piezo sensors, as well as a combination of the two).
Temperature is measured via three PT1000 sensors, whose resistance-temperature relationship is governed by the Callendar-Van Dusen equation, approximated with the Newton-Raphson method. Their resistance is measured through a Teensy 4.1. The three PT1000 are placed at different heights within the container; their temperature is 77K when within liquid and gradually higher with height when in gas.

The data is printed to screen and saved in .csv files (pressure.csv and temperature.csv) within a folder called `TestStand_logger` on the user`s disk.
For real-time monitoring, these files are uploaded to local web servers (127.0.0.1:8000/pressure.csv and 127.0.0.1:8001/temperature.csv respectively).

The data can be viewed and graphed in real-time via Grafana, a visualization suite. The necessary dashboard and panels to view the data from the web server are included in the repository.
To use it, simply navigate to Grafana on any browser and choose the ` Logger ` dashboard. The amount of time graphed can be chosen at the top.

## Prerequisites


### Serial

pySerial must be installed to read and communicate with the two sensors. Once python is installed (virtual environment if needed) simply run ` pip install pyserial `.

### Connecting Teensy and MKS Controller

Plug in both, then find the correct ports.

#### Linux
To see a list of plugged in devices run ` ls /dev/tty* `; they will be listed in plug-in order (e.g. /dev/ttyACM0).
If you want a specific path, independent of plug-in order, run ` s /dev/serial/by-id/ ` and use that serial id (e.g. /dev/serial/by-id/usb-Teensyduino_USB_Serial_12345670-if00).

#### macOS
To see a list of plugged in devices run `  ls /dev/cu.* `. The two sensors should be distinguishable by type (e.g. teensy /dev/cu.usbmodem165136901 and MKS /dev/cu.usbserial-14210) 

#### Windows
Navigate to Device Manager > Ports (COM & LPT) and two will be listed (e.g. COM3 and COM6)

### Grafana
The structure of the visual graphing is in ` dashboards/logger.json `, taking data from the local web servers chosen in ` logger/logger.py `.
To use Grafana it must be installed, along with the Infinity plugin, and then configured so it can read its instructions (` grafana/provisioning `). This process has been streamlined with custom made scripts (`grafana/setup`) for each OS, to make sure Grafana has the correct path to read the necessary files. This method has not been tested with other Grafana projects open, name/UID conflicts may arise. 
Grafana is used through the local webserver on port 3000, which must be free (needed condition to use the setup scrips).

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
It works for both Apple Silicon and Intel. 
Then open a new terminal window and run `grafana-start`. The terminal window must be kept running for Grafana to work. Close out of it to close out of Grafana.

Visit [Grafana](http://localhost:3000/d/adkpsps) to view the graphs. On first installation, sign in with the default `admin`/`admin` credentials and change the password when prompted.

#### Windows
Download the official [Grafana Windows](https://grafana.com/grafana/download?edition=oss&platform=windows) version and extract to a directory such as `C:\Grafana`. Make sure `\bin\grafana.exe` and `\conf` exist.

Open PowerShell and clone the repository, navigate to it, and run:
```bash
powershell -ExecutionPolicy Bypass -File .\grafana\setup\setup-windows.ps1 -GrafanaHome `C:\Grafana`
```
Alter `C:\Grafana` if a different extraction directory is used. The command is run in a child PowerShell to not alter the overall PowerShell execution policy.

In a different terminal run:
```bash
Set-Location `C:\Grafana`
 .\bin\grafana.exe server --homepath .
```
This terminal needs to be open while running Grafana. If that is not possible, a manual Grafana installation and setup is needed.

Visit [Grafana](http://localhost:3000/d/adkpsps) to view the graphs. On first installation, sign in with the default `admin`/`admin` credentials and change the password when prompted.

## Configuration

To ensure functioning, one must write the correct ports in which the Teensy and MKS Controller are plugged in trough ` logger.py `.
The port names have to be written here:
```python
PORT_TEENSY = "/dev/cu.usbmodem165136901" # teensy port
PORT_TRANS = "/dev/cu.usbserial-14210" #mks trans (controller) port
```
In the example they are shown as macOS ports; simply replace the path.

The only readily configurable setting is the measurement interval, and it is controlled through ` logger.py `.
The setting is in seconds:
```python
INTERVAL = 60
```

### Teensy

Teensy 4.1 stores its script (` temperature_query.ino `) in memory and starts running it once it receives power. It can be unplugged anytime without problem.

#### Resistances
It is assumed the three fixed resistors in the voltage dividers are equal and of (nominal) value `500 Ohm`. In case, their value can be modified (a measured value gives a higher precision PT100 resistance value) in:
```cpp
 const float R_REF[3] = {500.0, 500.0, 500.0}; 
 ```
They correspond, respectivly, to pins A0(14), A1(15), A2(16) ob the Teensy 4.1

It is also assumed that the PT1000 have values corresponding to the IEC 60751 Standard (mainly that at 0°C the resistance is 1kOhm). If that is not the case, or the Callendar-Van Dusen coefficients need to be altered, one can do so in:
```cpp
//PT1000 resistance to temperature conversion (Callendar-Van Dusen equation)
const double R0 = 1000.0;          
const double A = 3.9083e-3;
const double B = -5.775e-7;
const double C = -4.183e-12;
```

#### Queries
Four queries are accepted:
* ` READ\n `: outputs the computed temperature for the three PT1000. It is the only one used in ` logger.py `.
*  READ_RESISTANCE\n `: outputs the resistance of the three PT1000. 
* ` READ_VOLTAGE\n `: outputs the voltage leaving each of the three voltage dividers.
* ` ID?\n `: prints out ` Teensy PT1000 reader ` as a sanity check one is talking to the right port.
Otherwise an ` ERR:unkown command ` error is thrown out.


## Output Structure

### To Screen
Each measurement is printed to screen as two lines (one for temperature, one for pressure). Each line shows the time and three measured values (either MicroPirani, Piezo, combined and the three PT1000 respectively). For easier reading, the pressure values are in brackets, the temperatures are not.
For example:
```bash
12:21:54 1107.5 1110.8 1109.5
12:21:55 [1200.0, 995.0, 995.0]
```

### CSV files
Two .csv files are created, along with a folder (~/TestStand_logger, operating system-independent).
Each measurement is stored as Date-Time(UTC)-Measurements. 
For example ` 2026-10-22T09:43:03.436306+00:00,1200.0,995.0,995.0 `

### Grafana
On a browser, navigate to `localhost:3000/d/adkpsps` which should open Grafana. Make sure you have started runing ` logger.py ` with both sensors plugged in, if on Windows, the correct PowerShell is also needed, see section Prerequisites > Grafana > Windows of this README. The page should open within Grafana to `Dashboards > Logger` and you should see the pressure and temperature data logged on two graphs. The time taken in consideration can be adjusted at the top. Refresh to see new data points.

## Troubleshooting

### MKS Controller Not Responding
If the MKS Controller is not responding, navigate within its interface to ` Setup > Communication ` and then manually reset ` Controller Adress ` to 253, `Controller Baud rate` to 9600 and ` Interface ` to RS232. It should now work.

### Port Occupied/Permission Error
Make sure no other program is occupying or reading the port (e.g. PuTTy or Arduino IDE). Close out of them.

### No Data Displayed on Grafana
Make sure `logger.py` is running. 
By navigating to `http://127.0.0.1:8000/pressure.csv` and `http://127.0.0.1:8001/temperature.csv` the relative CSV files should be downloaded, with all data points up to that moment. 

