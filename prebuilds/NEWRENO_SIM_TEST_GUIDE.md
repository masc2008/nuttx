# NewReno SIM Test Guide

This guide runs the `Documentation/reference/os/newreno.rst` style test using
the patched `sim:tcpblaster` setup.

## Host Setup

Start from a clean run.

1. Create bridge and shaping first:

```bash
cd ~/nuttx/nuttx
sudo ./prebuilds/setup-newreno-sim-net.sh --bridge-only
```

2. Start SIM 1 in terminal A:

```bash
cd ~/nuttx/nuttx
./prebuilds/run-sim-tcpblaster.sh
```

3. Start SIM 2 in terminal B:

```bash
cd ~/nuttx/nuttx
./prebuilds/run-sim-tcpblaster.sh
```

4. After both SIMs are up, attach TAPs and refresh shaping:

```bash
cd ~/nuttx/nuttx
sudo ./prebuilds/setup-newreno-sim-net.sh
```

5. Verify host network:

```bash
ip addr show nuttx0
ip link show | grep tap
bridge link
ss -ltn | grep -E ':10003|:10004'
```

6. Start host server 1 in terminal C:

```bash
iperf -s -B 10.0.1.1 -i 1 -p 10003
```

7. Start host server 2 in terminal D:

```bash
iperf -s -B 10.0.1.1 -i 1 -p 10004
```

8. Optional host capture in terminal E:

```bash
sudo tcpdump -ni nuttx0 'tcp port 10003 or tcp port 10004'
```

## SIM 1

Paste in terminal A:

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.3
ifconfig
ping 10.0.1.1
```

Then start client:

```bash
iperf3 -c 10.0.1.1 -B 10.0.1.3 -i 1 -t 60 -p 10003
```

## SIM 2

Paste in terminal B:

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.4
ifconfig
ping 10.0.1.1
```

Then start client:

```bash
iperf3 -c 10.0.1.1 -B 10.0.1.4 -i 1 -t 60 -p 10004
```

## Important Notes

- Host uses `iperf`, not `iperf3`
- NuttX uses the command named `iperf3`
- SIM 1 must use `10.0.1.3` and port `10003`
- SIM 2 must use `10.0.1.4` and port `10004`

## Save Results

Save these outputs:

- SIM 1 client output
- SIM 2 client output
- host server 1 output
- host server 2 output

## If Something Fails

From the failing SIM:

```bash
ifconfig
arp
```

From the host:

```bash
ss -ltn | grep -E ':10003|:10004'
```
