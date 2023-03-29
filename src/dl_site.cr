require "yaml"
require "colorize"

struct DL::Site
  include YAML::Serializable

  getter encoding = "GBK"

  getter list_type = "chdiv"
  getter list_css = "#list > dl"

  getter chap_title = "h1"
  getter chap_body = "#content"

  getter cookie = ""

  getter chap_ids = "(\\d+)\\D+(\\d+)\\D*$"
  getter chap_clean = [] of String

  @[YAML::Field(ignore: true)]
  getter chap_clean_re = [] of Regex

  @[YAML::Field(ignore: true)]
  getter chap_ids_re = /(\d+)\D+(\d+)\D*$/

  def after_initialize
    @chap_clean_re = @chap_clean.map { |x| Regex.new(x) }
    @chap_ids_re = Regex.new(chap_ids)
  end

  ###

  CACHED = {} of String => Site

  CONF_DIR = "conf/sites"

  def self.load(host : String)
    CACHED[host] ||= begin
      path = File.join(CONF_DIR, "#{host}.yml")

      unless File.file?(path)
        puts "Trang #{host} chưa được hỗ trợ, mời liên hệ ban quản trị".colorize.red
        print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray
        gets
        exit 1
      end

      Site.from_yaml(File.read(path))
    end
  end
end
