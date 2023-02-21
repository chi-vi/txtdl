require "uri"
require "colorize"
require "http/client"
require "compress/gzip"

module DL::Util
  extend self

  def error_notif(reason : String, message : String)
    puts "- #{reason}: #{message.colorize.red}"
    puts
    print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray
    gets
    exit 1
  end

  def read_gz(path : String)
    File.open(path) { |io| Compress::Gzip::Reader.open(io, &.gets_to_end) }
  end

  def save_gz(path : String, data : String)
    File.open(path, "w") { |io| Compress::Gzip::Writer.open(io, &.print(data)) }
  end

  def file_exists?(file : String, ttl : Time::Span | Time::MonthSpan)
    return false unless info = File.info?(file)
    info.modification_time > Time.utc - ttl
  end

  def get_site_host(href : String)
    URI.parse(href).hostname.not_nil!
  end

  CA_FILE = ENV["CA_FILE"]? || "conf/cacert.pem"

  TLS = OpenSSL::SSL::Context::Client.new
  TLS.ca_certificates = CA_FILE

  USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:110.0) Gecko/20100101 Firefox/110.0"

  HEADERS = HTTP::Headers{"User-Agent" => USER_AGENT}

  def fetch_page(href : String, encoding = "UTF-8")
    tls = href.starts_with?("https") ? TLS : false

    HTTP::Client.get(href, tls: tls, headers: HEADERS) do |res|
      unless res.success?
        error_notif("Không tải được dữ liệu", res.body_io.gets_to_end)
        # unreachable!
      end

      res.body_io.set_encoding(encoding)
      html = res.body_io.gets_to_end

      if html.empty?
        error_notif("Không tải được dữ liệu", "Trang không có nội dung")
        # unreachable!
      end

      return html if encoding == "UTF-8"
      html.sub(/(?<==|")#{encoding}(?=;|")/i, "utf-8")
    rescue ex
      error_notif("Không tải được dữ liệu", ex.message || "Không rõ lỗi")
      # unreachable!
    end
  end

  CACHE_DIR = "tmp"
  Dir.mkdir_p(CACHE_DIR)

  def cache_path(link : String)
    parts = link.split('/', 4)

    dir = "#{CACHE_DIR}/#{parts[2]}" # host name
    Dir.mkdir_p(dir)

    path = parts[3].gsub(/\W/, '_') # path name
    "#{dir}/#{path}.htm.gz"
  end

  def load_html(link : String, ttl : Time::Span = 1.hours, encoding : String = "UTF-8")
    path = cache_path(link)

    if file_exists?(path, ttl: ttl)
      puts "- Đã tải: #{link.colorize.magenta}"
      read_gz(path)
    else
      puts "- Đang tải: #{link.colorize.cyan}"
      fetch_page(link, encoding).tap { |html| save_gz(path, html) }
    end
  end
end
