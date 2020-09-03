#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <linux/sockios.h>


#include <sel4ip.h>

void usage()
{
	printf("usage:\n\n");
	printf("sel4iptool device <action>\n");
	printf("actions:\n");
	printf("\tdhcp\n");
	printf("\tping <address>\n");
	exit(1);
}

void usage_fail()
{
	usage();
	exit(1);
}

int do_ioctl(char *device, int request, struct sel4ioctl *arg)
{
	int fd, ret;

	strncpy(arg->ifname, device, sizeof(arg->ifname));

	fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (fd < 0) {
		perror("socket");
		exit(1);
	}
	ret = ioctl(fd, request, arg);
	if (ret < 0) {
		perror("ioctl");
		exit(1);
	}

	close(fd);

	return ret;
}

void dhcp(char *device)
{
	int              ret, i;
	struct sel4ioctl arg;

	ret = do_ioctl(device, SIOCSEL4IPDHCP, &arg);
	if (ret != 0) {
		fprintf(stderr, "do_ioctl dhcp returned %d\n", ret);
		exit(1);
	}
	for (i = 0; i < arg.dhcp.nameserver_count; i++) {
		const char *ipstr;
		char ipstrbuf[INET6_ADDRSTRLEN];
		struct sockaddr *p = (struct sockaddr *)arg.dhcp.nameserver_addrs[i];

		printf("nameserver ");
		if (p->sa_family == AF_INET)
			ipstr = inet_ntop(p->sa_family, &((struct sockaddr_in*)(p))->sin_addr, ipstrbuf, sizeof(ipstrbuf));
		else
			ipstr = inet_ntop(p->sa_family, &((struct sockaddr_in6*)(p))->sin6_addr, ipstrbuf, sizeof(ipstrbuf));

		if (!ipstr) {
			perror("inet_ntop");
		}
		printf("%s\n", ipstr);
	}
}

void ping(char *device, char *address, char *count)
{
	int               i, ret, received;
	struct sel4ioctl  arg;
	struct addrinfo   filter, *info;
	const char       *ipstr;
	char              ipstrbuf[INET6_ADDRSTRLEN];

	/* restrict to ipv4 at the moment */
	memset(&filter, 0, sizeof(filter));
	filter.ai_family = AF_INET;

	ret = getaddrinfo(address, NULL, &filter, &info);

	if (ret) {
		fprintf(stderr, "%s is unknown\n", address);
		exit(1);
	}

	if ((info->ai_family != AF_INET) && (info->ai_family != AF_INET6)) {
		fprintf(stderr, "bad address family %d\n", info->ai_family);
		exit(1);
	}

	memcpy(&arg.ping.addr, info->ai_addr, info->ai_addrlen);

	arg.ping.count = count ? atoi(count) : 10;

	if ((arg.ping.count < 1) || (arg.ping.count > SEL4IP_MAX_PING)) {
		fprintf(stderr, "packet count must be 1..%d\n", SEL4IP_MAX_PING);
		exit(1);
	}

	if (info->ai_family == AF_INET)
		ipstr = inet_ntop(info->ai_family, &((struct sockaddr_in*)(info->ai_addr))->sin_addr, ipstrbuf, sizeof(ipstrbuf));
	else
		ipstr = inet_ntop(info->ai_family, &((struct sockaddr_in6*)(info->ai_addr))->sin6_addr, ipstrbuf, sizeof(ipstrbuf));

	if (!ipstr) {
		perror("inet_ntop");
		exit(1);
	}

	printf("PING %s (%s)\n", address, ipstr);

	ret = do_ioctl(device, SIOCSEL4IPPING, &arg);
	if (ret != 0) {
		fprintf(stderr, "do_ioctl ping returned %d\n", ret);
		exit(1);
	}

	received = 0;

	for (i = 0; i < arg.ping.count; i++) {
		sel4ip_ping_stat_t *p = &arg.ping.stats[i];

		if (p->err == 0) {
			printf("%d bytes from %s (%s): icmp_seq=%d ttl=%d time=%dms\n",
					p->size, address, ipstr, p->seq, p->ttl, p->time);
			received++;
		}
	}
	printf("--- %s ping statistics ---\n", address);
	printf("%d packets transmitted, %d received, %d%% packet loss\n", arg.ping.count, received, (arg.ping.count - received) * 100 / arg.ping.count);
}

int main(int argc, char **argv)
{
	if (argc < 3)
		usage_fail();

	if (strcmp(argv[2], "dhcp") == 0) {
		if (argc != 3)
			usage_fail();
		dhcp(argv[1]);
	} else if (strcmp(argv[2], "ping") == 0) {
		if ((argc != 4) && (argc != 5))
			usage_fail();
		ping(argv[1], argv[3], argc == 5 ? argv[4] : NULL);
	} else {
		usage_fail();
	}
	return 0;
}
