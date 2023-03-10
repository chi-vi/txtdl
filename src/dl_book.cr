require "./dl_util"
require "./dl_site"
require "./dl_page"

class DL::Book
  @uri : URI
  @doc : Page
  @site : Site

  getter host : String
  getter b_id : String

  record Chap, title : String, chdiv : String, href : String

  def initialize(link : String, ttl : Time::Span = 3.hours)
    @uri = URI.parse(link)
    @host = @uri.hostname.not_nil!

    @site = Site.load(@host)

    html = Util.load_html(link, ttl: ttl, encoding: @site.encoding)
    @doc = Page.new(html)

    @b_id = link.scan(/\d+/).last[0]
    @chaps = [] of Chap
  end

  getter chap_list : Array(Chap) do
    case @site.list_type
    when "plain"
      extract_plain(@site.list_css)
    when "chdiv"
      extract_chdiv(@site.list_css)
    when "ymxwx"
      extract_ymxwx(@site.list_css)
    when "wenku"
      extract_wenku(@site.list_css)
    when "uukanshu"
      extract_uukanshu(@site.list_css)
    else
      Util.error_notif("Không hỗ trợ kiểu dịch", @site.list_type)
      raise "unreachable"
    end

    @chaps
  end

  private def clean_chdiv(chdiv : String)
    chdiv.gsub(/《.*》/, "").gsub(/\n|\t|\s{3,}/, "  ").strip
  end

  private def add_chap(node : Lexbor::Node?, chdiv = "")
    return unless node && (href = node.attributes["href"]?)

    title = node.inner_text("  ")
    return if title.empty?

    @chaps << Chap.new(title, chdiv, @uri.resolve(href).to_s)
  rescue ex
    Log.error(exception: ex) { ex.message.colorize.red }
  end

  private def extract_chdiv(query : String)
    return unless body = @doc.find(query)
    chdiv = ""

    body.children.each do |node|
      case node.tag_sym
      when :dt
        inner = node.css("b", &.first?) || node
        chdiv = clean_chdiv(inner.inner_text)
        add_chap(node.css("a", &.first?), chdiv)
      when :dd
        next if chdiv.includes?("最新章节")
        add_chap(node.css("a", &.first?), chdiv)
      end
    end
  end

  private def extract_ymxwx(query : String)
    return unless body = @doc.find(query)
    chdiv = ""

    body.children.each do |node|
      next unless node.tag_sym == :li

      case node.attributes["class"]?
      when "col1 volumn"
        chdiv = clean_chdiv(node.inner_text)
      when "col3"
        next if chdiv.includes?("最新九章")
        add_chap(node.css("a", &.first?), chdiv)
      end
    end
  end

  private def extract_wenku(query : String)
    return unless body = @doc.find(query)
    chdiv = ""

    body.css("td").each do |node|
      case node.attributes["class"]?
      when "vcss"
        chdiv = clean_chdiv(node.inner_text)
      when "ccss"
        add_chap(node.css("a", &.first?), chdiv)
      end
    end
  end

  private def extract_plain(query : String)
    @doc.css(query).each { |link_node| add_chap(link_node) }
  end

  private def extract_uukanshu(query : String)
    return unless body = @doc.find(query)
    chdiv = ""

    body.children.to_a.reverse_each do |node|
      if node.attributes["class"]? == "volume"
        chdiv = clean_chdiv(node.inner_text)
      else
        add_chap(node.css("a").first?, chdiv)
      end
    end
  end
end
