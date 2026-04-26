Start two host servers in two terminals:

  iperf3 -s -i1 -p10003

  iperf3 -s -i1 -p10004

  On SIM 1 NSH:

  ifconfig eth0 10.0.1.3
  ping 10.0.1.1
  iperf3 -c 10.0.1.1 -i1 -t60 -p10003

  On SIM 2 NSH:

  ifconfig eth0 10.0.1.4
  ping 10.0.1.1
  iperf3 -c 10.0.1.1 -i1 -t60 -p10004

  That is the direct equivalent of newreno.rst.

  For A/B comparison:

  1. run this with current build where CONFIG_NET_TCP_CC_NEWRENO=y
  2. save the results
  3. disable CONFIG_NET_TCP_CC_NEWRENO
  4. rebuild
  5. run the same commands again

  Useful host checks before starting iperf3:

  ip addr show nuttx0
  bridge link
  tc qdisc show dev nuttx0
  tc qdisc show dev ifb0

  If you want, I can give you the exact menuconfig and rebuild steps for the NEWRENO=n comparison build next.

