module common.socket;

import core.stdc.stdlib, core.stdc.stdio;
import std.internal.cstring;

public import std.socket : AddressFamily, SocketType, ProtocolType, SocketFlags, wouldHaveBlocked;

@nogc:
nothrow:

version(Windows)
{
	pragma (lib, "ws2_32.lib");
	pragma (lib, "wsock32.lib");

	public import core.sys.windows.winsock2;
	private import core.sys.windows.windows, std.windows.syserror;
	private alias _ctimeval = core.sys.windows.winsock2.timeval;
	private alias _clinger = core.sys.windows.winsock2.linger;

	enum socket_t : SOCKET { INVALID_SOCKET }
	private const int _SOCKET_ERROR = SOCKET_ERROR;


	private int _lasterr() nothrow @nogc
	{
		return WSAGetLastError();
	}
}
else version(Posix)
{
	version(linux)
	{
		enum : int
		{
			TCP_KEEPIDLE  = 4,
			TCP_KEEPINTVL = 5
		}
	}

	import core.sys.posix.netdb;
	import core.sys.posix.sys.un : sockaddr_un;
	private import core.sys.posix.fcntl;
	private import core.sys.posix.unistd;
	private import core.sys.posix.arpa.inet;
	private import core.sys.posix.netinet.tcp;
	private import core.sys.posix.netinet.in_;
	private import core.sys.posix.sys.time;
	private import core.sys.posix.sys.select;
	private import core.sys.posix.sys.socket;
	private alias _ctimeval = core.sys.posix.sys.time.timeval;
	private alias _clinger = core.sys.posix.sys.socket.linger;

	private import core.stdc.errno;

	enum socket_t : int32_t { init = -1 }
	private const int _SOCKET_ERROR = -1;

	private enum : int
	{
		SD_RECEIVE = SHUT_RD,
		SD_SEND    = SHUT_WR,
		SD_BOTH    = SHUT_RDWR
	}

	private int _lasterr() nothrow @nogc
	{
		return errno;
	}
}
else
{
	static assert(0);     // No socket support yet.
}

struct NonBlockingSocket
{
	@nogc:
	nothrow:
	
	socket_t handle = cast(socket_t)-1;

	this(AddressFamily af, SocketType type, ProtocolType protocol) @trusted
	{
		this.handle = cast(socket_t).socket(af, type, protocol);
		version (Windows)
		{
			uint nonblock = 1;
			ioctlsocket(this.handle, FIONBIO, &nonblock);
		}
		else version (Posix)
		{
			auto x = fcntl(handle, F_GETFL, 0);
			x |= O_NONBLOCK;
			fcntl(this.handle, F_SETFL, x);
		}
	}

	this(socket_t handle)
	{
		this.handle = handle;
	}

	bool isValid() @property
	{
		return this.handle != -1;
	}

	~this()
	{
		close(this.handle);
	}

	NonBlockingSocket accept()
	{
		return NonBlockingSocket(cast(socket_t).accept(this.handle, null, null));
	}

	bool bind(ushort port)
	{
		sockaddr_in sa;
		sa.sin_family = AF_INET;
		sa.sin_port = htons(port);
		sa.sin_addr.s_addr = htonl(INADDR_ANY);

		return .bind(this.handle, cast(sockaddr*)&sa, sa.sizeof) != -1;
	}

	bool listen(int backlog)
	{
		return .listen(this.handle, backlog) == _SOCKET_ERROR;
	}

	ptrdiff_t receive(void[] buf, SocketFlags flags = SocketFlags.NONE) @trusted
	{
		version (Windows)
			auto length = cast(int)buf.length;
		else
			auto length = buf.length;

		return length ? .recv(this.handle, buf.ptr, length, cast(int)flags) : 0;
	}
}