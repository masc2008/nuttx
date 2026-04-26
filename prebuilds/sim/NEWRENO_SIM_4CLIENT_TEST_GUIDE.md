# NuttX SIM NewReno 4-Client Test Guide

This guide runs 4 NuttX `sim:tcpblaster` instances against one Linux host bridge with shaped bandwidth, using host-side `iperf` servers and NuttX-side `iperf3` commands.

## Host Setup

Stop old host `iperf` servers if needed:

```bash
bash ~/nuttx/nuttx/prebuilds/stop-iperf-servers.sh 4
```

Create bridge and shaping first:

```bash
cd ~/nuttx/nuttx
sudo ./prebuilds/setup-newreno-sim-net.sh --bridge-only
```

Start 4 SIMs in 4 terminals:

```bash
cd ~/nuttx/nuttx
./prebuilds/run-sim-tcpblaster.sh
```

After all 4 SIMs are up, attach TAPs:

```bash
cd ~/nuttx/nuttx
sudo ./prebuilds/setup-newreno-sim-net.sh tap0 tap1 tap2 tap3
```

Start 4 host `iperf` servers:

```bash
bash ~/nuttx/nuttx/prebuilds/start-iperf-servers.sh 4
```

Optional host checks:

```bash
ip addr show nuttx0
bridge link
ss -ltn | grep -E ':10003|:10004|:10005|:10006'
```

## SIM 1

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.3
ping 10.0.1.1
iperf3 -c 10.0.1.1 -B 10.0.1.3 -i 1 -t 600 -p 10003
```

## SIM 2

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.4
ping 10.0.1.1
iperf3 -c 10.0.1.1 -B 10.0.1.4 -i 1 -t 600 -p 10004
```

## SIM 3

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.5
ping 10.0.1.1
iperf3 -c 10.0.1.1 -B 10.0.1.5 -i 1 -t 600 -p 10005
```

## SIM 4

```bash
ifdown eth0
ifup eth0
ifconfig eth0 10.0.1.6
ping 10.0.1.1
iperf3 -c 10.0.1.1 -B 10.0.1.6 -i 1 -t 600 -p 10006
```

## Cleanup

Stop host servers after the run:

```bash
bash ~/nuttx/nuttx/prebuilds/stop-iperf-servers.sh 4
```

## Notes

- With 4 clients sharing the same shaped `10Mbit` bridge, per-client throughput will be lower than the 2-client case.
- Compare total throughput and stability, not the old per-client rate from the 2-client test.
- `setup-newreno-sim-net.sh --bridge-only` is safe to rerun. It refreshes bridge and shaping state but does not attach TAP devices.
- After SIMs are running, use `setup-newreno-sim-net.sh` without `--bridge-only` to attach TAP devices.
