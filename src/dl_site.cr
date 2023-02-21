require "yaml"
require "colorize"

struct DL::Site
  include YAML::Serializable

  getter encoding = "GBK"

  getter chap_title = "h1"
  getter chap_body = "#content"

  getter chap_clean = [] of String

  getter cookie = ""

  @[YAML::Field(ignore: true)]
  getter chap_clean_re = [] of Regex

  def after_initialize
    @chap_clean_re = @chap_clean.map { |x| Regex.new(x) }
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
