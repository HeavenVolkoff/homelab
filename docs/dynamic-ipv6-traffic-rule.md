[Source](http://blog.dupondje.be/?p=17 "Permalink to Dynamic IPv6 Subnet & ip6tables")

# Dynamic IPv6 Subnet & ip6tables

Great! Native IPv6. Now all my computers/devices in my LAN have a public IP address!

So first of all think about security.
With IPv4 and NAT, all devices are not accessible directly because they have a private IP address.
Now with IPv6 all your devices receive a public IP address, and are available over the internet for everybody.

A good thing is that Tomato Toastman activates ip6tables for your whole LAN.
So everything is closed down at the router level! Great!

But of course you might want to open like SSH to your local computer, or connectivity to your NAS.
Easy, just:

```sh
$> ip6tables -I INPUT -d MyIPv6Address -j ACCEPT
```

This works fine, but not in the case where your ISP thinks its needed to give out a dynamic prefix.
As the full IPv6 address will change every time, its not possible to add such a rule to your ip6tables.

Searching on the internet for a possible solution, I found out the 'EUI64' module in ip6tables.
But after some testing/source code checking it was clear this module was not made for this case.
The module only checks the source MAC address and the EUI64 of the source IP and checks if it matches.
Its made to beat spoofing/unauthorized IP's in your network.

So we mailed to the netfilter mailing list for a possible solution.
And guess what, its already possible by default, but not documented.

Lets take you want to allow traffic to your computer with MAC address 'a1:a3:be:89:93:af'.
If you use SLAAC your IP will be: Prefix:a3a3:beff:fe89:93af.
Now to allow traffic to this you can use the following ip6tables rule:

```sh
$> ip6tables -I INPUT -d ::a3a3:beff:fe89:93af/::ffff:ffff:ffff:ffff -j ACCEPT
```

No more changes to your rules if your Prefix changes. It just keeps working!
