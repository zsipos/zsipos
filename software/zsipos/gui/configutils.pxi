# SPDX-FileCopyrightText: 2021 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2021 Esther Bergter

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
"""
#
# configutils.pxi
#
# Author: Esther Bergter
#
# Version 1.0


def concat_host_port(host, port):
    if len(host):
        if is_valid_hostname(host) or is_valid_ipv4_address(host):
            h = f'{host}'
        elif is_valid_ipv6_address(host):
            h = f'[{host}]'
        else:
            log.error(f'invalid host {host}')
            return None
    if len(port):
        return f'{h}:{port}'
    else:
        return f'{h}'
# concat_host_port

def concat_url(scheme, ip, port):
    debug("scheme %s, ip %s, port %s" % (scheme, ip, port))
    hostport = concat_host_port(ip, port)
    if hostport is None:
        log.error("concat_url failed")
        return None
    return f'{scheme}://{hostport}'
# concat_url

def concat_url_path(scheme, ip, port, path):
    #debug("scheme %s, ip %s, port %s, path %s" % (scheme, ip, port, path))
    url = concat_url(scheme, ip, port)
    if url is None:
        log.error("concat_url failed")
        return None
    return f'{url}{path}'
# concat_url_path

def disp_simple(var):
    """ generate display string from var """
    if var in cfdict:
        return filled(f'{cfdict[var]}')
    else:
        return filled(" ")

def disp_host_port(var1, var2):
    """ generate display string from var """
    if var1 in cfdict:
        host = cfdict[var1]
    else:
        host = ''
    if var2 in cfdict:
        port = cfdict[var2]
    else:
        port = ''
    if len(host) > 0:
        return filled(concat_host_port(host,port))
    else:
        return filled(" ")

def disp_upload(var1, var2):
    if var1 in cfdict:
        h = f'{cfdict[var1]}'
    else:
        h = ''
    if var2 in cfdict:
        u = f'{cfdict[var2]}'
    else:
        u = ''
    return filled(f'{h};id={u}')

def disp_turn(var1, var2, var3):
    if var1 in cfdict:
        h = f'{cfdict[var1]}'
    else:
        h = ''
    if var2 in cfdict:
        u = f'{cfdict[var2]}'
    else:
        u = ''
    if var3 in cfdict:
        p = f'{cfdict[var3]}'
    else:
        p = ''
    return filled(f'{h};u={u};p={p}')

def filled(string):
    """ insert starting blank, fill up with white to 80 chars """
    #debug(f'filled: x{string}x')
    return '{b}{s: <79}'.format(b=' ',s=string)

def is_valid_host(name):
    return is_valid_ip(name) or is_valid_hostname(name)

def is_valid_hostname(hostname):
    if len(hostname) > 255:
        return False
    if hostname[-1] == ".":
        hostname = hostname[:-1] # strip exactly one dot from the right, if present
    allowed = re.compile("(?!-)[A-Z\d-]{1,63}(?<!-)$", re.IGNORECASE)
    return all(allowed.match(x) for x in hostname.split("."))

def is_valid_ip(ip):
    """ Validate IP addresses. """
    return is_valid_ipv4_address(ip) or is_valid_ipv6_address(ip)

def is_valid_mask(mask):
    """ Validate netmask. """
    return is_valid_ipv4_mask(mask) or is_valid_ipv6_mask(mask)

def is_valid_ipv4_address(address):
    try:
        socket.inet_pton(socket.AF_INET, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        return address.count('.') == 3
    except socket.error:  # not a valid address
        return False

    return True
# is_valid_ipv4_address

def is_valid_ipv4_mask(netmask):
    if netmask.count('.') == 3:
        try:
            socket.inet_aton(netmask) # valid numbers
        except socket.error:
            return False
        s4 = netmask.split('.')
        c4 = list(map(int, s4))
        m = ((c4[0]*256+c4[1])*256+c4[2])*256+c4[3]
        #debug('subnet mask')
        #debug(bin(m))
        if m == 0:
            return False
        y = ~m + 2**32 # subnet has 32 bits
        #debug(bin(y))
        z = y +1
        #debug(bin(z))
        if (z & y):
            return False
        else:
            return True
    else:
        try:
            nt = int(netmask)
        except:
            return False
        if  nt > 0 and nt <= 32:
            return True
        else:
            return False

# is_valid_ipv4_address
def is_valid_ipv6_address(address):
    try:
        socket.inet_pton(socket.AF_INET6, address)
    except socket.error:  # not a valid address
        return False
    return True

def is_valid_ipv6_mask(netmask):
    try:
        nt = int(netmask)
    except:
        return False
    if  nt >= 8 and nt <= 128:
        return True
    else:
        return False

def is_valid_or_empty_port(testport):
    if testport is "":
        return True
    else:
        return is_valid_port(testport)

def is_valid_port(testport):

    try:
        port = int(testport)
    except:
        #debug("is_valid_port got %s" %(testport,))
        return False
    #debug("port=%d" %(port,))
    if port > 0 and port < 65536:
        return True
    else:
        return False
# is_valid_port

def split_url(input):
    #debug("split_url " + input)
    re_host = re.compile('(http[s]?)://((\w+[\.]?)+):?(\d+)?')
    re_v6 = re.compile('(http[s]?)://\[([^\]]*)\]:?(\d+)?')
    re_v4 = re.compile('(http[s]?)://(\d[^:]*):?(\d+)?')
    result = re_host.search(input)
    if not result:
        #debug(v6)
        result = re_v6.search(input)
        if not result:
            #debug(v4)
            result = re_v4.match(input)
    #debug(result)
    if result is not None:
        if result.lastindex > 2:
            debug(f'split_url {result.group(1, 2, result.lastindex)}')
            return result.group(1, 2, result.lastindex)
        elif result.lastindex == 2:
            debug(f'split_url {result.group(1, 2)}')
            return result.group(1,2)

    log.error("split_url failed: " + input)
    return ("","","")
# split_url

def split_url_path(input):
    #debug("split_url_path " + input)
    re_host = re.compile('(http[s]?)://((\w+[\.]?)+)(:(\d+))?(/.*)')
    re_v6 = re.compile('(http[s]?)://\[([^\]]*)\](:(\d+))?(/.*)')
    re_v4 = re.compile('(http[s]?)://(\d[^:]*)(:(\d+))?(/.*)')
    result = re_host.search(input)
    if not result:
        #debug(v6)
        result = re_v6.search(input)
        if not result:
            #debug(v4)
            result = re_v4.match(input)
    if result is not None:
        if result.lastindex > 3:
            debug(f'split_url_path {result.group(1, 2, 5, result.lastindex)}')
            return result.group(1, 2, 5, result.lastindex)
    log.error("split_url_path failed: " + input)
    return ("","","","")
# split_url_path

def to_bool(myint):
    if myint is None:
        return False
    try:
        i = int(myint)
    except:
        return True
    if i == 0:
        return False
    else:
        return True

