require "../src/dl_chap"

links = ARGV.select(&.starts_with?("http"))

if links.empty?
  print "Nhập vào đường dẫn chương: ".colorize.blue
  links = [gets.not_nil!.strip]
end

links.each do |link|
  chdl = DL::Chap.new(link, ttl: 30.days)

  out_dir = File.join("out", chdl.host, chdl.b_id)
  Dir.mkdir_p(out_dir)

  out_path = File.join(out_dir, "#{chdl.c_id}.txt")

  File.open(out_path, "w") do |file|
    file << chdl.title << '\n'
    chdl.body.each { |line| file << '\n' << line }
  end

  puts "  Kết quả đã được lưu vào #{out_path.colorize.green}"
end

puts
print "-- Gõ Enter để thoát chương trình! --".colorize.dark_gray
gets
