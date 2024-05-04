class HTTP::Client
  def dns_resolver=(value : Durian::Resolver)
    @dnsResolver = value
  end

  def dns_resolver
    @dnsResolver
  end

  def tls_context
    tls rescue nil
  end

  def close
    @io.try &.close rescue nil
  end

  private def create_socket(hostname : String)
    # Workaround Because since 2f143fbfecddb1d9f282646c3040c5a0c9d1d6d8 in crystal Http::Client.*_timeout are Time::Span instead Int | Float? = nil
    connect_timeout = @connect_timeout
    connect_timeout_f = unless connect_timeout.nil?
      connect_timeout.to_f
    else
      nil
    end
    return TCPSocket.new hostname, @port, @dns_timeout, connect_timeout_f unless resolver = dns_resolver

    Durian::TCPSocket.connect hostname, @port, resolver, connect_timeout_f
  end

  def set_wrapped(wrapped : IO)
    return if @io
    @io = wrapped

    begin
      hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1_i32..-2_i32] : @host

      {% unless flag? :without_openssl %}
        case _tls = tls_context
        when OpenSSL::SSL::Context::Client
          tls_socket = OpenSSL::SSL::Socket::Client.new wrapped, context: _tls, sync_close: true, hostname: @host
          @io = tls_socket
        end
      {% end %}
    rescue ex
      close

      raise ex
    end
  end

  private def io
    _io = @io
    return _io if _io

    raise "This HTTP::Client cannot be reconnected" unless @reconnect

    begin
      hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1_i32..-2_i32] : @host
      _io = create_socket hostname
      # Workaround Because since 2f143fbfecddb1d9f282646c3040c5a0c9d1d6d8 in crystal Http::Client.*_timeout are Time::Span instead Int | Float? = nil
      read_timeout = @read_timeout
      read_timeout_f = unless read_timeout.nil?
        read_timeout.to_f
      else
        nil
      end
      _io.read_timeout = read_timeout_f if read_timeout_f
      write_timeout = @write_timeout
      write_timeout_f = unless write_timeout.nil?
        write_timeout.to_f
      else
        nil
      end
      _io.write_timeout = write_timeout_f if write_timeout_f
      _io.sync = false
      @io = _io

      {% unless flag? :without_openssl %}
        case _tls = tls_context
        when OpenSSL::SSL::Context::Client
          _io = OpenSSL::SSL::Socket::Client.new _io, context: _tls, sync_close: true, hostname: @host
          @io = _io
        end
      {% end %}

      _io
    rescue ex
      close

      raise ex
    end
  end
end
