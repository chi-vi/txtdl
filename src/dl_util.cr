require "uri"
require "colorize"
require "http/client"
require "compress/gzip"

module DL::Util
  extend self

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

  def fetch_page(href : String, encoding = "UTF-8")
    tls = href.starts_with?("https") ? TLS : false

    HTTP::Client.get(href, tls: tls) do |res|
      unless res.status.success?
        puts "- Không tải được dữ liệu: #{res.body_io.gets_to_end.colorize.red}"
        print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray

        gets
        exit 1
      end

      res.body_io.set_encoding(encoding)
      html = res.body_io.gets_to_end

      if html.empty?
        puts "- Trang #{href} không có nội dung, mời xem lại".colorize.red
        print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray

        gets
        exit 1
      end

      return html if encoding == "UTF-8"
      html.sub(/(?<==|")#{encoding}(?=;|")/i, "utf-8")
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
      puts "- Trang #{link} đã được lưu, không tải lại!".colorize.magenta
      read_gz(path)
    else
      puts "- Đang tải trang #{link}".colorize.green
      fetch_page(link, encoding).tap { |html| save_gz(path, html) }
    end
  end
end
