require "../src/dl_chap"
require "../src/dl_book"

links = ARGV.select(&.starts_with?("http"))

if links.empty?
  print "Nhập vào đường dẫn mục lục: ".colorize.blue
  links = [gets.not_nil!.strip]
end

links.each do |link|
  download_book(link)
end

def download_chap(link : String, label = "-/-")
  chdl = DL::Chap.new(link, ttl: 30.days)

  out_dir = File.join("out", chdl.host, chdl.b_id)
  Dir.mkdir_p(out_dir)

  out_path = File.join(out_dir, "#{chdl.c_id}.txt")

  content = String.build do |io|
    io << chdl.title
    chdl.body.each { |line| io << '\n' << line }
  end

  File.write(out_path, content)
  puts "  <#{label}> Tệp lẻ: #{out_path.colorize.green}"
  puts

  content
end

def download_book(link : String)
  nvdl = DL::Book.new(link, ttl: 3.hours)

  chaps = nvdl.chap_list
  puts "- Tổng số chương tiết: #{chaps.size.colorize.yellow}"

  print "- Tải từ chương thứ (mặc định: 1): "
  chmin = gets.try(&.to_i?) || 1
  chmin = 1 if chmin < 1

  print "- Tới chương thứ (mặc định: #{chaps.size}): "
  chmax = gets.try(&.to_i?) || chaps.size
  chmax = chaps.size if chmax > chaps.size

  content = String::Builder.new

  chdiv = ""

  chaps[(chmin - 1)..(chmax - 1)].each_with_index(1) do |chap, idx|
    content << chap.chdiv << '\n' << '\n' if chap.chdiv != chdiv
    chdiv = chap.chdiv

    label = "#{idx}/#{chmax - chmin + 1}"
    content << download_chap(chap.href, label: label)
    content << '\n' << '\n'
  end

  out_path = File.join("out", nvdl.host, "#{nvdl.b_id} (#{chmin}-#{chmax}).txt")
  File.write(out_path, content.to_s)

  puts "  Đã tải xong các chương từ #{chmin.colorize.yellow} tới #{chmax.colorize.yellow}"
  puts "  Kết quả tổng hợp đã được lưu vào #{out_path.colorize.green}"
end

puts
print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray
gets
