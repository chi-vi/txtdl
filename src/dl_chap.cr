require "yaml"

require "./dl_page"
require "./dl_site"
require "./dl_util"

class DL::Chap
  def self.new(link : String, ttl = 10.days)
    host = Util.get_site_host(link)
    site = Site.load(host)
    html = Util.load_html(link, ttl: ttl, encoding: site.encoding)

    new(html, site, link)
  end

  @doc : Page
  getter host : String
  getter b_id : String
  getter c_id : String

  def initialize(html : String, @site : Site, @link : String)
    @doc = Page.new(html)
    @host = site.hostname
    *_, @b_id, @c_id = link.scan(/\d+/).map(&.[0])
  end

  getter title : String do
    elem = @doc.find!(@site.chap_title)

    if @link.includes?("ptwxz")
      elem.children.each { |node| node.remove! if node.tag_sym == :a }
    end

    title = @doc.inner_text(elem, ' ')
    puts "  Tựa chương: #{title.colorize.yellow}"

    title
      .sub(/^章节目录\s*/, "")
      .sub(/(《.+》)?正文\s*/, "")
  end

  getter body : Array(String) do
    return get_hetu_body if @link.includes?("hetushu")

    purge_tags = {:script, :div, :h1, :table, :ul}
    lines = @doc.get_lines(@site.chap_body, purge_tags)
    return lines if lines.empty?

    lines.shift if reject_first_line?(lines.first)
    lines.pop if lines.last == "(本章完)"

    lines.reject(&.empty?)
  rescue ex
    Log.error(exception: ex) { "error extracting body" }
    [] of String
  end

  private def reject_first_line?(first : String)
    case first
    when .starts_with?("笔趣阁"), .starts_with?("笔下文学")
      true
    else
      first.sub(self.title, "") !~ /\p{Han}/
    end
  end

  private def get_hetu_body
    file_path = Util.cache_path(@link).sub(".htm.gz", ".tok")
    reorder = get_hetu_line_order(file_path)

    res = Array(String).new(reorder.size, "")
    jmp = 0

    nodes = @doc.css("#content > div:not([class])")

    nodes.each_with_index do |node, idx|
      ord = reorder[idx]? || 0

      if ord < 5
        jmp += 1
      else
        ord -= jmp
      end

      res[ord] = node.inner_text(deep: false).strip
    end

    res
  end

  private def get_hetu_line_order(file : String)
    base64 = load_encrypt_string(file)
    Base64.decode_string(base64).split(/[A-Z]+%/).map(&.to_i)
  end

  private def load_encrypt_string(file : String)
    return File.read(file) if File.exists?(file)

    headers = HTTP::Headers{
      "Referer"          => @link,
      "Content-Type"     => "application/x-www-form-urlencoded",
      "X-Requested-With" => "XMLHttpRequest",
      "Cookie"           => @site.cookie,
    }

    json_link = @link.sub(/(\d+).html$/) { "r#{$1}.json" }

    HTTP::Client.get(json_link, headers: headers) do |res|
      unless res.status.success?
        puts "  Không tải được thông tin giải mã trang #{@link}".colorize.red
        print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray
        gets
        exit 1
      end

      res.headers["token"].tap { |x| File.write(file, x) }
    end
  end
end
